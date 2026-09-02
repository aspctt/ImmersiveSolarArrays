--[[
    Stash house definitions for the mod's solar caches.

    Shared, because the annotated map is drawn client side while the building and its
    loot are prepared server side.
--]]

require "StashDescriptions/StashUtil"
local ISA = require "ImmersiveSolarArrays/Utilities"

local Stash = { descriptions = {} }

--- StashUtil has no __index, so making it a metatable does not give a stash its methods
--- and the first addStamp call fails, taking every stash in this file with it. Vanilla
--- copies the two methods onto each stash in StashUtil.newStash, and so does this.
function Stash.newStash(obj,mod)
    obj.addStamp = StashUtil.addStamp
    obj.addContainer = StashUtil.addContainer
    Stash.descriptions[obj] = mod
    return obj
end

local stashMap = Stash.newStash({
    name = "ISA_Stash_RiversideW1",
    type = "Map",
    item = "ISA.Stash_RiversideW1",
    customName = "Stash_AnnotedMap",
    buildingX = 4538,
    buildingY = 5727,
    barricades = 80,
    spawnOnlyOnZed = true,
    spawnTable = "ISASolarBoxCache",
    containers = {
        { containerType = "SolarBox", containerSprite = "solarmod_tileset_01_36", contX = 4542, contY = 5719, contZ = 0 }
    }
},
{
    knownOnStart = 90,
    rarity = 0.6,
    targets = {"inventoryfemale","inventorymale","Outfit_Foreman"}
})
stashMap:addStamp(nil, "Stash_ISA_Stash_RiversideW1_t1", 5497, 5962, 0, 0, 1)
stashMap:addStamp(nil, "Stash_ISA_Stash_RiversideW1_t2", 5410, 5845, 0, 0, 1)
stashMap:addStamp("Exclamation", nil, 5538, 5953, 0, 0, 0)
stashMap:addStamp("ArrowWest", nil, 5451, 5835, 0, 0, 0)
stashMap:addStamp("Question", nil, 5412, 5835, 0, 0, 0)
stashMap:addStamp("X", nil, 5415, 6106, 0, 0, 0)
stashMap:addStamp("X", nil, 5408, 6056, 0, 0, 0)

local stashMap = Stash.newStash({
    name = "ISA_Stash_RosewoodE1",
    type = "Map",
    item = "ISA.Stash_RosewoodE1",
    customName = "Stash_AnnotedMap",
    buildingX = 9069,
    buildingY = 12425,
    barricades = 60,
    spawnOnlyOnZed = true,
    spawnTable = "ISASolarBoxCache",
    containers = {
        { containerType = "SolarBox", containerSprite = "solarmod_tileset_01_36", contX = 9064, contY = 12423, contZ = 1 }
    }
},
{
    knownOnStart = 90,
    rarity = 0.6,
    targets = {"inventoryfemale","inventorymale","Outfit_Inmate"}
})
stashMap:addStamp(nil, "Stash_ISA_Stash_RosewoodE1_t1", 8071, 12101, 0, 0, 0)
stashMap:addStamp("House", nil, 8116, 12227, 0, 0, 0)
stashMap:addStamp("Fish", nil, 8171, 12188, 0, 0, 0)
stashMap:addStamp("Lock", nil, 8245, 12233, 0, 0, 0)
stashMap:addStamp("Lock", nil, 8285, 12211, 0, 0, 0)
stashMap:addStamp(nil, "Stash_ISA_Stash_RosewoodE1_t2", 8208, 12313, 1, 0, 0)
stashMap:addStamp("Question", nil, 8388, 12300, 0, 0, 0)
stashMap:addStamp("Question", nil, 8388, 12320, 0, 0, 0)
stashMap:addStamp("Question", nil, 8388, 12340, 0, 0, 0)

