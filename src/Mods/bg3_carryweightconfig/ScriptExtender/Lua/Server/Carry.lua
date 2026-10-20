-- The carry weight multiplier. Every party member and camp companion gets the game's boost
-- CarryCapacityMultiplier(<multiplier>) through Osiris AddBoosts, with this mod as the source. The game itself uses
-- this boost (Bull's Strength 2.0, Enlarge 1.25, Aspect of the Bear 2). A change removes the old boost first; the
-- boost text each character got is kept in the mod variable AppliedBoosts (Shared/Vars.lua).

local Settings = Ext.Require("Shared/Settings.lua")
local ServerLog = Ext.Require("Server/ServerLog.lua")

local Carry = {}

Carry.SettingId = "carry_multiplier"
Carry.SourceId = "bg3_carryweightconfig"
-- The range of the slider in MCM_blueprint.json; values outside it (for example from an edited settings file) are
-- clamped.
Carry.Min, Carry.Max = 1.0, 10.0
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

--- The multiplier to use, clamped and rounded to two decimals, and its source ("MCM" or "default").
function Carry.Multiplier()
    local value, source = Settings.Get(Carry.SettingId)
    value = math.min(Carry.Max, math.max(Carry.Min, value))
    return math.floor(value * 100 + 0.5) / 100, source
end

--- The boost text for a multiplier, or nil for 1.0 (the game's own limit needs no boost).
function Carry.Boost(multiplier)
    if multiplier == 1.0 then
        return nil
    end
    return string.format("CarryCapacityMultiplier(%.2f)", multiplier)
end

--- The party members (DB_Players) and camp companions (DB_PartOfTheTeam), each once, without summons.
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

local function LoadApplied()
    local ok, saved = pcall(function()
        return Ext.Vars.GetModVariables(ModuleUUID).AppliedBoosts
    end)
    local applied = {}
    if ok and type(saved) == "table" then
        for uuid, boost in pairs(saved) do
            applied[uuid] = boost
        end
    end
    return applied
end

local function SaveApplied(applied)
    Ext.Vars.GetModVariables(ModuleUUID).AppliedBoosts = applied
end

--- One second later (the game recalculates the limits after a boost change), logs the weights the game computed:
--- the component EncumbranceStats holds them in grams.
local function LogLimits()
    Ext.Timer.WaitForRealtime(1000, function()
        local parts = {}
        for _, character in ipairs(Carry.Team()) do
            local ok, stats = pcall(function()
                return Ext.Entity.Get(character).EncumbranceStats
            end)
            if ok and stats ~= nil then
                parts[#parts + 1] = string.format("%s %g/%g/%g", Short(character), stats.UnencumberedWeight / 1000,
                    stats.EncumberedWeight / 1000, stats.HeavilyEncumberedWeight / 1000)
            end
        end
        if #parts > 0 then
            ServerLog.Add("Carry limits in kg (UnencumberedWeight/EncumberedWeight/HeavilyEncumberedWeight): "
                .. table.concat(parts, ", ") .. ".")
        end
    end)
end

--- Gives every team member the boost of the current multiplier and removes old boosts of this mod, also from
--- characters that left the team. Writes one log line with the reason.
function Carry.Apply(reason)
    local multiplier, source = Carry.Multiplier()
    local boost = Carry.Boost(multiplier)
    local applied = LoadApplied()
    local inTeam = {}
    local changed, unchanged, removed = 0, 0, 0

    for _, character in ipairs(Carry.Team()) do
        local uuid = Uuid(character)
        inTeam[uuid] = true
        local old = applied[uuid]
        if old == boost then
            unchanged = unchanged + 1
        else
            if old ~= nil then
                Osi.RemoveBoosts(character, old, 0, Carry.SourceId, NO_CAUSE)
            end
            if boost ~= nil then
                Osi.AddBoosts(character, boost, Carry.SourceId, NO_CAUSE)
            end
            applied[uuid] = boost
            changed = changed + 1
        end
    end

    for uuid, old in pairs(applied) do
        if not inTeam[uuid] then
            if Osi.Exists(uuid) == 1 then
                Osi.RemoveBoosts(uuid, old, 0, Carry.SourceId, NO_CAUSE)
            end
            applied[uuid] = nil
            removed = removed + 1
        end
    end

    SaveApplied(applied)
    ServerLog.Add(string.format("%s: multiplier %.2f (%s), boost %s: %d changed, %d unchanged, %d removed (left the team).",
        reason, multiplier, source, boost or "none", changed, unchanged, removed))
    if changed > 0 or removed > 0 or reason == "Session loaded" then
        LogLimits()
    end
end

function Carry.Init()
    Ext.Events.SessionLoaded:Subscribe(function()
        Carry.Apply("Session loaded")
    end)
    Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function()
        Carry.Apply("Level started")
    end)
    Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(character)
        Carry.Apply("Joined the party: " .. Short(character))
    end)
    Ext.Osiris.RegisterListener("CharacterLeftParty", 1, "after", function(character)
        Carry.Apply("Left the party: " .. Short(character))
    end)
    -- MCM: a saved setting of this mod, or a profile switch (settingId nil).
    Settings.OnChange(function(settingId)
        if settingId == nil or settingId == Carry.SettingId then
            Carry.Apply(settingId and "Setting changed" or "MCM profile changed")
        end
    end)
end

return Carry
