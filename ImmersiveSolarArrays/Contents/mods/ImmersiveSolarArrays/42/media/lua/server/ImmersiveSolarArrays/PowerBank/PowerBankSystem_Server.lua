--[[
    "isa_powerbank" server system
--]]

if isClient() then return end

require "Map/SGlobalObjectSystem"
local ISA = require "ImmersiveSolarArrays/Utilities"
local Powerbank = require "ImmersiveSolarArrays/PowerBank/PowerBankObject_Server"

---@class PowerbankSystem_Server : PowerbankSystem, SGlobalObjectSystem
---@field instance PowerbankSystem_Server
local PBSystem = require("ImmersiveSolarArrays/PowerBankSystem_Shared"):new(SGlobalObjectSystem:derive("ISA_PowerBankSystem_Server"))

--called when making the instance, triggered by: Events.OnSGlobalObjectSystemInit
function PBSystem:new()
    return SGlobalObjectSystem.new(self, "isa_powerbank")
end

--called in SGlobalObjectSystem:new(name)
PBSystem.savedObjectModData = { 'on', 'batteries', 'charge', 'maxcapacity', 'drain', 'npanels', 'panels', "lastHour", "conGenerator"}
function PBSystem:initSystem()
    -- set the instance for easy access
    ISA.PBSystem_Server = self

    --SGlobalObjectSystem.initSystem(self) --does nothing
    --set saved fields
    self.system:setObjectModDataKeys(self.savedObjectModData)

    --sandbox options, *Events.Event.Add() doesn't need to be specifically inside a function call
    self.updateEveryTenMinutes = SandboxVars.ISA.ChargeFreq == 1 and true
    if self.updateEveryTenMinutes then
        Events.EveryTenMinutes.Add(PBSystem.updatePowerbanks)
    else
        Events.EveryHours.Add(PBSystem.updatePowerbanks)
    end
    Events.EveryDays.Add(PBSystem.EveryDays)
end

---Create / Load a lua object from java object
function PBSystem:newLuaObject(globalObject)
    return Powerbank:new(self, globalObject)
end

---triggered by: Events.OnObjectAdded (SGlobalObjectSystem)
---@param isoObject IsoObject
function PBSystem:OnObjectAdded(isoObject)
    local isaType = ISA.WorldUtil.getType(isoObject)
    if not isaType then
        return
    elseif isaType == "PowerBank" then
        if not instanceof(isoObject, "IsoGenerator") then
            isoObject = ISA.WorldUtil.replaceIsoObjectWithGenerator(isoObject)
        end
        if self:isValidIsoObject(isoObject) then
            self:loadIsoObject(isoObject)
        end
    elseif isaType == "Panel" then
        local modData = isoObject:getModData()
        modData.pbLinked = nil
        modData.connectDelta = nil
        isoObject:transmitModData()
    elseif isaType == "Failsafe" then
        -- It shares a tile with the generator it triggers, so without this the generator
        -- draws over it.
        ISA.WorldUtil.raiseToTopOfSquare(isoObject)
    end
end

---triggered by: Events.OnObjectAboutToBeRemoved, Events.OnDestroyIsoThumpable  (SGlobalObjectSystem)
---v41.78 object data has already been copied to InventoryItem on pickup
function PBSystem:OnObjectAboutToBeRemoved(isoObject)
    local isaType = ISA.WorldUtil.getType(isoObject)
    if not isaType then
        return
    elseif self:isValidIsoObject(isoObject) then
        local luaObject = self:getLuaObjectOnSquare(isoObject:getSquare())
        if not luaObject then return end
        self:removeLuaObject(luaObject)
    elseif isaType == "Panel" then
        self:removePanel(isoObject)
    end
end

function PBSystem:OnClientCommand(command, playerObj, args)
    local fn = self.Commands[command]
    if fn ~= nil then
        fn(playerObj, args)
    end
end

---called when object is about to be removed
function PBSystem:removePanel(panel)
    local pbData = panel:getModData().pbLinked
    if pbData == nil then return end
    local pb = self:getLuaObjectAt(pbData.x, pbData.y, pbData.z)
    panel:getModData().pbLinked = nil
    panel:transmitModData()
    if pb == nil then return end
    local x = panel:getX()
    local y = panel:getY()
    local z = panel:getZ()
    for i = #pb.panels, 1, -1 do
        local _panel = pb.panels[i]
        if _panel.x == x and _panel.y == y and _panel.z == z then
            table.remove(pb.panels, i)
            pb.npanels = pb.npanels - 1
            break
        end
    end
    pb:saveData(true)
end


function PBSystem.EveryDays()
    local self = PBSystem.instance
    for i = 0, self.system:getObjectCount() - 1 do
        ---@type PowerBankObject_Server
        local pb = self.system:getObjectByIndex(i):getModData()
        local isopb = pb:getIsoObject()
        if isopb then
            local inv = isopb:getContainer()
            pb:degradeBatteries(inv) ---TODO x days passed
            pb:calculateBatteryStats(inv)
            -- isopb:sendObjectChange("containers")
        end
        pb:checkPanels()
    end
end

function PBSystem.updatePowerbanks()
    local self = PBSystem.instance
    local solaroutput = self:getModifiedSolarOutput(1)
    for i = 0, self.system:getObjectCount() - 1 do
        ---@type PowerBankObject_Server
        local pb = self.system:getObjectByIndex(i):getModData()
        local isopb = pb:getIsoObject()

        -- Count what is actually in the bank rather than trusting the running total.
        --
        -- That total is kept up to date by the moveBattery command, which the client
        -- sends from its hook on the vanilla transfer action. In multiplayer that hook
        -- never runs: ISInventoryTransferAction only calls transferItem when isClient is
        -- false, so the client skips it and the server moves the item through the item
        -- transaction system instead, where no Lua of ours sits.
        --
        -- A bank on a server therefore reported no batteries however many were in it, and
        -- it did more than misreport. maxcapacity stayed at zero, so modCharge below came
        -- out zero, and updateBatteries wrote that straight back into every battery on the
        -- next pass. The bank drained the things it was supposed to be charging.
        --
        -- The container is the truth and it is a handful of items, so read it.
        local container = isopb and isopb:getContainer()
        if container then
            pb:calculateBatteryStats(container)
        end

        local drain = 0
        if pb:shouldDrain(isopb) then
            pb:updateDrain()
            drain = pb.drain
        end

        local dCharge = solaroutput * pb.npanels - drain
        if self.updateEveryTenMinutes then dCharge = dCharge / 6 end
        local charge = pb.charge + dCharge
        if charge < 0 then charge = 0 elseif charge > pb.maxcapacity then charge = pb.maxcapacity end
        local modCharge = pb.maxcapacity > 0 and charge / pb.maxcapacity or 0
        pb.charge = charge
        if isopb then
            pb:updateBatteries(isopb:getContainer(), modCharge)
            pb:updateGenerator(dCharge)
            pb:updateSprite(modCharge)
        end
        pb:updateConGenerator()
        pb:saveData(true)

        if PBSystem.wantChargeNoise then
            self:noise(string.format("/charge: (%d) Battery at: %d %%, charge dif: %.1f, output: %.1f, drain: %.1f",i,modCharge*100,dCharge,pb.npanels*solaroutput,drain))
        end
    end
end

SGlobalObjectSystem.RegisterSystemClass(PBSystem)

return PBSystem
