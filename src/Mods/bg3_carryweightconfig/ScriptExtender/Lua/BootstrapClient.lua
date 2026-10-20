local Common = Ext.Require("Shared/Common.lua")
local CarryData = Ext.Require("Shared/CarryData.lua")
local Settings = Ext.Require("Shared/Settings.lua")
local ClientLog = Ext.Require("Client/ClientLog.lua")
Ext.Require("Shared/Vars.lua")

-- Each game process has its own global values: the client writes them too (on the host, client and server share
-- them; a remote player's game needs its own write). StatsLoaded fires only here, before a save loads.
Ext.Events.StatsLoaded:Subscribe(function()
    CarryData.ApplyAndLog("Stats loaded", ClientLog)
end)

Ext.Events.SessionLoaded:Subscribe(function()
    ClientLog.Add("Carry Weight Config " .. Common.ModVersion() .. " loaded.")
    CarryData.ApplyAndLog("Session loaded", ClientLog)
end)

Settings.OnChange(function(settingId)
    if settingId == nil or settingId == CarryData.SettingId then
        CarryData.ApplyAndLog(settingId and "Setting changed" or "MCM profile changed", ClientLog)
    end
end)
