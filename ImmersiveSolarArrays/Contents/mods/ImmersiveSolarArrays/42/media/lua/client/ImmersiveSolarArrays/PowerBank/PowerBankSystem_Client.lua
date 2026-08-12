require "Map/CGlobalObjectSystem"
---@class ImmersiveSolarArrays
local ISA = require "ImmersiveSolarArrays/Utilities"
local PowerBank = require "ImmersiveSolarArrays/PowerBank/PowerBankObject_Client"

---@class PowerbankSystem_Client : PowerbankSystem, CGlobalObjectSystem
local PBSystem = require("ImmersiveSolarArrays/PowerBankSystem_Shared"):new(CGlobalObjectSystem:derive("ISA_PowerBankSystem_Client"))

function PBSystem:new()
    return CGlobalObjectSystem.new(self, "isa_powerbank")
end

function PBSystem:initSystem()
    ISA.PBSystem_Client = self
    if isClient() then
        --if SandboxVars.ISA.ChargeFreq == 1 then
           Events.EveryTenMinutes.Add(PBSystem.updateBanksForClient)
        --else
        --    Events.EveryHours.Add(PbSystem.updateBanksForClient)
        --end
    end
    --added after server function with sendObjectChange("containers") so SP need only one tick
    Events.EveryDays.Add(PBSystem.resetAcceptItemFunction.addItems)
end

function PBSystem:newLuaObject(globalObject)
    return PowerBank:new(self, globalObject)
end

--called by java receiveNewLuaObjectAt
function PBSystem:newLuaObjectAt(x, y, z)
    self:noise("adding luaObject "..x..','..y..','..z)
    local globalObject = self.system:newObject(x, y, z)
    self.processNewLua:addItem(x,y,z)
    return self:newLuaObject(globalObject)
end

do
    local o = ISA.delayedProcess:new{maxTimes=999}

    function o.process()
        if not o.data then return o:stop() end
        for i = #o.data, 1 , -1 do
            local gen = o.data[i]:getGenerator()
            if gen then
                local isoPb = PBSystem.instance:getIsoObjectOnSquare(o.data[i])
                if isoPb then
                    isoPb:getContainer():setAcceptItemFunction("AcceptItemFunction.ISA_Batteries")
                    gen:getCell():addToProcessIsoObjectRemove(gen)
                end
                table.remove(o.data,i)
            end
        end
        if #o.data == 0 or o.times <= 1 then o:stop() return end
        o.times = o.times - 1
    end

    function o:addItem(x,y,z)
        local square = getSquare(x,y,z)
        if not square then return end
        if not self.data then
            self.data = {}
            self:start()
        end
        self.times = self.maxTimes
        table.insert(self.data, square)
    end

    PBSystem.processNewLua = o
end

do
    local o = ISA.delayedProcess:new{maxTimes=999}

    function o.process()
        if not o.data then return o:stop() end

        for i = #o.data, 1, -1 do
            local obj = o.data[i]
            if obj:getObjectIndex() == -1 then
                -- Gone from the world.
                table.remove(o.data, i)
            else
                local container = obj:getContainer()
                if not container then
                    -- Not carrying its container yet. This is the one case worth
                    -- waiting on, so it stays in the list for a later tick.
                elseif container:getAcceptItemFunction() ~= nil then
                    -- Already right, so there is nothing to wait for. Dropping these
                    -- was the missing part: a bank whose filter was fine stayed in the
                    -- list and kept the sweep running for its whole retry window every
                    -- day, rechecking banks that were never going to change.
                    table.remove(o.data, i)
                else
                    PBSystem.instance:noise("Container reset")
                    container:setAcceptItemFunction("AcceptItemFunction.ISA_Batteries")
                    triggerEvent("OnContainerUpdate", obj)
                    table.remove(o.data, i)

                    -- The transfer action caches the container's filter, so anyone
                    -- standing at this bank needs their queue cleared to pick up the
                    -- change.
                    local players = IsoPlayer.getPlayers()
                    for p = 0, players:size() - 1 do
                        local player = players:get(p)
                        if player ~= nil and player:getZ() == obj:getZ()
                           and IsoUtils.DistanceToSquared(player:getX(), player:getY(), obj:getX() + 0.5, obj:getY() + 0.5) <= 4 then
                            ISTimedActionQueue.clear(player)
                        end
                    end
                end
            end
        end

        if #o.data == 0 or o.times <= 1 then return o:stop() end
        o.times = o.times - 1
    end

    function o.addItems()
        o.data = {}
        for i=1,PBSystem.instance:getLuaObjectCount() do
            local isoObject = PBSystem.instance:getLuaObjectByIndex(i):getIsoObject()
            if isoObject then
                table.insert(o.data,isoObject)
            end
        end
        if #o.data > 0 then
            o.times = o.maxTimes
            o:start()
        else
            o.data = nil
        end
    end
    PBSystem.resetAcceptItemFunction = o
end

function PBSystem.canConnectPanelTo(panel)
    local options = {}

    if not panel:getSquare():isOutside() then
        options.inside = true
        return options
    end

    local x = panel:getX()
    local y = panel:getY()
    local z = panel:getZ()
    local DistanceToSquared, abs = IsoUtils.DistanceToSquared, math.abs
    local jSystem = PBSystem.instance.system

    for i = 0, jSystem:getObjectCount() -1  do
        local pb = jSystem:getObjectByIndex(i):getModData()

        if DistanceToSquared(x, y, pb.x, pb.y) <= 400.0 and abs(z - pb.z) <= 3 then
            pb:updateFromIsoObject()
            local isConnected
            for _, ipanel in ipairs(pb.panels) do
                if x == ipanel.x and y == ipanel.y and z == ipanel.z then
                    isConnected = true
                    break
                end
            end
            table.insert(options, {pb, pb.x-x,pb.y-y, isConnected})
        end
    end

    return options
end

--draw debug num of valid generators
function PBSystem.getGeneratorsInAreaInfo(luaPb, area)
    local getSquare = getSquare
    local DistanceToSquared = IsoUtils.DistanceToSquared

    local generators = 0
    for ix = luaPb.x - area.radius, luaPb.x + area.radius do
        for iy = luaPb.y - area.radius, luaPb.y + area.radius do
            for iz = luaPb.z - area.levels, luaPb.z + area.levels do
                local isquare = getSquare(ix, iy, iz)
                local generator = isquare and luaPb.luaSystem:getValidBackupOnSquare(isquare)
                if generator and DistanceToSquared(luaPb.x,luaPb.y,luaPb.z,ix,iy,iz) <= area.distance then
                    generators = generators + 1
                end
            end
        end
    end
    return generators
end

---FIXME this might run before new data is received, use command instead
function PBSystem.updateBanksForClient()
    for i=1,PBSystem.instance:getLuaObjectCount() do
        local pb = PBSystem.instance:getLuaObjectByIndex(i)
        local isopb = pb:getIsoObject()
        if isopb then
            pb:fromModData(isopb:getModData())
            local delta = pb.maxcapacity > 0 and pb.charge / pb.maxcapacity or 0
            local items = isopb:getContainer():getItems()
            for v=0,items:size()-1 do
                local item = items:get(v)
                --FIXME all items should be valid batteries and drainable here already
                if item:getModData().ISA_maxCapacity then
                    item:setCurrentUsesFloat(delta)
                end
            end
        end
    end
end

CGlobalObjectSystem.RegisterSystemClass(PBSystem)

return PBSystem
