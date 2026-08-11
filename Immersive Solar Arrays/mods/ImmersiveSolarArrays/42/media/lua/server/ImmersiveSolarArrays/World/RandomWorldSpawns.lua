if isClient() then return end

local ISA = require "ImmersiveSolarArrays/Utilities"
local TargetSquare_OnLoad = require "!_TargetSquare_OnLoad"
local sandbox = SandboxVars.ISA

local RandomWorldSpawns = {}
RandomWorldSpawns.spawnBatteryBankRooms = { shed = 12, garagestorage = 12, storageunit = 12, electronicsstorage = 3, farmstorage = 8 }
RandomWorldSpawns.spawnBatteryBankChance = { 999999, 10, 3, 1 }
RandomWorldSpawns.spawnCrateRooms = { garagestorage = 33, storageunit = 16 }
RandomWorldSpawns.spawnCrateChance = { 999999, 10, 3, 1 }

---@param square IsoGridSquare
---@param spriteName string
---@param index? number
function RandomWorldSpawns.addToWorld(square, spriteName, index)
    ---TODO get adjacent free square or pop error
    --if square:isFree(true) or (sprite == "solarmod_tileset_01_6" or sprite == "solarmod_tileset_01_7") and square:isFreeOrMidair(true) then

    index = index or -1
    local isoObject
    if ISA.WorldUtil.ISATypes[spriteName] == "PowerBank" then
        RandomWorldSpawns.placePowerBank(square, spriteName, index)
        return
    end
    isoObject = IsoObject.new(square:getCell(), square, spriteName)
    isoObject:createContainersFromSpriteProperties()
    RandomWorldSpawns.fillContainer(isoObject, spriteName)

    square:AddSpecialObject(isoObject,index)
    if isServer() then
        isoObject:transmitCompleteItemToClients()
    end
    triggerEvent("OnObjectAdded", isoObject)

    --else get another square
    --end
end

--- Vanilla only ever fills a container for a specific player, and every call it makes
--- passes a real one. A dedicated server has no local player, so rather than hand the
--- engine a nil the container is left for the first person to open it.
---@param container ItemContainer
local function fillFromLootTables(container)
    local player = getPlayer()
    if player then
        ItemPickerJava.fillContainer(container, player)
    end
end

---@param square IsoGridSquare
---@param spriteName string
---@param index number
---@return IsoObject
function RandomWorldSpawns.placePowerBank(square, spriteName, index)
    local sprite = getSprite(spriteName)
    local fullType = sprite:getProperties():Is("CustomItem") and sprite:getProperties():Val("CustomItem")
                     or ("Moveables." .. spriteName)

    local object = IsoGenerator.new(square:getCell())
    object:setSprite(sprite)
    object:setSquare(square)
    object:getModData().generatorFullType = fullType
    object:createContainersFromSpriteProperties()
    fillFromLootTables(object:getContainer())
    object:getContainer():setExplored(true)
    square:AddSpecialObject(object, index)
    object:transmitCompleteItemToClients()
    object:setCondition(100)
    object:setFuel(100)
    object:setConnected(true)
    object:getCell():addToProcessIsoObjectRemove(object)
    triggerEvent("OnObjectAdded", object)

    return object
end

function RandomWorldSpawns.fillContainer(isoObject, sprite)
    local container = isoObject:getContainer()
    if not container then return end
    local fillType, overlayType
    if sprite == "solarmod_tileset_01_36" then fillType = "SolarBox"; overlayType = "solarmod_tileset_01_38"
    --elseif sprite == "solarmod_tileset_01_0" then overlayType = false
    end
    if fillType == "SolarBox" then
        local panelnumber = ZombRand(3, 5) * sandbox.LRMSolarPanels
        local batterynumber = ZombRand(1, 2) * sandbox.LRMBatteries
        panelnumber = panelnumber < 8 and panelnumber or 7
        batterynumber = batterynumber < 4 and batterynumber or 3
        container:AddItems("ISA.SolarPanel",panelnumber)
        container:AddItems("Base.ElectricWire",panelnumber*3)
        container:AddItems("Base.MetalBar",panelnumber*2)
        container:AddItems("ISA.DeepCycleBattery",batterynumber)
        container:AddItem("ISA.ISAInverter")
        container:AddItem("ISA.ISAMag1")
    else
        fillFromLootTables(container)
    end
    if overlayType then
        isoObject:setOverlaySprite(overlayType)
    elseif overlayType == nil then
        ItemPickerJava.updateOverlaySprite(isoObject)
        -- getContainerOverlays():updateContainerOverlaySprite(isoObject)
    end
    container:setExplored(true)
