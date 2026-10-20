-- With the Mod Configuration Menu: the multiplier from MCM becomes the game's global carry values (ExtraData),
-- written by the client when the stats load, by both sides on the session load, and after every change.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 1 } } }
-- MCM loads before this mod (the dependency in meta.lsx), so this mod gets the MCM table.
Harness.InstallMCM({ carry_multiplier = 2.5 })
local World = load(READ_FILE(MOD_LUA_ROOT .. "/../../../../../tests/world.lua"))()

Ext.Require("BootstrapServer.lua")
Ext.Require("BootstrapClient.lua")
local Settings = Ext.Require("Shared/Settings.lua")
local CarryData = Ext.Require("Shared/CarryData.lua")

local function Log(name)
    -- The refresh is a chain of timers (1 s, 1 s, 1 s), and each log write is one more.
    for _ = 1, 6 do
        Harness.RunTimers()
    end
    return Harness.Files["bg3_carryweightconfig/" .. name] or ""
end

local function Values()
    local x = World.ExtraData
    return string.format("%g/%g/%g/%g", x.CarryWeightBase, x.CarryLimitMultiplier, x.EncumberedMultiplier,
        x.HeavilyEncumberedMultiplier)
end

Test("the client writes the values when the stats load", function()
    Ext.Events.StatsLoaded:Fire()
    AssertEq(Values(), "100/25/17.5/22.5", "game values x 2.5")
    AssertEq(World.ExtraData.CarryWeightPerStr, 10000, "a key the formula does not use stays")
    AssertEq(World.ExtraData["bg3_carryweightconfig_Original_CarryLimitMultiplier"], 10, "original kept")
    AssertTrue(string.find(Log("client.log"), "Stats loaded: multiplier 2.50 (MCM): CarryWeightBase 100, "
        .. "CarryLimitMultiplier 25, EncumberedMultiplier 17.5, HeavilyEncumberedMultiplier 22.5.", 1, true), "log")
end)

Test("the server writes them on the session load, without any Osiris call", function()
    local players = Osi.DB_Players
    Osi.DB_Players = { Get = function() error("Osiris in SessionLoaded") end }
    Ext.Events.SessionLoaded:Fire()
    Osi.DB_Players = players
    local log = Log("server.log")
    AssertTrue(string.find(log, "Session loaded: multiplier 2.50 (MCM): CarryWeightBase 100,", 1, true), "log")
    AssertTrue(not string.find(log, "ERROR", 1, true), "no error")
    AssertEq(Values(), "100/25/17.5/22.5", "unchanged: the same values")
end)

Test("a change multiplies the original values, not the multiplied ones", function()
    Harness.FireMCMSettingSaved("carry_multiplier", 4)
    AssertEq(Values(), "160/40/28/36", "game values x 4")
    AssertTrue(string.find(Log("server.log"), "Setting changed: multiplier 4.00 (MCM): CarryWeightBase 160,", 1, true),
        "server log")
    AssertTrue(string.find(Log("client.log"), "Setting changed: multiplier 4.00 (MCM)", 1, true), "client log")
end)

Test("a new Lua session in the same game process finds the originals", function()
    -- The values stay multiplied in the process; the extra keys still hold the originals.
    Harness.MCMValues.carry_multiplier = 2
    CarryData.Apply()
    AssertEq(Values(), "80/20/14/18", "game values x 2, not 160 x 2")
end)

Test("1.0 gives the game's values", function()
    Harness.FireMCMSettingSaved("carry_multiplier", 1.0)
    AssertEq(Values(), "40/10/7/9", "game values")
end)

Test("values outside the slider range are clamped", function()
    Harness.FireMCMSettingSaved("carry_multiplier", 150)
    AssertEq(Values(), "3600/900/630/810", "at most 90")
    Harness.FireMCMSettingSaved("carry_multiplier", 0.05)
    AssertEq(Values(), "10/2.5/1.75/2.25", "at least 0.25")
end)

Test("after a change: limits, a neutral boost for a second, limits again", function()
    Harness.Objects[World.Hero].Components.EncumbranceStats = {
        UnencumberedWeight = 288000, EncumberedWeight = 336000, HeavilyEncumberedWeight = 360000 }
    local adds, removes = World.Calls.Add, World.Calls.Remove
    Harness.FireMCMSettingSaved("carry_multiplier", 3)
    local log = Log("server.log")
    AssertTrue(string.find(log, "Carry limits before the refresh in kg (UnencumberedWeight/EncumberedWeight/"
        .. "HeavilyEncumberedWeight): S_Player_Hero 288/336/360.", 1, true), "before line")
    AssertTrue(string.find(log, "Carry limits after the refresh in kg", 1, true), "after line")
    AssertEq(World.Calls.Add - adds, 3, "the neutral boost for the three team members")
    AssertEq(World.Calls.Remove - removes, 3, "and removed again")
    AssertEq(World.BoostsOf(World.Hero), "", "no boost stays")
    Harness.Objects[World.Hero].Components.EncumbranceStats = nil
end)

Test("many changes in a row lead to one refresh", function()
    local adds = World.Calls.Add
    for _, value in ipairs({ 2.1, 2.2, 2.3, 2.4 }) do
        Harness.FireMCMSettingSaved("carry_multiplier", value)
    end
    Log("server.log")
    AssertEq(World.Calls.Add - adds, 3, "one neutral boost per team member, not four")
    AssertEq(Values(), "96/24/16.8/21.6", "the last value counts")
end)

Test("the level start writes the values and refreshes", function()
    local adds = World.Calls.Add
    Harness.Listeners["LevelGameplayStarted/2"]("WLD_Main_A", 0)
    AssertTrue(string.find(Log("server.log"), "Level started: multiplier 2.40 (MCM): CarryWeightBase 96,", 1, true),
        "log")
    AssertEq(World.Calls.Add - adds, 3, "refresh")
end)

Test("a missing key is an error in the log, and nothing else happens", function()
    local key, original = "CarryLimitMultiplier", "bg3_carryweightconfig_Original_CarryLimitMultiplier"
    local saved, savedOriginal = World.ExtraData[key], World.ExtraData[original]
    World.ExtraData[key], World.ExtraData[original] = nil, nil
    local adds = World.Calls.Add
    Harness.FireMCMSettingSaved("carry_multiplier", 2)
    AssertTrue(string.find(Log("server.log"), "ERROR in Setting changed: ", 1, true), "error line")
    AssertTrue(string.find(Log("server.log"), "ExtraData has no CarryLimitMultiplier", 1, true), "error text")
    AssertEq(World.Calls.Add, adds, "no refresh")
    World.ExtraData[key], World.ExtraData[original] = saved, savedOriginal
end)

Test("the script clamps to the slider range of the blueprint", function()
    local slider = MCM_BLUEPRINT.Tabs[1].Sections[1].Settings[1]
    AssertEq(slider.Id, CarryData.SettingId, "setting id")
    AssertEq(slider.Options.Min, CarryData.Min, "Min")
    AssertEq(slider.Options.Max, CarryData.Max, "Max")
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
