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
    containers = {
        { containerType = "SolarBox", containerSprite = "solarmod_tileset_01_36", contX = 10655, contY = 9720, contZ = 0 }
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
    containers = {
        { containerType = "SolarBox", containerSprite = "solarmod_tileset_01_36", contX = 11577, contY = 6768, contZ = 1 }
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

function Stash.sandbox(newGame)
    local mode = SandboxVars.ISA.StashMode
    if mode == 1 then return end

    Stash.insertItems(mode ~= 4)

    if mode ~= 2 and newGame and not isClient() then
        ISA.queueFunction("OnTick", Stash.prepareBuildingStash)
    end
end

Events.OnInitGlobalModData.Add(Stash.sandbox)

return Stash
