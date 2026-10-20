-- With the Mod Configuration Menu: the multiplier from MCM becomes a CarryCapacityMultiplier boost on every party
-- member and camp companion, and every change replaces it.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }
-- MCM loads before this mod (the dependency in meta.lsx), so this mod gets the MCM table.
Harness.InstallMCM({ carry_multiplier = 2.5 })
local World = load(READ_FILE(MOD_LUA_ROOT .. "/../../../../../tests/world.lua"))()

Ext.Require("BootstrapServer.lua")
Ext.Require("BootstrapClient.lua")
local Settings = Ext.Require("Shared/Settings.lua")

local function ServerLog()
    -- Twice: the delayed limits line is a timer, and its log write is a second one.
    Harness.RunTimers()
    Harness.RunTimers()
    return Harness.Files["bg3_carryweightconfig/server.log"] or ""
end

local B25 = "CarryCapacityMultiplier(2.50)"

Test("the session load gives the boost to party members and camp companions, not to summons", function()
    Ext.Events.SessionLoaded:Fire()
    AssertEq(World.BoostsOf(World.Hero), B25, "party member")
    AssertEq(World.BoostsOf(World.Shadowheart), B25, "party member")
    AssertEq(World.BoostsOf(World.Gale), B25, "camp companion")
    AssertEq(World.BoostsOf(World.Wolf), "", "no boost for a summon")
    AssertTrue(string.find(ServerLog(), "Settings: carry_multiplier = 2.5 (MCM).", 1, true), "settings line")
    AssertTrue(string.find(ServerLog(), "Session loaded: multiplier 2.50 (MCM), boost " .. B25
        .. ": 3 changed, 0 unchanged, 0 removed (left the team).", 1, true), "apply line")
    AssertEq(Harness.ModVars.AppliedBoosts[string.sub(World.Hero, -36)], B25, "kept in the savegame")
end)

Test("applying again changes nothing", function()
    local calls = World.Calls.Add + World.Calls.Remove
    Harness.Listeners["LevelGameplayStarted/2"]("WLD_Main_A", 0)
    AssertEq(World.Calls.Add + World.Calls.Remove, calls, "no Osiris calls")
    AssertTrue(string.find(ServerLog(), "Level started: multiplier 2.50 (MCM), boost " .. B25 .. ": 0 changed, 3 unchanged",
        1, true), "log")
end)

Test("a change in MCM replaces the boost at once", function()
    Harness.FireMCMSettingSaved("carry_multiplier", 4)
    AssertEq(World.BoostsOf(World.Hero), "CarryCapacityMultiplier(4.00)", "new boost, the old one is gone")
    AssertEq(World.BoostsOf(World.Gale), "CarryCapacityMultiplier(4.00)", "camp companion too")
    AssertTrue(string.find(ServerLog(), "Setting changed: multiplier 4.00 (MCM)", 1, true), "log")
end)

Test("1.0 removes the boost: the game's own limit", function()
    Harness.FireMCMSettingSaved("carry_multiplier", 1.0)
    AssertEq(World.BoostsOf(World.Hero), "", "no boost")
    AssertTrue(string.find(ServerLog(), "multiplier 1.00 (MCM), boost none: 3 changed", 1, true), "log")
end)

Test("values outside the slider range are clamped, and a profile switch reads the value again", function()
    Harness.MCMValues.carry_multiplier = 150
    Ext.ModEvents.BG3MCM["MCM_Profile_Activated"]:Fire({ profileName = "Other" })
    AssertEq(World.BoostsOf(World.Hero), "CarryCapacityMultiplier(90.00)", "at most 90")
    AssertTrue(string.find(ServerLog(), "MCM profile changed: multiplier 90.00", 1, true), "log")
    Harness.FireMCMSettingSaved("carry_multiplier", 0.05)
    AssertEq(World.BoostsOf(World.Hero), "CarryCapacityMultiplier(0.25)", "at least 0.25")
end)

Test("the script clamps to the slider range of the blueprint", function()
    local Carry = Ext.Require("Server/Carry.lua")
    local slider = MCM_BLUEPRINT.Tabs[1].Sections[1].Settings[1]
    AssertEq(slider.Id, Carry.SettingId, "setting id")
    AssertEq(slider.Options.Min, Carry.Min, "Min")
    AssertEq(slider.Options.Max, Carry.Max, "Max")
end)

Test("values below 1.0 lower the limit with the same boost", function()
    Harness.FireMCMSettingSaved("carry_multiplier", 0.5)
    AssertEq(World.BoostsOf(World.Hero), "CarryCapacityMultiplier(0.50)", "a boost below 1.0")
    AssertEq(World.BoostsOf(World.Gale), "CarryCapacityMultiplier(0.50)", "camp companion too")
end)

Test("a new party member gets the boost, and one who left the team loses it", function()
    Harness.FireMCMSettingSaved("carry_multiplier", 2.5)
    World.Add(World.Karlach, { Player = true, Team = true })
    Harness.Listeners["CharacterJoinedParty/1"](World.Karlach)
    AssertEq(World.BoostsOf(World.Karlach), B25, "new member")
    World.Characters[string.sub(World.Gale, -36)].Team = nil
    Harness.Listeners["CharacterLeftParty/1"](World.Shadowheart)
    AssertEq(World.BoostsOf(World.Gale), "", "removed from a character that left the team")
    AssertTrue(string.find(ServerLog(), "Left the party: S_Player_ShadowHeart: multiplier 2.50 (MCM), boost " .. B25
        .. ": 0 changed, 3 unchanged, 1 removed (left the team).", 1, true), "log")
end)

Test("a boost from an earlier session is replaced exactly", function()
    World.Reset()
    Harness.ModVars.AppliedBoosts = { [string.sub(World.Hero, -36)] = "CarryCapacityMultiplier(3.00)" }
    World.Characters[string.sub(World.Hero, -36)].Boosts["CarryCapacityMultiplier(3.00)"] = 1
    Ext.Events.SessionLoaded:Fire()
    AssertEq(World.BoostsOf(World.Hero), B25, "old boost removed, new one added")
end)

Test("a second after a change, the log shows the limits the game computed", function()
    Harness.Objects[World.Hero] = { Components = { EncumbranceStats = {
        UnencumberedWeight = 224000, EncumberedWeight = 256000, HeavilyEncumberedWeight = 280000 } } }
    Harness.FireMCMSettingSaved("carry_multiplier", 3)
    AssertTrue(string.find(ServerLog(), "Carry limits in kg (UnencumberedWeight/EncumberedWeight/HeavilyEncumberedWeight): "
        .. "S_Player_Hero 224/256/280.", 1, true), "limits line")
    Harness.Objects[World.Hero] = nil
end)

Test("an MCM error or a value of the wrong type gives the default", function()
    local original = MCM.Get
    MCM.Get = function() error("broken") end
    local value, source = Settings.Get("carry_multiplier")
    AssertEq(value, 2.0, "default after an error")
    AssertEq(source, "default", "source")
    MCM.Get = function() return "yes" end
    value = Settings.Get("carry_multiplier")
    MCM.Get = original
    AssertEq(value, 2.0, "default for a wrong type")
end)
