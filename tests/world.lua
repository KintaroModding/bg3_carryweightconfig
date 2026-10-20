-- A small Osiris world for the tests: party members, camp companions, a summon, and the boosts that AddBoosts and
-- RemoveBoosts change. Load it in a test file with:
--   local World = load(READ_FILE(MOD_LUA_ROOT .. "/../../../../../tests/world.lua"))()

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

local function Uuid(guid)
    return string.sub(guid, -36)
end

function World.Add(guid, fields)
    fields.Guid = guid
    fields.Boosts = fields.Boosts or {}
    World.Characters[Uuid(guid)] = fields
    return fields
end

function World.Reset()
    World.Characters = {}
    World.Calls = { Add = 0, Remove = 0 }
    World.Add(World.Hero, { Player = true, Team = true })
    World.Add(World.Shadowheart, { Player = true, Team = true })
    World.Add(World.Gale, { Team = true })
    World.Add(World.Wolf, { Player = true, Summon = true })
end

--- The boosts of a character, as "text x count" pieces sorted, for example "CarryCapacityMultiplier(2.50)".
function World.BoostsOf(guid)
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
    local boosts = World.Characters[Uuid(guid)].Boosts
    boosts[text] = (boosts[text] or 0) + 1
    World.Calls.Add = World.Calls.Add + 1
end
-- Removing a boost that the character does not have changes nothing (assumed for the game; a loaded game has lost
-- the boosts that the saved record lists).
Osi.RemoveBoosts = function(guid, text, onlyFirst, source, cause)
    assert(onlyFirst == 0 and source == "bg3_carryweightconfig" and cause == NO_CAUSE, "RemoveBoosts arguments")
    World.Characters[Uuid(guid)].Boosts[text] = nil
    World.Calls.Remove = World.Calls.Remove + 1
end

World.Reset()
return World
