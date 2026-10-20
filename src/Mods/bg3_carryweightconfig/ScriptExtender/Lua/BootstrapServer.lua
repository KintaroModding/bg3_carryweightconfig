local Common = Ext.Require("Shared/Common.lua")
local Settings = Ext.Require("Shared/Settings.lua")
local ServerLog = Ext.Require("Server/ServerLog.lua")
Ext.Require("Shared/Vars.lua")

Ext.Events.SessionLoaded:Subscribe(function()
    ServerLog.Add("Carry Weight Config " .. Common.ModVersion() .. " loaded.")
    ServerLog.Add("Settings: " .. Settings.Describe() .. ".")
end)

-- In multiplayer, the host's server holds the values that count: the boosts are given here.
local Carry = Ext.Require("Server/Carry.lua")
Carry.Init()
