-- Without the Mod Configuration Menu (missing, or loaded after this mod): the default multiplier 2.0 applies.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }
local World = load(READ_FILE(MOD_LUA_ROOT .. "/../../../../../tests/world.lua"))()

Ext.Require("BootstrapServer.lua")
Ext.Require("BootstrapClient.lua")
local Settings = Ext.Require("Shared/Settings.lua")

Test("without MCM the default 2.0 applies", function()
    AssertEq(MCM, nil, "no MCM table")
    Harness.Listeners["LevelGameplayStarted/2"]("WLD_Main_A", 0)
    AssertEq(World.BoostsOf(World.Hero), "CarryCapacityMultiplier(2.00)", "default boost")
    Harness.RunTimers()
    AssertTrue(string.find(Harness.Files["bg3_carryweightconfig/server.log"] or "",
        "Level started: multiplier 2.00 (default), boost CarryCapacityMultiplier(2.00): 3 changed", 1, true), "log")
end)

Test("OnChange reports that no change can come", function()
    AssertEq(Settings.OnChange(function() end), false, "no subscription")
end)

Test("an unknown setting id is an error", function()
    local ok, message = pcall(Settings.Get, "no_such_setting")
    AssertEq(ok, false, "error")
    AssertTrue(string.find(tostring(message), "unknown setting no_such_setting", 1, true), "message")
end)
