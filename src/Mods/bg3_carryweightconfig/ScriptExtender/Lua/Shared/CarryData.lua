-- The carry weight multiplier as the game's own global values: the same keys that a Data.txt mod changes, written
-- while the game runs (Ext.Stats.GetStatsManager().ExtraData). The game computes the three weights of each character
-- as CarryWeightBase + Strength x CarryLimitMultiplier (the limit), x HeavilyEncumberedMultiplier and
-- x EncumberedMultiplier (game log 2026-10-20, Strength 8: 96/112/120 kg = 40 + 8 x 7, 9, 10). Multiplying all four
-- values by the factor multiplies the three weights by it, for every character. Nothing of it is in a save: the game
-- reads its values at start and the mod writes them again in every session.

local Settings = Ext.Require("Shared/Settings.lua")

local CarryData = {}

CarryData.SettingId = "carry_multiplier"
-- The range of the slider in MCM_blueprint.json; values outside it are clamped.
CarryData.Min, CarryData.Max = 0.25, 90.0
CarryData.Keys = { "CarryWeightBase", "CarryLimitMultiplier", "EncumberedMultiplier", "HeavilyEncumberedMultiplier" }
-- The values before this mod, kept in ExtraData itself under these extra keys. The values stay in the game process
-- across session loads while the Lua state starts again, so a value read later could already be multiplied; these
-- keys keep the originals as long as the values live (a reload of the stats clears both).
CarryData.OriginalPrefix = "bg3_carryweightconfig_Original_"

--- The multiplier to use, clamped and rounded to two decimals, and its source ("MCM" or "default").
function CarryData.Multiplier()
    local value, source = Settings.Get(CarryData.SettingId)
    value = math.min(CarryData.Max, math.max(CarryData.Min, value))
    return math.floor(value * 100 + 0.5) / 100, source
end

--- Writes original x multiplier into every key. Returns the multiplier, its source, and a log text such as
--- "CarryWeightBase 80, CarryLimitMultiplier 20, EncumberedMultiplier 14, HeavilyEncumberedMultiplier 18". Raises an
--- error when a key is missing.
function CarryData.Apply()
    local extra = Ext.Stats.GetStatsManager().ExtraData
    local multiplier, source = CarryData.Multiplier()
    local parts = {}
    for _, key in ipairs(CarryData.Keys) do
        local original = extra[CarryData.OriginalPrefix .. key]
        if original == nil then
            original = extra[key]
            if original == nil then
                error("ExtraData has no " .. key)
            end
            extra[CarryData.OriginalPrefix .. key] = original
        end
        local value = original * multiplier
        if extra[key] ~= value then
            extra[key] = value
        end
        parts[#parts + 1] = string.format("%s %g", key, value)
    end
    return multiplier, source, table.concat(parts, ", ")
end

--- Apply, protected, with one log line: "<reason>: multiplier 2.00 (MCM): CarryWeightBase 80, ...".
function CarryData.ApplyAndLog(reason, log)
    local ok, multiplier, source, values = pcall(CarryData.Apply)
    if ok then
        log.Add(string.format("%s: multiplier %.2f (%s): %s.", reason, multiplier, source, values))
    else
        log.Add("ERROR in " .. reason .. ": " .. tostring(multiplier))
    end
    return ok
end

return CarryData
