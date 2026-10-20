-- The server side of the carry weight multiplier. The values themselves are global game values
-- (Shared/CarryData.lua), written on SessionLoaded (no Osiris needed) and after each MCM change. The game keeps the
-- computed weights of each character in the component EncumbranceStats; after a change, this module logs them,
-- gives the party a neutral boost for a moment so that the game computes them again, and logs them once more.

local CarryData = Ext.Require("Shared/CarryData.lua")
local Settings = Ext.Require("Shared/Settings.lua")
local ServerLog = Ext.Require("Server/ServerLog.lua")

local Carry = {}

Carry.SourceId = "bg3_carryweightconfig"
-- A boost that changes nothing (only the highest carry multiplier counts, and 1.00 is the game's own). Adding it makes
-- the game compute the weights again; it is removed a second later.
Carry.RefreshBoost = "CarryCapacityMultiplier(1.00)"
-- The empty cause, as the game's own story procedures pass it.
local NO_CAUSE = "NULL_00000000-0000-0000-0000-000000000000"

--- The UUID part of an Osiris GUID string (the last 36 characters).
local function Uuid(guid)
    return string.sub(guid, -36)
end

--- A short name for the log: the GUID string without its UUID, or the UUID when there is no name.
local function Short(guid)
    local name = string.sub(guid, 1, -38)
    return name ~= "" and name or guid
end

--- The party members (DB_Players) and camp companions (DB_PartOfTheTeam), each once, without summons. Osiris: not in
--- SessionLoaded (playbook knowledge\boosts.md).
function Carry.Team()
    local team, seen = {}, {}
    for _, db in ipairs({ "DB_Players", "DB_PartOfTheTeam" }) do
        for _, row in ipairs(Osi[db]:Get(nil) or {}) do
            local character = row[1]
            if not seen[Uuid(character)] then
                seen[Uuid(character)] = true
                if Osi.IsSummon(character) ~= 1 then
                    team[#team + 1] = character
                end
            end
        end
    end
    return team
end

--- Logs the weights the game computed for the team, in kg (EncumbranceStats holds grams).
local function LogLimits(label)
    local ok, err = pcall(function()
        local parts = {}
        for _, character in ipairs(Carry.Team()) do
            local found, stats = pcall(function()
                return Ext.Entity.Get(character).EncumbranceStats
            end)
            if found and stats ~= nil then
                parts[#parts + 1] = string.format("%s %g/%g/%g", Short(character), stats.UnencumberedWeight / 1000,
                    stats.EncumberedWeight / 1000, stats.HeavilyEncumberedWeight / 1000)
            end
        end
        if #parts > 0 then
            ServerLog.Add("Carry limits " .. label .. " in kg (UnencumberedWeight/EncumberedWeight/"
                .. "HeavilyEncumberedWeight): " .. table.concat(parts, ", ") .. ".")
        end
    end)
    if not ok then
        ServerLog.Add("ERROR while reading the carry limits: " .. tostring(err))
    end
end

-- Counts the refreshes, so that only the newest one runs (a slider moved in many steps starts many).
local refreshGeneration = 0

--- One second after a change, logs the weights; then lets the game compute them again (the neutral boost for a
--- second) and logs them once more. The two lines show whether the game picked the new values up by itself. A
--- refresh that a newer change replaced stops before it adds anything.
function Carry.Refresh(reason)
    refreshGeneration = refreshGeneration + 1
    local generation = refreshGeneration
    Ext.Timer.WaitForRealtime(1000, function()
        if generation ~= refreshGeneration then
            return
        end
        LogLimits("before the refresh")
        local ok, err = pcall(function()
            local team = Carry.Team()
            for _, character in ipairs(team) do
                Osi.AddBoosts(character, Carry.RefreshBoost, Carry.SourceId, NO_CAUSE)
            end
            -- Removed in a later moment: removing and adding the same text in one go leaves no boost
            -- (knowledge\boosts.md), here it must first be there.
            Ext.Timer.WaitForRealtime(1000, function()
                local done, problem = pcall(function()
                    for _, character in ipairs(team) do
                        Osi.RemoveBoosts(character, Carry.RefreshBoost, 0, Carry.SourceId, NO_CAUSE)
                    end
                end)
                if not done then
                    ServerLog.Add("ERROR in " .. reason .. " (refresh end): " .. tostring(problem))
                end
                Ext.Timer.WaitForRealtime(1000, function()
                    LogLimits("after the refresh")
                end)
            end)
        end)
        if not ok then
            ServerLog.Add("ERROR in " .. reason .. " (refresh): " .. tostring(err))
        end
    end)
end

function Carry.Init()
    -- ExtraData can be written in SessionLoaded (a restricted context only blocks Osiris).
    Ext.Events.SessionLoaded:Subscribe(function()
        CarryData.ApplyAndLog("Session loaded", ServerLog)
    end)
    Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function()
        CarryData.ApplyAndLog("Level started", ServerLog)
        Carry.Refresh("Level started")
    end)
    -- MCM: a saved setting of this mod, or a profile switch (settingId nil).
    Settings.OnChange(function(settingId)
        if settingId == nil or settingId == CarryData.SettingId then
            local reason = settingId and "Setting changed" or "MCM profile changed"
            if CarryData.ApplyAndLog(reason, ServerLog) then
                Carry.Refresh(reason)
            end
        end
    end)
end

return Carry
