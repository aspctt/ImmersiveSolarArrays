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

--- Tell the bank a battery went in or came out, so its totals move straight away.
---
--- Singleplayer only in practice, and deliberately not relied on. ISInventoryTransferAction
--- guards its call with `if not isClient()`, so on a multiplayer client this never runs:
--- the item travels through the item transaction system and the server applies it with no
--- Lua of ours in the way. The bank recounts its own container on every pass and when the
--- status window opens, which is what actually keeps multiplayer honest. This is only here
--- to make the number move the instant the player drops a battery in.
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

-- perform, not complete. The engine skips the Lua complete on a multiplayer client,
-- where the server runs its own copy of the action and calls complete there instead.
-- Hooking complete meant a client plugging a generator in never told the powerbank.
--
-- perform runs just before complete would, so vanilla has not applied the change yet
-- when these fire. What gets reported is therefore the action's intent rather than the
-- generator's current state, which is the only thing a client can know at this point
-- anyway. The server reconciles the real state on its next hourly pass.

--- Run our half of a wrapped action without letting it take the vanilla half down.
---
--- These wrappers sit in front of actions this mod does not own. Anything thrown in here
--- propagates out of perform, so vanilla never applies the change, and the only thing the
--- player sees is the progress bar filling and the generator not turning on, not plugging
--- in, not unplugging. Nothing in the log points at the generator either, because the
--- error is in the powerbank bookkeeping.
---
--- The bank being out of step is recoverable, it is reconciled on the next hourly pass.
--- A generator that cannot be switched on is not. So the vanilla action always runs.
local function safely(what, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        print("ISA: " .. what .. " failed, the generator itself was not affected: " .. tostring(err))
    end
end

ISA.Patches["ISPlugGenerator.perform"] = function()
    local original = ISPlugGenerator.perform
    ISPlugGenerator.perform = function(self)
        safely("plugGenerator", onPlugGenerator, self.character, self.generator, self.plug and true or false)
        return original(self)
    end
end

ISA.Patches["ISActivateGenerator.perform"] = function()
    local original = ISActivateGenerator.perform
    ISActivateGenerator.perform = function(self)
        safely("activateGenerator", onActivateGenerator, self.character, self.generator, self.activate)
        return original(self)
    end
end

ISA.Patches["ISTransferAction.transferItem"] = function()
    local original = ISTransferAction.transferItem
    ISTransferAction.transferItem = function(self, character, item, srcContainer, destContainer, dropSquare)
        local result = original(self, character, item, srcContainer, destContainer, dropSquare)

        if result ~= nil then
            safely("moveBattery", onTransferItem, character, item, srcContainer, destContainer)
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
