-- A small Osiris world for the tests: party members, camp companions, a summon, and the boosts that AddBoosts and
-- RemoveBoosts change. Load it in a test file with:
--   local World = load(READ_FILE(MOD_LUA_ROOT .. "/../../../../../tests/world.lua"))()
--
-- As in the game (game log 2026-10-20), boost requests do not act at once: they wait until somebody looks at the
-- boosts again. Then the additions run first and the removals second, so removing and adding the same boost text in
-- one go leaves the character without it. Each character also has a BoostsContainer component (the layout of the
-- Script Extender, BG3Extender Components/Boosts.h) that shows its carry boosts.

local World = {}

local NO_CAUSE = "NULL_00000000-0000-0000-0000-000000000000"

--- An Osiris GUID string: name and a 36-character UUID made from the number.
function World.Guid(name, n)
    return string.format("%s_%08d-0000-0000-0000-%012d", name, n, n)
end

World.Hero = World.Guid("S_Player_Hero", 1)
World.Shadowheart = World.Guid("S_Player_ShadowHeart", 2)
World.Gale = World.Guid("S_Player_Gale", 3) -- a camp companion
World.Wolf = World.Guid("S_Summon_Wolf", 4) -- a summon in the party
World.Karlach = World.Guid("S_Player_Karlach", 5) -- joins later

-- [uuid] = { Guid, Player (DB_Players), Team (DB_PartOfTheTeam), Summon, Boosts = { [text] = count } }
World.Characters = {}
World.Calls = { Add = 0, Remove = 0 }
World.Pending = {}

local function Uuid(guid)
    return string.sub(guid, -36)
end

--- Runs the waiting boost requests: additions first, then removals.
function World.Flush()
    local pending = World.Pending
    World.Pending = {}
    for _, kind in ipairs({ "add", "remove" }) do
        for _, request in ipairs(pending) do
            if request.Kind == kind then
                local boosts = World.Characters[request.Uuid].Boosts
                if kind == "add" then
                    boosts[request.Text] = (boosts[request.Text] or 0) + 1
                else
                    boosts[request.Text] = nil
                end
            end
        end
    end
end

--- A BoostsContainer component that shows the character's carry boosts as they are now.
local function BoostsContainer(uuid)
    return setmetatable({}, {
        __index = function(_, key)
            if key ~= "Boosts" then
                return nil
            end
            World.Flush()
            local carry = {}
            for text, count in pairs(World.Characters[uuid].Boosts) do
                local value = tonumber(string.match(text, "^CarryCapacityMultiplier%(([%d%.]+)%)$"))
                for _ = 1, value and count or 0 do
                    carry[#carry + 1] = { CarryCapacityMultiplierBoost = { Multiplier = value } }
                end
            end
            return { { Type = "Ability", Boosts = {} }, { Type = "CarryCapacityMultiplier", Boosts = carry } }
        end,
    })
end

function World.Add(guid, fields)
    fields.Guid = guid
    fields.Boosts = fields.Boosts or {}
    World.Characters[Uuid(guid)] = fields
    Harness.Objects[guid] = { Components = { BoostsContainer = BoostsContainer(Uuid(guid)) } }
    return fields
end

function World.Reset()
    World.Characters = {}
    World.Calls = { Add = 0, Remove = 0 }
    World.Pending = {}
    Harness.Objects = {}
    World.Add(World.Hero, { Player = true, Team = true })
    World.Add(World.Shadowheart, { Player = true, Team = true })
    World.Add(World.Gale, { Team = true })
    World.Add(World.Wolf, { Player = true, Summon = true })
end

--- The boosts of a character, as "text x count" pieces sorted, for example "CarryCapacityMultiplier(2.50)".
function World.BoostsOf(guid)
    World.Flush()
    local character = World.Characters[Uuid(guid)]
    local parts = {}
    for text, count in pairs(character and character.Boosts or {}) do
        parts[#parts + 1] = count == 1 and text or (text .. " x" .. count)
    end
    table.sort(parts)
    return table.concat(parts, ", ")
end

local function Rows(field)
    local rows = {}
    for _, character in pairs(World.Characters) do
        if character[field] then
            rows[#rows + 1] = { character.Guid }
        end
    end
    table.sort(rows, function(a, b) return a[1] < b[1] end)
    return rows
end

Osi.DB_Players = { Get = function(_, _) return Rows("Player") end }
Osi.DB_PartOfTheTeam = { Get = function(_, _) return Rows("Team") end }
Osi.IsSummon = function(guid)
    return World.Characters[Uuid(guid)].Summon and 1 or 0
end
Osi.Exists = function(guid)
    return World.Characters[Uuid(guid)] ~= nil and 1 or 0
end
Osi.AddBoosts = function(guid, text, source, cause)
    assert(source == "bg3_carryweightconfig" and cause == NO_CAUSE, "AddBoosts: source and cause")
    World.Pending[#World.Pending + 1] = { Kind = "add", Uuid = Uuid(guid), Text = text }
    World.Calls.Add = World.Calls.Add + 1
end
-- Removing a boost that the character does not have changes nothing.
Osi.RemoveBoosts = function(guid, text, onlyFirst, source, cause)
    assert(onlyFirst == 0 and source == "bg3_carryweightconfig" and cause == NO_CAUSE, "RemoveBoosts arguments")
    World.Pending[#World.Pending + 1] = { Kind = "remove", Uuid = Uuid(guid), Text = text }
    World.Calls.Remove = World.Calls.Remove + 1
end

World.Reset()
return World
