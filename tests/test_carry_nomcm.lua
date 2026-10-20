-- Without the Mod Configuration Menu (missing, or loaded after this mod): the default multiplier 2.0 applies.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 1 } } }
local World = load(READ_FILE(MOD_LUA_ROOT .. "/../../../../../tests/world.lua"))()

Ext.Require("BootstrapServer.lua")
Ext.Require("BootstrapClient.lua")
local Settings = Ext.Require("Shared/Settings.lua")

Test("without MCM the default 2.0 applies", function()
    AssertEq(MCM, nil, "no MCM table")
    Ext.Events.StatsLoaded:Fire()
    local x = World.ExtraData
    AssertEq(string.format("%g/%g/%g/%g", x.CarryWeightBase, x.CarryLimitMultiplier, x.EncumberedMultiplier,
        x.HeavilyEncumberedMultiplier), "80/20/14/18", "game values x 2")
    Harness.RunTimers()
    AssertTrue(string.find(Harness.Files["bg3_carryweightconfig/client.log"] or "",
        "Stats loaded: multiplier 2.00 (default): CarryWeightBase 80,", 1, true), "log")
end)

Test("OnChange reports that no change can come", function()
    AssertEq(Settings.OnChange(function() end), false, "no subscription")
end)

Test("an unknown setting id is an error", function()
    local ok, message = pcall(Settings.Get, "no_such_setting")
    AssertEq(ok, false, "error")
    AssertTrue(string.find(tostring(message), "unknown setting no_such_setting", 1, true), "message")
end)
