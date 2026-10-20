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
Carry.Min, Carry.Max = 0.25, 90.0
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

--- The CarryCapacityMultiplier values a character has now (numbers), read from its boost components, or nil when
--- the components cannot be read. Reading works (game log 2026-10-20: Gale and Wyll showed 1.25, the boost of Human
--- Versatility).
local function CarryValuesOf(character)
    local ok, values = pcall(function()
        local found = {}
        for _, entry in pairs(Ext.Entity.Get(character).BoostsContainer.Boosts) do
            if tostring(entry.Type) == "CarryCapacityMultiplier" then
                for _, boost in pairs(entry.Boosts) do
                    found[#found + 1] = boost.CarryCapacityMultiplierBoost.Multiplier
                end
            end
        end
        return found
    end)
    return ok and values or nil
end

--- The same for the log: "90", "1.25+90" (several), "none", or "?" when the components cannot be read.
local function CarryBoostsOf(character)
    local values = CarryValuesOf(character)
    if values == nil then
        return "?"
    end
    local parts = {}
    for _, value in ipairs(values) do
        parts[#parts + 1] = string.format("%g", math.floor(value * 100 + 0.5) / 100)
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, "+") or "none"
end

--- True when the character has a carry boost of this multiplier now; false when not, or when it cannot be read.
local function HasCarryBoost(character, multiplier)
    for _, value in ipairs(CarryValuesOf(character) or {}) do
        if math.abs(value - multiplier) < 0.005 then
            return true
        end
    end
    return false
end

--- One second later (the game recalculates the limits after a boost change), logs the weights the game computed
--- (the component EncumbranceStats holds them in grams) and the carry boosts each character has.
local function LogLimits()
    Ext.Timer.WaitForRealtime(1000, function()
        local done, err = pcall(function()
            local parts = {}
            for _, character in ipairs(Carry.Team()) do
                local ok, stats = pcall(function()
                    return Ext.Entity.Get(character).EncumbranceStats
                end)
                if ok and stats ~= nil then
                    parts[#parts + 1] = string.format("%s %g/%g/%g [%s]", Short(character),
                        stats.UnencumberedWeight / 1000, stats.EncumberedWeight / 1000,
                        stats.HeavilyEncumberedWeight / 1000, CarryBoostsOf(character))
                end
            end
            if #parts > 0 then
                ServerLog.Add("Carry limits in kg (UnencumberedWeight/EncumberedWeight/HeavilyEncumberedWeight) "
                    .. "[carry boosts]: " .. table.concat(parts, ", ") .. ".")
            end
        end)
        if not done then
            ServerLog.Add("ERROR while reading the carry limits: " .. tostring(err))
        end
    end)
end

-- What this mod gave in this session: [character UUID] = boost text. nil until the first apply of the session. The
-- game starts the Lua state again for every session, so this starts empty after each load.
local sessionApplied = nil

--- For the tests: forget the session, as a new game session does.
function Carry.ResetSession()
    sessionApplied = nil
end

--- Gives every team member the boost of the current multiplier and removes old boosts of this mod, also from
--- characters that left the team. Writes one log line with the reason.
---
--- A loaded game does not have the boosts any more (game log 2026-10-20: "none" after a load, although the saved
--- record listed them). So the first apply of a session, and every apply with renewAll, trusts no record: it looks at
--- the character's boosts and adds the boost only when it is missing. It never removes and adds the same boost text
--- at once: the game then drops the new boost (game log 2026-10-20: still "none" after such a renewal). A different
--- old boost is removed first, as a slider change does.
local function Apply(reason, renewAll)
    local multiplier, source = Carry.Multiplier()
    local boost = Carry.Boost(multiplier)
    local renew = renewAll == true or sessionApplied == nil
    local applied = renew and LoadApplied() or sessionApplied
    local inTeam = {}
    local changed, unchanged, removed = 0, 0, 0

    local team = Carry.Team()
    if renew then
        local found = {}
        for _, character in ipairs(team) do
            found[#found + 1] = Short(character) .. " " .. CarryBoostsOf(character)
        end
        ServerLog.Add(reason .. ": renewing all boosts. Carry boosts found: " .. table.concat(found, ", ") .. ".")
    end

    for _, character in ipairs(team) do
        local uuid = Uuid(character)
        inTeam[uuid] = true
        local old = applied[uuid]
        if old == boost and (not renew or boost == nil or HasCarryBoost(character, multiplier)) then
            unchanged = unchanged + 1
        else
            if old ~= nil and old ~= boost then
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

    sessionApplied = applied
    SaveApplied(applied)
    ServerLog.Add(string.format("%s: multiplier %.2f (%s), boost %s: %d changed, %d unchanged, %d removed (left the team).",
        reason, multiplier, source, boost or "none", changed, unchanged, removed))
    if changed > 0 or removed > 0 then
        LogLimits()
    end
end

--- Apply, protected: an error goes into server.log (the Script Extender console is not visible from here), and the
--- next event tries again.
function Carry.Apply(reason, renewAll)
    local ok, err = pcall(Apply, reason, renewAll)
    if not ok then
        ServerLog.Add("ERROR in " .. reason .. ": " .. tostring(err))
    end
end

-- A safety check after this delay: the level start looks at everyone's boosts once more and adds only what is
-- missing. Boosts added at LevelGameplayStarted do count (game log 2026-10-20, the fourth test); the failed loads
-- before came from removing and adding the same boost text in one go (playbook knowledge\boosts.md).
Carry.RenewDelayMs = 3000

function Carry.Init()
    -- No apply on SessionLoaded: Osiris databases cannot be read then ("Attempted to read Osiris database in
    -- restricted context", game log 2026-10-20).
    Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function()
        Carry.Apply("Level started", true)
        Ext.Timer.WaitForRealtime(Carry.RenewDelayMs, function()
            Carry.Apply(string.format("%g s after the level start", Carry.RenewDelayMs / 1000), true)
        end)
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
