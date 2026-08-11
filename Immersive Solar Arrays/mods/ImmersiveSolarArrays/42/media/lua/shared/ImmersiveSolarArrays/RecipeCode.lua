--[[
    Recipe hooks and the battery bank's container filter.

    Shared rather than server. Craft recipe hooks run on whichever machine is doing the
    crafting, and the container filter is read by the inventory UI, so a multiplayer
    client needs both. The build 41 version lived under server/ and was named after
    build 41's recipecode.lua, which build 42 removed along with the global Recipe table.

    Build 42 calls OnCreate as (craftRecipeData, character) and OnTest as
    (inventoryItem, character), mirroring zombie.scripting.logic.RecipeCodeOnCreate and
    RecipeCodeOnTest. The build 41 (items, result, player) signature is gone.
--]]

---@class ISARecipes
ISARecipes = ISARecipes or {}
ISARecipes.OnCreate = ISARecipes.OnCreate or {}
ISARecipes.OnTest = ISARecipes.OnTest or {}

--- Capacity in amp hours and degrade rate for each car battery the wiring recipe accepts.
ISARecipes.carBatteries = {
    ["Base.CarBattery1"] = { ah = 50, degrade = 10 },
    ["Base.CarBattery2"] = { ah = 100, degrade = 6 },
    ["Base.CarBattery3"] = { ah = 75, degrade = 8 },
}

--- Sprites the three craftable panels place, plus the two extra facings the tileset has.
--- A panel picked up off the ground comes back as a plain Base.Moveable carrying one of
--- these, which is the only way to tell it apart from any other moveable.
ISARecipes.panelSprites = {
    solarmod_tileset_01_6 = "mounted",
    solarmod_tileset_01_7 = "mounted",
    solarmod_tileset_01_8 = "flat",
    solarmod_tileset_01_9 = "mounted",
    solarmod_tileset_01_10 = "mounted",
}

--- Which of the three panel items maps to which teardown return.
ISARecipes.panelItems = {
    ["ISA.SolarPanelFlat"] = "flat",
    ["ISA.SolarPanelWall"] = "mounted",
    ["ISA.SolarPanelMounted"] = "mounted",
}

local function roundToNumber(x, n)
    return math.ceil(x / n - 0.5) * n
end

--- Mirrors ISCraftAction:addOrDropItem, which is not reachable from a recipe hook.
local function addOrDrop(character, item)
    local inv = character:getInventory()
    if inv:getCapacityWeight() + item:getWeight() < inv:getEffectiveCapacity(character) then
        inv:AddItem(item)
    else
        local square = character:getCurrentSquare()
        if square then
            square:AddWorldInventoryItem(item, character:getX() % 1, character:getY() % 1, 0)
        else
            inv:AddItem(item)
        end
    end
end

--- First consumed input matching a predicate. Consumed covers every non-keep input, so
--- the wire and the screwdriver turn up here too and have to be filtered out.
local function findConsumed(craftRecipeData, predicate)
    local items = craftRecipeData:getAllConsumedItems()
    if not items then return nil end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and predicate(item) then
            return item
        end
    end
    return nil
end

local function isCarBattery(item)
    return ISARecipes.carBatteries[item:getFullType()] ~= nil
end

local function isWiredBattery(item)
    return item:getFullType() == "ISA.WiredCarBattery"
end

----------------------------------------------------------------------------------------
--- Container filter

AcceptItemFunction = AcceptItemFunction or {}

--- Only things the powerbank can actually charge go in the battery bank.
function AcceptItemFunction.ISA_Batteries(container, item)
    return item:getModData().ISA_maxCapacity ~= nil
end

----------------------------------------------------------------------------------------
--- OnCreate

--- Wiring a car battery records what it was so unwiring can give the same one back, and
--- rolls a capacity and a degrade rate from the electrician's skill.
function ISARecipes.OnCreate.wireCarBattery(craftRecipeData, character)
    local result = craftRecipeData:getFirstCreatedItem()
    local carBattery = findConsumed(craftRecipeData, isCarBattery)
    if not (result and carBattery) then return end

    local fullType = carBattery:getFullType()
    local batteryInfo = ISARecipes.carBatteries[fullType]
    local resultData = result:getModData()

    resultData.unwiredType = fullType
    if carBattery:hasModData() then
        resultData.unwiredData = copyTable(carBattery:getModData())
    end

    local skillMod = math.min(10, ZombRand(1 + character:getPerkLevel(Perks.Electricity)))
    local qualityMod = math.min(11, ZombRand(9, 11) + skillMod / 4) / 10

    resultData.ISA_maxCapacity = roundToNumber(batteryInfo.ah * qualityMod, 5)
    resultData.ISA_BatteryDegrade = batteryInfo.degrade / qualityMod

    result:setCurrentUsesFloat(carBattery:getCurrentUsesFloat())
    result:setCondition(carBattery:getCondition() - ZombRand(1, 12 - skillMod))
    result:syncItemFields()