local stashMap = Stash.newStash({
    name = "ISA_Stash_Muldraugh1",
    type = "Map",
    item = "Base.MuldraughMap",
    customName = "Stash_AnnotedMap",
    buildingX = 10653,
    buildingY = 9715,
    zombies = 8,
    barricades = 40,
    spawnOnlyOnZed = false,
    spawnTable = "ISASolarBoxCache",
    -- Was 10655,9720, which is outside every room of this house: the garage it belongs
    -- to is x 10652..10656, y 9711..9715, and 9720 lands in the gap behind it. See the
    -- note on the Westpoint crate below for why a square outside a room is fatal.
    containers = {
        { containerType = "SolarBox", containerSprite = "solarmod_tileset_01_36", contX = 10654, contY = 9713, contZ = 0 }
    }
},
{
    knownOnStart = 90,
})
stashMap:addStamp("Target", nil, 10653, 9717, 0, 0, 0)
stashMap:addStamp(nil, "Stash_ISA_Stash_Muldraugh1_t1", 10663, 9708, 0, 0, 0)
stashMap:addStamp("FaceDead", nil, 10701, 9355, 0, 0, 0)
stashMap:addStamp(nil, "Stash_ISA_Stash_Muldraugh1_t2", 10710, 9346, 0, 0, 0)
stashMap:addStamp("Cross", nil, 10726, 9327, 0, 0, 0)

local stashMap = Stash.newStash({
    name = "ISA_Stash_Westpoint1",
    type = "Map",
    item = "Base.WestpointMap",
    customName = "Stash_AnnotedMap",
    buildingX = 11574,
    buildingY = 6768,
    barricades = 60,
    spawnOnlyOnZed = true,
    spawnTable = "ISASolarBoxCache",
    --- The crate square, and what has to be true of it.
    --- StashSystem builds the crate at contX, contY, contZ with no fallback: given
    --- explicit coordinates it calls getGridSquare and, if that answers nil, logs a line
    --- and moves on. Then doBuildingStash fills every container in the house whose type
    --- the spawn table names, but only where the square has a room and that room belongs
    --- to this building. A crate outside a room is therefore never stocked even when it
    --- does appear, which is a stash house holding nothing, with nothing in the log to
    --- say why.
    ---
    --- This was z 1. The house is single storey: its rooms are all at z 0 and the only
    --- thing above them is roof. So the crate was asked for on a floor that does not
    --- exist. At z 0 the same x and y is the bedroom, which is where it was meant to be.
    containers = {
        { containerType = "SolarBox", containerSprite = "solarmod_tileset_01_36", contX = 11577, contY = 6768, contZ = 0 }
    }
},
{
    knownOnStart = 90,
})
stashMap:addStamp(nil, "Stash_ISA_Stash_Westpoint1_t1", 10912, 7330, 1, 0, 0)
stashMap:addStamp(nil, "Stash_ISA_Stash_Westpoint1_t2", 11588, 7431, 0, 0, 0)
stashMap:addStamp(nil, "Stash_ISA_Stash_Westpoint1_t3", 11554, 6890, 0, 0, 0)
stashMap:addStamp("Skull", nil, 11737, 7182, 0, 0, 0)
stashMap:addStamp("Skull", nil, 12106, 7182, 0, 0, 0)
stashMap:addStamp("Skull", nil, 12229, 6899, 0, 0, 0)
stashMap:addStamp("Skull", nil, 10838, 7048, 0, 0, 0)

local stashMap = Stash.newStash({
    name = "ISA_Stash_Louisville1",
    type = "Map",
    item = "ISA.Stash_Louisville1",
    customName = "Stash_AnnotedMap",
    buildingX = 13133,
    buildingY = 2944,
    barricades = 60,
    spawnOnlyOnZed = true,
    traps = "1",
    spawnTable = "ISASolarBoxCache",
    containers = {
        { containerType = "SolarBox", containerSprite = "solarmod_tileset_01_36", contX = 13135, contY = 2940, contZ = 0 }
    }
},
{
    knownOnStart = false,
    rarity = 0.1,
    targets = {"inventoryfemale","inventorymale","Outfit_Survivalist","Outfit_Bandit"}
})
stashMap:addStamp("House", nil, 13133, 2946, 0, 0, 1)
stashMap:addStamp(nil, "Stash_ISA_Stash_Louisville1_t1", 13277, 3086, 0, 0, 0)
stashMap:addStamp("Skull", nil, 13039, 2999, 1, 0, 0)
stashMap:addStamp("Skull", nil, 13039, 2926, 1, 0, 0)
stashMap:addStamp("Skull", nil, 13316, 2999, 1, 0, 0)
stashMap:addStamp("Skull", nil, 13198, 3055, 1, 0, 0)
stashMap:addStamp("Skull", nil, 13417, 2898, 1, 0, 0)
stashMap:addStamp("DollarSign", nil, 13350, 3062, 1, 0, 0)
stashMap:addStamp("Circle", nil, 13349, 3043, 0, 0, 0)
stashMap:addStamp("Trap", nil, 13066, 2926, 0, 0, 0)
stashMap:addStamp("Trap", nil, 13064, 2997, 0, 0, 0)
stashMap:addStamp("Trap", nil, 13200, 3001, 0, 0, 0)
stashMap:addStamp("ArrowSouthEast", nil, 13193, 2929, 1, 0, 0)
stashMap:addStamp("ArrowSouthEast", nil, 13257, 3001, 1, 0, 0)
stashMap:addStamp("X", nil, 13317, 3000, 0, 0, 0)
stashMap:addStamp("X", nil, 13039, 2926, 0, 0, 0)

