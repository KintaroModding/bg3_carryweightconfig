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

Test("the session load only logs: Osiris databases cannot be read then", function()
    Ext.Events.SessionLoaded:Fire()
    AssertEq(World.BoostsOf(World.Hero), "", "no boost yet")
    AssertTrue(string.find(ServerLog(), "Settings: carry_multiplier = 2.5 (MCM).", 1, true), "settings line")
end)

Test("the level start gives the boost to party members and camp companions, not to summons", function()
    Harness.Listeners["LevelGameplayStarted/2"]("WLD_Main_A", 0)
    AssertEq(World.BoostsOf(World.Hero), B25, "party member")
    AssertEq(World.BoostsOf(World.Shadowheart), B25, "party member")
    AssertEq(World.BoostsOf(World.Gale), B25, "camp companion")
    AssertEq(World.BoostsOf(World.Wolf), "", "no boost for a summon")
    AssertEq(Harness.ModVars.AppliedBoosts[string.sub(World.Hero, -36)], B25, "kept in the savegame")
    local log = ServerLog()
    AssertTrue(string.find(log, "Level started: renewing all boosts. Carry boosts found:", 1, true), "found line")
    AssertTrue(string.find(log, "Level started: multiplier 2.50 (MCM), boost " .. B25
        .. ": 3 changed, 0 unchanged, 0 removed (left the team).", 1, true), "apply line")
end)

Test("3 seconds after the level start, the check finds the boosts and adds none twice", function()
    -- ServerLog() above ran the timers, so the delayed renewal has run.
    AssertTrue(string.find(ServerLog(), "3 s after the level start: multiplier 2.50 (MCM), boost " .. B25
        .. ": 0 changed, 3 unchanged", 1, true), "renewal line")
    AssertEq(World.BoostsOf(World.Hero), B25, "one boost, not two")
end)

Test("an event with the same value changes nothing", function()
    local calls = World.Calls.Add + World.Calls.Remove
    Harness.FireMCMSettingSaved("carry_multiplier", 2.5)
    AssertEq(World.Calls.Add + World.Calls.Remove, calls, "no Osiris calls")
    AssertTrue(string.find(ServerLog(), "Setting changed: multiplier 2.50 (MCM), boost " .. B25 .. ": 0 changed, 3 unchanged",
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

Test("after a load, the boosts that the game lost come back", function()
    -- The bug of the first game test: the saved record listed the boosts, the loaded game had none, and the mod
    -- trusted the record.
    local Carry = Ext.Require("Server/Carry.lua")
    World.Reset()
    Carry.ResetSession()
    Harness.ModVars.AppliedBoosts = {}
    for _, guid in ipairs({ World.Hero, World.Shadowheart, World.Gale }) do
        Harness.ModVars.AppliedBoosts[string.sub(guid, -36)] = B25
    end
    Harness.Listeners["LevelGameplayStarted/2"]("WLD_Main_A", 0)
    AssertEq(World.BoostsOf(World.Hero), B25, "boost given again")
    AssertEq(World.BoostsOf(World.Gale), B25, "camp companion too")
    AssertTrue(string.find(ServerLog(), "Level started: renewing all boosts. Carry boosts found:", 1, true), "found line")
    AssertTrue(string.find(ServerLog(), "Level started: multiplier 2.50 (MCM), boost " .. B25 .. ": 3 changed", 1, true),
        "apply line")
    Harness.Listeners["LevelGameplayStarted/2"]("WLD_Main_A", 0)
    AssertEq(World.BoostsOf(World.Hero), B25, "a second apply in the same session changes nothing")
end)

Test("a boost that a save kept is replaced, not doubled", function()
    local Carry = Ext.Require("Server/Carry.lua")
    World.Reset()
    Carry.ResetSession()
    Harness.ModVars.AppliedBoosts = { [string.sub(World.Hero, -36)] = "CarryCapacityMultiplier(3.00)" }
    World.Characters[string.sub(World.Hero, -36)].Boosts["CarryCapacityMultiplier(3.00)"] = 1
    World.Characters[string.sub(World.Shadowheart, -36)].Boosts[B25] = 1
    Harness.ModVars.AppliedBoosts[string.sub(World.Shadowheart, -36)] = B25
    Harness.Listeners["LevelGameplayStarted/2"]("WLD_Main_A", 0)
    AssertEq(World.BoostsOf(World.Hero), B25, "old boost removed, new one added")
    AssertEq(World.BoostsOf(World.Shadowheart), B25, "the same boost once, not twice")
end)

Test("an error is written to server.log, and the next event tries again", function()
    local original = Osi.DB_PartOfTheTeam
    Osi.DB_PartOfTheTeam = { Get = function() error("Osiris is not ready") end }
    Harness.FireMCMSettingSaved("carry_multiplier", 3)
    AssertTrue(string.find(ServerLog(), "ERROR in Setting changed: ", 1, true), "error line")
    AssertTrue(string.find(ServerLog(), "Osiris is not ready", 1, true), "error text")
    Osi.DB_PartOfTheTeam = original
    Harness.FireMCMSettingSaved("carry_multiplier", 2.5)
    AssertEq(World.BoostsOf(World.Hero), B25, "works again")
end)

Test("a second after a change, the log shows the limits the game computed", function()
    local components = Harness.Objects[World.Hero].Components
    components.EncumbranceStats = { UnencumberedWeight = 224000, EncumberedWeight = 256000,
        HeavilyEncumberedWeight = 280000 }
    -- A carry boost of the game on the same character (as Human Versatility gives 1.25).
    World.Characters[string.sub(World.Hero, -36)].Boosts["CarryCapacityMultiplier(1.25)"] = 1
    Harness.FireMCMSettingSaved("carry_multiplier", 3)
    AssertTrue(string.find(ServerLog(), "Carry limits in kg (UnencumberedWeight/EncumberedWeight/HeavilyEncumberedWeight) "
        .. "[carry boosts]: S_Player_Hero 224/256/280 [1.25+3].", 1, true), "limits line with the boosts")
    components.EncumbranceStats = nil
    World.Characters[string.sub(World.Hero, -36)].Boosts["CarryCapacityMultiplier(1.25)"] = nil
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
