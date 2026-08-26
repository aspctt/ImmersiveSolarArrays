---@class ImmersiveSolarArrays
local ISA = require "ImmersiveSolarArrays/Utilities"

local WorldUtil = {}

---@alias ISAType
---| `PowerBank`
---| `Panel`
---| `FailSafe`

WorldUtil.ISATypes = {
    solarmod_tileset_01_0 = "PowerBank",
    solarmod_tileset_01_6 = "Panel",
    solarmod_tileset_01_7 = "Panel",
    solarmod_tileset_01_8 = "Panel",
    solarmod_tileset_01_9 = "Panel",
    solarmod_tileset_01_10 = "Panel",
    solarmod_tileset_01_15 = "Failsafe",
}

---return type of solar object
---@param isoObject IsoObject
---@return ISAType
function WorldUtil.getType(isoObject)
    return WorldUtil.ISATypes[isoObject:getTextureName()]
end

---@param isoObject IsoObject
---@param modType ISAType
---@return boolean
function WorldUtil.objectIsType(isoObject, modType)
    return WorldUtil.ISATypes[isoObject:getTextureName()] == modType
end

---@param level number Electical skill level
---@return table
function WorldUtil.getValidBackupArea(level)
    return { radius = level, levels = level > 5 and 1 or 0, distance = math.pow(level, 2) * 1.25 }
end

---@param square IsoGridSquare
---@param radius number
---@param zLevels number
---@param distance number
---@return table<any,PowerBankObject_Server>
function WorldUtil.getPowerBanksInArea(square, radius, zLevels, distance)
    local all = {}
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()
    for ix = x - radius, x + radius do
        for iy = y - radius, y + radius do
            for iz = z - zLevels, z + zLevels do
                local isquare = IsoUtils.DistanceToSquared(x,y,z,ix,iy,iz) <= distance and getSquare(ix, iy, iz)
                local pb
                if isquare then
                    if isClient() then
                        pb = ISA.PBSystem_Client:getLuaObjectOnSquare(isquare)
                    else
                        pb = ISA.PBSystem_Server:getLuaObjectOnSquare(isquare)
                    end
                end
                if pb ~= nil then
                    table.insert(all,pb)
                end
            end
        end
    end
    return all
end

--- Move an object to the end of its square's list, so it draws over whatever shares the
--- tile with it.
---
--- The failsafe is placed with MoveType = FloorRug, which is what lets it go down on a
--- square that already holds a generator: the placement code waives the "something solid
--- is here" rule for rugs. The same flag inserts it just above the floor, so a generator
--- on the same tile draws straight over the top of it.
---
--- Dropping the rug type would fix the drawing and break the placing, so the object goes
--- down as a rug and is lifted afterwards. Neither call raises a Lua event, so this does
--- not re-enter whatever is calling it.
---
--- Ordering only, no transmit. Each machine sorts its own copy out when the object is
--- added or the chunk loads, rather than trying to resend an object the other end
--- already has.
---@param isoObject IsoObject
function WorldUtil.raiseToTopOfSquare(isoObject)
    local square = isoObject and isoObject:getSquare()
    if not square then return end

    local objects = square:getObjects()
    if not objects or objects:size() < 2 then return end
    if isoObject:getObjectIndex() == objects:size() - 1 then return end

    square:RemoveTileObject(isoObject)
    square:AddSpecialObject(isoObject, square:getObjects():size())
end

function WorldUtil.findOnSquare(square,sprite)
    local special = square:getSpecialObjects()
    for i = 0, special:size()-1 do
        local obj = special:get(i)
        if obj:getTextureName() == sprite then
            return obj
        end
    end
end

---@param square IsoGridSquare
---@param type string
---@return IsoObject?
function WorldUtil.findTypeOnSquare(square, type)
    local special = square:getSpecialObjects()
    for i = 0, special:size() - 1 do
        local obj = special:get(i)
        if WorldUtil.ISATypes[obj:getTextureName()] == type then
            return obj
        end
    end
    return nil
end

---@param isoObject IsoObject
---@return IsoGenerator
function WorldUtil.replaceIsoObjectWithGenerator(isoObject)
    local square = isoObject:getSquare()
    local index = isoObject:getObjectIndex()
    ---TODO check earlier
    if not square or index == -1 then return IsoGenerator.new(getCell()) end
    -- PropertyContainer lost Is and Val in build 42; they are has and get now.
    local props = isoObject:getSprite():getProperties()
    local fullType = props:has("CustomItem") and props:get("CustomItem")
                     or ("Moveables." .. isoObject:getTextureName())
    square:transmitRemoveItemFromSquare(isoObject)
    -- local generator = IsoGenerator.new(instanceItem("ISA.PowerBank"), square:getCell(), square)
    local generator = IsoGenerator.new(square:getCell())
    generator:setSprite(isoObject:getSprite())
    generator:setSquare(square)
    
    --set sprite, condition, fuel, fulltype from item
    generator:getModData().generatorFullType = fullType

    square:AddSpecialObject(generator, index)
    generator:createContainersFromSpriteProperties()
    -- The tiledef gives a bank its container, and createContainersFromSpriteProperties
    -- says nothing when it cannot: no sprite resolved, no container property found, and
    -- it simply returns. Reaching straight through that used to throw here and abandon
    -- the rest of this function, which left a generator standing on the square with no
    -- container, no condition, no fuel and no OnObjectAdded, so the mod never saw it.
    -- That is the battery bank you cannot open and cannot connect a panel to. Finishing
    -- the job leaves a bank the chunk load can repair instead of one only a pick up and
    -- replace could.
    local container = generator:getContainer()
    if container then
        container:setExplored(true)
    end
    generator:transmitCompleteItemToClients()
    ---these auto transmit, do after sending object
    generator:setCondition(100)
    generator:setFuel(100)
    generator:setConnected(true)
    generator:getCell():addToProcessIsoObjectRemove(generator)
    triggerEvent("OnObjectAdded", generator)

    return generator
end

ISA.WorldUtil = WorldUtil