end

---TODO balance loot
-- function RandomWorldSpawns.fillContainer(isoObject, sprite)
--     local container = isoObject:getContainer()
--     if not container then return end
--     fillFromLootTables(container)
--     ItemPickerJava.updateOverlaySprite(isoObject)
--     container:setExplored(true)

--     if getDebug() and getPlayer() then
--         getPlayer():Say(string.format("isa: filled container x:%.1f, y:%.1f",getPlayer():getX()-isoObject:getX(),getPlayer():getY()-isoObject:getY()))
--     end
-- end

function RandomWorldSpawns.doRolls(targetSquare)
    local spawnChance = sandbox.solarPanelWorldSpawns
    if spawnChance == 0 then return end
    local ZombRand, ipairs = ZombRand, ipairs
    local Locations = require("ImmersiveSolarArrays/World/RandomWorldSpawns_Locations")

    local loaded = {}
    for _,map in ipairs(getWorld():getMap():split(";")) do
        local mapLocations = Locations[map]
        if mapLocations ~= nil then
            for _,location in ipairs(mapLocations) do
                local valid = true
                for _,over in ipairs(location.overwrite) do
                    if loaded[over] then valid = false break end
                end
                if valid and ZombRand(100) < spawnChance then
                    targetSquare.addCommand(location.x,location.y,location.z,{ command = "isaWorldSpawn", sprite = location.type})
                end
            end
        end
        loaded[map] = true
    end
end

function RandomWorldSpawns.OnSeeNewRoom(room)
    local roomChance, square
    -- random powerbank
    if sandbox.BatteryBankSpawn > 1 then
        -- Spelt roomchance here until now, which assigned a global and left the local
        -- nil, so a battery bank never spawned in a room.
        roomChance = RandomWorldSpawns.spawnBatteryBankRooms[room:getName()]
        if roomChance and ZombRand(roomChance * RandomWorldSpawns.spawnBatteryBankChance[sandbox.BatteryBankSpawn]) == 0 then
            square = room:getRandomFreeSquare()
            if square then
                RandomWorldSpawns.addToWorld(square, "solarmod_tileset_01_0")
            end
        end
    end
    ---TODO add sandbox option
    --random crate
    roomChance = RandomWorldSpawns.spawnCrateRooms[room:getName()]
    if roomChance and ZombRand(roomChance * RandomWorldSpawns.spawnCrateChance[sandbox.BatteryBankSpawn]) == 0 then
        square = room:getRandomFreeSquare()
        if square then
            RandomWorldSpawns.addToWorld(square, "solarmod_tileset_01_36")
        end
    end
end

function RandomWorldSpawns.InitSpawns()
    if sandbox.BatteryBankSpawn > 1 then
        Events.OnSeeNewRoom.Add(RandomWorldSpawns.OnSeeNewRoom)
    end

    local instance = TargetSquare_OnLoad and TargetSquare_OnLoad.instance
    if not instance then return end

    instance.OnLoadCommands.isaWorldSpawn = function(square,command)
        RandomWorldSpawns.addToWorld(square,command.sprite)
    end

    if instance.savedData["ISA_RandomWorldSpawns_initialised"] then return end
    RandomWorldSpawns.doRolls(instance)
    instance.savedData["ISA_RandomWorldSpawns_initialised"] = true
end

Events.OnSGlobalObjectSystemInit.Add(RandomWorldSpawns.InitSpawns)

return RandomWorldSpawns