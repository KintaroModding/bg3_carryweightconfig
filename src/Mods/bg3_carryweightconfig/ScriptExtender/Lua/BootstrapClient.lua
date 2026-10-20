local Common = Ext.Require("Shared/Common.lua")
local ClientLog = Ext.Require("Client/ClientLog.lua")
Ext.Require("Shared/Vars.lua")

Ext.Events.SessionLoaded:Subscribe(function()
    ClientLog.Add("Carry Weight Config " .. Common.ModVersion() .. " loaded.")
end)