function Stash.prepareBuildingStash()
    local ZombRand, StashSystem = ZombRand, StashSystem
    for stashMap, customDef in pairs(Stash.descriptions) do
        if customDef.knownOnStart and ZombRand(100) < customDef.knownOnStart then
            StashSystem.prepareBuildingStash(stashMap.name)
        end
    end
end

function Stash.insertItems(addMapItems)
    if not StashDescriptions then
        print("ISA: no StashDescriptions table, stash houses skipped")
        return
    end

    -- The map items ride along in the loot tables, which only the machine running the
    -- distributions has. A multiplayer client still registers the stashes themselves,
    -- because that is what draws the annotated map.
    local all = SuburbsDistributions and SuburbsDistributions.all
    local canAddMapItems = addMapItems and all ~= nil and ISA.Distributions ~= nil

    for stashMap, customDef in pairs(Stash.descriptions) do
        table.insert(StashDescriptions, stashMap)
        if canAddMapItems and customDef.rarity and customDef.targets then
            ISA.Distributions.insertItemsToMultipleLists(all,customDef.targets,{stashMap.item,customDef.rarity})
        end
    end
    if canAddMapItems then
        ItemPickerJava.doParse = true
    end
end

--- Put the mod's stashes back into the list the engine annotates maps from.
---
--- StashSystem keeps two lists. allStashes is every stash it knows about, rebuilt from
--- the Lua descriptions each time the world starts. possibleStashes is the ones still
--- worth finding, and checkStashItem refuses to annotate a map for any stash that is not
--- in it. IsoWorld.init fills both from Lua, and then loads the map metadata, which
--- replaces possibleStashes wholesale with whatever the save stored.
---
--- On a world that already existed, that second step drops every stash this mod added.
--- The map items still spawn, because they come from the loot tables, they just arrive
--- with nothing drawn on them: the right patch of Kentucky and not one marker.
---
--- Runs after the world is up, and only adds back a stash whose map has not been read
--- and whose building has not been walked into, so nothing points at an emptied house.
function Stash.restorePossible()
    if isClient() then return end

    local possible = StashSystem.getPossibleStashes()
    if not possible then return end

    local present = {}
    for i = 1, possible:size() do
        present[possible:get(i - 1):getName()] = true
    end

    local read = {}
    local alreadyRead = StashSystem.getAlreadyReadMap()
    if alreadyRead then
        for i = 1, alreadyRead:size() do
            read[alreadyRead:get(i - 1)] = true
        end
    end

    local metaGrid = getWorld():getMetaGrid()
    local restored = 0
    for stashMap in pairs(Stash.descriptions) do
        local name = stashMap.name
        if not present[name] and not read[name] then
            local room = metaGrid:getRoomAt(stashMap.buildingX, stashMap.buildingY, 0)
            local building = room and room:getBuilding()
            if building and not building:isHasBeenVisited() then
                possible:add(StashBuilding.new(name, stashMap.buildingX, stashMap.buildingY))
                restored = restored + 1
            end
        end
    end

    if restored > 0 then
        print("ISA: restored " .. restored .. " stash house(s) the save had not heard of")
    end
end

function Stash.sandbox(newGame)
    local mode = SandboxVars.ISA.StashMode
    if mode == 1 then return end

    Stash.insertItems(mode ~= 4)
    Events.OnGameStart.Add(Stash.restorePossible)

    if mode ~= 2 and newGame and not isClient() then
        ISA.queueFunction("OnTick", Stash.prepareBuildingStash)
    end
end

Events.OnInitGlobalModData.Add(Stash.sandbox)

return Stash
