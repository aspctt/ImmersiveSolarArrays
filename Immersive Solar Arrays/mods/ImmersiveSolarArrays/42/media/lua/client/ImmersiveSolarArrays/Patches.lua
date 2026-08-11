--[[
    Wraps the three vanilla actions the powerbank needs to hear about: plugging a
    generator in, switching one on, and moving a battery in or out of the bank.

    Client rather than shared. All three are client side actions, and the file requires
    the mod's UI, so a dedicated server used to fail loading it outright.

    Everything goes through the powerbank system's commands. The build 41 code reached
    straight into the server system instead, which works in singleplayer, where both
    halves share a Lua state, and does nothing at all on a multiplayer client, where
    there is no server system to reach. CGlobalObjectSystem:sendCommand is routed to the
    server in both cases, so one path covers both.
--]]

---@class ImmersiveSolarArrays
local ISA = require "ImmersiveSolarArrays/Utilities"
require "ImmersiveSolarArrays/UI/ISAUI"
local PBSystem = require "ImmersiveSolarArrays/PowerBank/PowerBankSystem_Client"

ISA.Patches = {}

local function sendCommand(character, command, args)
    local instance = PBSystem.instance
    if not instance or not character then return end
    instance:sendCommand(character, command, args)
end

--- Coordinates of a world object, for sending to the server.
---@param isoObject IsoObject
local function isoXYZ(isoObject)
    return { x = isoObject:getX(), y = isoObject:getY(), z = isoObject:getZ() }
end

--- Coordinates of a powerbank's Lua object.
---
--- Deliberately separate from isoXYZ. A CGlobalObject carries x, y and z as plain
--- fields and has no accessors at all, so calling getX on one throws, and the two are
--- easy to confuse because in this file both are "the powerbank".
---@param luaObject PowerBankObject_Client
local function luaXYZ(luaObject)
    return { x = luaObject.x, y = luaObject.y, z = luaObject.z }
end

---@param character IsoPlayer
---@param generator IsoGenerator
---@param plug boolean
local function onPlugGenerator(character, generator, plug)
    local square = generator:getSquare()
    local instance = PBSystem.instance
    if not (square and instance) then return end

    local pbList = {}
    if plug then
        -- Only banks the character's electrical skill can reach.
        local area = ISA.WorldUtil.getValidBackupArea(character:getPerkLevel(Perks.Electricity))
        local luaPowerbanks = ISA.WorldUtil.getPowerBanksInArea(square, area.radius, area.levels, area.distance)
        for i = 1, #luaPowerbanks do
            table.insert(pbList, luaXYZ(luaPowerbanks[i]))
        end
    else
        -- Unplugging has no range check: every bank pointing at this generator drops it.
        local x, y, z = generator:getX(), generator:getY(), generator:getZ()
        for i = 1, instance:getLuaObjectCount() do
            local pb = instance:getLuaObjectByIndex(i)
            local con = pb.conGenerator
            if con and con.x == x and con.y == y and con.z == z then
                table.insert(pbList, luaXYZ(pb))
            end
        end
    end

    if pbList[1] == nil then return end
    sendCommand(character, "plugGenerator", { pbList = pbList, gen = isoXYZ(generator), plug = plug })
end

---@param character IsoPlayer
---@param generator IsoGenerator
---@param activate boolean
local function onActivateGenerator(character, generator, activate)
    local instance = PBSystem.instance
    if not instance then return end

    local x, y, z = generator:getX(), generator:getY(), generator:getZ()
    for i = 1, instance:getLuaObjectCount() do
        local pb = instance:getLuaObjectByIndex(i)
        local con = pb.conGenerator
        if con and con.x == x and con.y == y and con.z == z then
            sendCommand(character, "activateGenerator", { pb = luaXYZ(pb), activate = activate })
        end
    end
end

---@param character IsoPlayer
---@param item InventoryItem
local function onTransferItem(character, item, srcContainer, destContainer)
    local maxCapacity = item:getModData().ISA_maxCapacity
    if not maxCapacity then return end

    local src = srcContainer and srcContainer:getParent()
    local dst = destContainer and destContainer:getParent()
    local take = src ~= nil and ISA.WorldUtil.objectIsType(src, "PowerBank")
    local put = dst ~= nil and ISA.WorldUtil.objectIsType(dst, "PowerBank")
    if not (take or put) then return end

    -- Capacity falls away sharply as condition drops, matching the server's formula.
    local capacity = maxCapacity * (1 - math.pow((1 - (item:getCondition() / 100)), 6))
    local charge = capacity * item:getCurrentUsesFloat()

    if take then
        sendCommand(character, "moveBattery", { isoXYZ(src), "take", charge, capacity })
    end
    if put then
        sendCommand(character, "moveBattery", { isoXYZ(dst), "put", charge, capacity })
    end
end

ISA.Patches["ISPlugGenerator.complete"] = function()
    local original = ISPlugGenerator.complete
    ISPlugGenerator.complete = function(self)
        local result = original(self)
        onPlugGenerator(self.character, self.generator, self.plug and true or false)
        return result
    end
end

ISA.Patches["ISActivateGenerator.complete"] = function()
    local original = ISActivateGenerator.complete
    ISActivateGenerator.complete = function(self)
        local result = original(self)

        -- Only report it if the generator actually ended up in the requested state.
        if result and self.activate == self.generator:isActivated() then
            onActivateGenerator(self.character, self.generator, self.activate)
        end

        return result
    end
end

ISA.Patches["ISTransferAction.transferItem"] = function()
    local original = ISTransferAction.transferItem
    ISTransferAction.transferItem = function(self, character, item, srcContainer, destContainer, dropSquare)
        local result = original(self, character, item, srcContainer, destContainer, dropSquare)

        if result ~= nil then
            onTransferItem(character, item, srcContainer, destContainer)
        end

        return result
    end
end

-- Applied a tick in, so that any mod replacing the same actions has already done so.
ISA.queueFunction("OnTick", function()
    for _, patch in pairs(ISA.Patches) do
        patch()
    end
    ISA.Patches = nil
end)