end

--- The recipe has no output, because which car battery comes back depends on what was
--- wired in the first place.
function ISARecipes.OnCreate.unwireCarBattery(craftRecipeData, character)
    local wiredBattery = findConsumed(craftRecipeData, isWiredBattery)
    if not wiredBattery then return end

    local oldData = wiredBattery:getModData()
    local item = InventoryItemFactory.CreateItem(oldData.unwiredType or "Base.CarBattery1")
    if not item then return end

    if oldData.unwiredData then
        local newData = item:getModData()
        for k, v in pairs(oldData.unwiredData) do
            newData[k] = v
        end
    end

    local skillMod = math.min(10, ZombRand(1 + character:getPerkLevel(Perks.Electricity)))
    item:setCurrentUsesFloat(wiredBattery:getCurrentUsesFloat())
    item:setCondition(wiredBattery:getCondition() - ZombRand(1, 12 - skillMod))
    item:syncItemFields()

    addOrDrop(character, item)
end

--- Capacity of the DIY battery is what went into it, scaled by the sandbox multiplier.
function ISARecipes.OnCreate.createDiyBattery(craftRecipeData, character)
    local result = craftRecipeData:getFirstCreatedItem()
    if not result then return end

    local sourceItems = 0
    local sumCondition = 0
    local sumCapacity = 0

    local items = craftRecipeData:getAllConsumedItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local maxCapacity = item:getModData().ISA_maxCapacity
        if maxCapacity then
            sourceItems = sourceItems + 1
            sumCapacity = sumCapacity + maxCapacity
            sumCondition = sumCondition + item:getCondition()
        end
    end
    if sourceItems == 0 then return end

    local resultData = result:getModData()
    resultData.ISA_maxCapacity = roundToNumber(sumCapacity * SandboxVars.ISA.DIYBatteryMultiplier / 100, 5)

    result:setCurrentUsesFloat(0)
    result:setCondition(math.floor(sumCondition / sourceItems))
    result:syncItemFields()
end

--- Taking a panel apart returns the mounting hardware, but only if it had any.
function ISARecipes.OnCreate.reverseSolarPanel(craftRecipeData, character)
    local panel = findConsumed(craftRecipeData, function(item)
        return ISARecipes.panelItems[item:getFullType()] ~= nil
            or (instanceof(item, "Moveable") and ISARecipes.panelSprites[item:getWorldSprite()] ~= nil)
    end)
    if not panel then return end

    local kind = ISARecipes.panelItems[panel:getFullType()]
    if not kind and instanceof(panel, "Moveable") then
        kind = ISARecipes.panelSprites[panel:getWorldSprite()]
    end

    local inventory = character:getInventory()
    inventory:AddItems("Base.ElectricWire", 2)
    if kind ~= "flat" then
        inventory:AddItems("Base.MetalBar", 3)
        inventory:AddItems("Base.Screws", 2)
    end
end

----------------------------------------------------------------------------------------
--- OnTest
---
--- OnTest is asked about every candidate item for the recipe, tools included, so
--- anything the check does not care about has to come back true.

--- Keeps the teardown recipe from eating unrelated furniture.
function ISARecipes.OnTest.solarPanelMoveable(item, character)
    if not instanceof(item, "Moveable") then return true end
    if ISARecipes.panelItems[item:getFullType()] then return true end
    return ISARecipes.panelSprites[item:getWorldSprite()] ~= nil
end

--- Build 41 hid these two behind recipe:setIsHidden, which build 42 has no equivalent
--- for. Failing the test leaves them visible but unperformable while the option is off.
function ISARecipes.OnTest.expandedRecipes(item, character)
    return SandboxVars.ISA.enableExpandedRecipes == true
end

return ISARecipes
