--[[
    "isa_powerbank" server luaObject
--]]

if isClient() then return end

require "Map/SGlobalObject"
local ISA = require "ImmersiveSolarArrays/Utilities"
local solarscan = require "ImmersiveSolarArrays/PowerBank/SolarScan"
local sandbox = SandboxVars.ISA

---@class PowerBankObject_Server : SGlobalObject
---@field luaSystem PowerbankSystem_Server
local PowerBank = SGlobalObject:derive("ISA_PowerBank_Server")

function PowerBank:new(luaSystem, globalObject)
    return SGlobalObject.new(self, luaSystem, globalObject)
end

function PowerBank:initNew()
    self.on = false
    self.batteries = 0
    self.charge = 0
    self.maxcapacity = 0
    self.panels = {}
    self.npanels = 0
    self.drain = 0
    self.lastHour = 0
    self.conGenerator = false ---FIXME should be nil, nil didn't save / transmit data?
end

---called from loadIsoObject function when making new globalObject & luaObject. This is called for IsoObjects that did not have a Lua object when loaded.
---triggered by: Events.OnObjectAdded, MapObjects.OnLoadWithSprite
function PowerBank:stateFromIsoObject(isoObject)
    self:initNew()
    self:calculateBatteryStats(isoObject:getContainer())
    self:autoConnectBackup()
    self:loadGenerator()
    self:updateDrain()
    self:updateSprite()
    self:saveData(true)
end

---called from loadIsoObject function when luaObject exists, triggered by: Events.OnObjectAdded, MapObjects.OnLoadWithSprite
function PowerBank:stateToIsoObject(isoObject)
    self:toModData(isoObject:getModData())
    isoObject:transmitModData()
    self:loadGenerator()
    self:updateSprite()
end

function PowerBank:fromModData(modData)
    for i, key in ipairs(self.luaSystem.savedObjectModData) do
        self[key] = modData[key]
    end
end

function PowerBank:toModData(modData)
    for i, key in ipairs(self.luaSystem.savedObjectModData) do
        modData[key] = self[key]
    end
end

function PowerBank:saveData(transmit)
    local isoObject = self:getIsoObject()
    if not isoObject then return end
    self:toModData(isoObject:getModData())
    if transmit then
        isoObject:transmitModData()
    end
end

function PowerBank:shouldDrain(isoPb)
    if self.switchchanged then
        self.switchchanged = nil
    elseif not self.on then
        return false
    end
    if self.conGenerator and self.conGenerator.ison then return false end

    local world = getWorld()
    if world:isHydroPowerOn() then
        if isoPb then
            if not isoPb:getSquare():isOutside() then return false end
        else
            if world:getMetaGrid():getRoomAt(self.x, self.y, self.z) then return false end
        end
    end
    return true
end

PowerBank.fuelToSolarRate = 800
function PowerBank:getDrainVanilla(square)
    local gen = square:getGenerator()
    if not gen then return 0 end
    if gen:isActivated() then
        gen:setSurroundingElectricity()
        return gen:getTotalPowerUsing() * self.fuelToSolarRate
    else
        return PowerBank.getTotalWhenoff(gen) * self.fuelToSolarRate
    end
end

function PowerBank.getTotalWhenoff(generator)
    generator:setActivated(true)
    local tpu = generator:getTotalPowerUsing()
    generator:setActivated(false)
    if generator:getSquare():getBuilding() ~= nil then generator:getSquare():getBuilding():setToxic(false) end
    return tpu
end

function PowerBank:updateDrain()
    local square = self:getSquare()
    if not square then return end
    if sandbox.DrainCalc == 1 then
        self.drain = solarscan(square, false, true, false, 0)
    else
        self.drain = self:getDrainVanilla(square)
    end
end

--- Write the bank's charge level into every battery it holds.
---
--- Anything that is not a battery is left exactly where it is. This used to pull the item
--- out and drop it on the floor whenever isItemAllowed said no, and that answer is not
--- only about the item: ItemContainer.isItemAllowed calls the container's filter through
--- protectedCallBoolean and treats anything other than a returned true, a throw included,
--- as a refusal. One bad call therefore emptied a bank onto the ground, and on a server
--- the usual sweep then clears the dropped items away and the batteries are gone.
---
--- Reading the item's own capacity is the same test calculateBatteryStats already makes,
--- it cannot fail on someone else's function, and the worst it can do is ignore something
--- rather than destroy it. Nothing that is not a battery can get in here anyway: the
--- container carries its own accept filter.
---@param container ItemContainer
---@param modCharge number
function PowerBank:updateBatteries(container, modCharge)
    local items = container:getItems()
    for i = items:size() - 1, 0, -1  do
        local item = items:get(i)
        if item:getModData().ISA_maxCapacity ~= nil then
            item:setCurrentUsesFloat(modCharge)
        end
    end
    -- container:setDirty(true)
    container:setDrawDirty(true)
end

-- SPowerbank.batteryDegrade = {
--     ["WiredCarBattery"] = 7, --ModData
--     ["DIYBattery"] = 0.125,
--     ["DeepCycleBattery"] = 0.033,
--     ["SuperBattery"] = 0.033,
-- }

--condition is an int
function PowerBank:degradeBatteries(container)
    if sandbox.batteryDegradeChance == 0 then return end
    if not container then return end

    local ZombRand, math = ZombRand, math
    local mod = sandbox.batteryDegradeChance * ZombRand(8, 13) / 1000

    local items = container:getItems()
    for i = items:size() - 1, 0, -1 do repeat
        local item = items:get(i)
        local degradeVal = item:getModData()["ISA_BatteryDegrade"] or 0 --or self.batteryDegrade[item:getType()]
        if degradeVal <= 0 then break end
        -- average of 1M rolls / 10: 5.5 / 3: 2 / 1.6: 1.37364 / 0.9: 0.90082 / 0.033: 0.03280
        degradeVal = degradeVal * mod
        degradeVal = degradeVal > 1 and 1 + math.floor(ZombRand(degradeVal * 100) / 100) or math.floor(ZombRand(100 / degradeVal) / 100 ) == 0 and 1 or 0
        if degradeVal <= 0 then break end
        item:setCondition(item:getCondition() - degradeVal)
    until true
    end
end

--- Recount what the bank is holding.
---
--- Nothing is written when there is no container to read. A bank whose container has
--- gone, or has not been built yet, is not a bank holding nothing: answering zero would
--- put maxcapacity at zero, and the charge loop writes that straight back into every
--- battery on its next pass. The last known figures are wrong for a moment; a zero is
--- wrong and acted upon.
---
--- Guarded here rather than at the four callers, because it is the same answer at all
--- of them and one of the four had it already.
---@param container ItemContainer?
function PowerBank:calculateBatteryStats(container)
    if not container then return end

    local batteries = 0
    local capacity = 0
    local charge = 0

    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local maxCapacity = item:getModData().ISA_maxCapacity
        if maxCapacity then
            local condition = item:getCondition()
            if condition > 0 then
                batteries = batteries + 1
                local cap = maxCapacity * (1 - math.pow((1 - (condition/100)),6))
                capacity = capacity + cap
                charge = charge + cap * item:getCurrentUsesFloat()
            end
        else
            print("ISA: Warning invalid item in Battery Bank. -> ", item:getFullType())
        end
    end

    self.batteries = batteries
    self.maxcapacity = capacity
    self.charge = charge
end

function PowerBank:getPanelStatus(panel)
    local x,y,z = panel:getX(), panel:getY(), panel:getZ()
    if IsoUtils.DistanceToSquared(x, y, self.x, self.y) <= 400.0 and math.abs(z - self.z) <= 3 then
        for _, panelXYZ in ipairs(self.panels) do
            if x == panelXYZ.x and y == panelXYZ.y and z == panelXYZ.z then return "connected" end
        end
        return "not connected"
    else
        return "far"
    end
end

---checks the square for a panel object and returns the object and status
function PowerBank:getPanelStatusOnSquare(square)
    local panel = ISA.WorldUtil.findTypeOnSquare(square, "Panel")
    if panel ~= nil then
        return panel, square:isOutside() and self:getPanelStatus(panel) or "indoors"
    end
    return nil, ""
end

---bugfix, verify panels
function PowerBank:checkPanels()
    local getSquare = getSquare

    local dup = {}
    for i = #self.panels, 1, -1 do
        local panel = self.panels[i]
        local square = getSquare(panel.x, panel.y, panel.z)
        if square ~= nil then --TODO check if chunk loaded
            local panelObj, status = self:getPanelStatusOnSquare(square)
            if not panelObj or status ~= "connected" or dup[square] then
                table.remove(self.panels, i)
                if panelObj ~= nil then
                    panelObj:getModData().pbLinked = nil
                    panelObj:transmitModData()
                end
            end
            dup[square] = true
        end
    end
    self.npanels = #self.panels
end

---@param modChanrge number
---@return string?
function PowerBank:getSpriteForOverlay(modChanrge)
    if self.batteries <= 0 then return nil end
    if modChanrge == nil then modChanrge = self.maxcapacity > 0 and self.charge / self.maxcapacity or 0 end
    if modChanrge < 0.10 then
        --show 0 charge
        if self.batteries < 5 then
            --show bottom shelf
            return "solarmod_tileset_01_1"
        elseif self.batteries < 9 then
            --show two shelves
            return "solarmod_tileset_01_2"
        elseif self.batteries < 13 then
            --show three shelves
            return "solarmod_tileset_01_3"
        elseif self.batteries < 17 then
            --show four shelves
            return "solarmod_tileset_01_4"
        else
            --show five shelves
            return "solarmod_tileset_01_5"
        end
    elseif modChanrge < 0.35 then
        --show 25 charge
        if self.batteries < 5 then
            --show bottom shelf
            return "solarmod_tileset_01_16"
        elseif self.batteries < 9 then
            --show two shelves
            return "solarmod_tileset_01_20"
        elseif self.batteries < 13 then
            --show three shelves
            return "solarmod_tileset_01_24"
        elseif self.batteries < 17 then
            --show four shelves
            return "solarmod_tileset_01_28"
        else
            --show five shelves
            return "solarmod_tileset_01_32"
        end
    elseif modChanrge < 0.65 then
        -- show 50 charge
        if self.batteries < 5 then
            --show bottom shelf
            return "solarmod_tileset_01_17"
        elseif self.batteries < 9 then
            --show two shelves
            return "solarmod_tileset_01_21"
        elseif self.batteries < 13 then
            --show three shelves
            return "solarmod_tileset_01_25"
        elseif self.batteries < 17 then
            --show four shelves
            return "solarmod_tileset_01_29"
        else
            --show five shelves
            return "solarmod_tileset_01_33"
        end
    elseif modChanrge < 0.95 then
        -- show 75 charge
        if self.batteries < 5 then
            --show bottom shelf
            return "solarmod_tileset_01_18"
        elseif self.batteries < 9 then
            --show two shelves
            return "solarmod_tileset_01_22"
        elseif self.batteries < 13 then
            --show three shelves
            return "solarmod_tileset_01_26"
        elseif self.batteries < 17 then
            --show four shelves
            return "solarmod_tileset_01_30"
        else
            --show five shelves
            return "solarmod_tileset_01_34"
        end
    else
        --show 100 charge
        if self.batteries < 5 then
            --show bottom shelf
            return "solarmod_tileset_01_19"
        elseif self.batteries < 9 then
            --show two shelves
            return "solarmod_tileset_01_23"
        elseif self.batteries < 13 then
            --show three shelves
            return "solarmod_tileset_01_27"
        elseif self.batteries < 17 then
            --show four shelves
            return "solarmod_tileset_01_31"
        else
            --show five shelves
            return "solarmod_tileset_01_35"
        end
    end
end

function PowerBank:updateSprite(modCharge)
    local newSprite = self:getSpriteForOverlay(modCharge)
    local isoObject = self:getIsoObject()
    if not isoObject then return end
    local attached = isoObject:getAttachedAnimSprite()

    if attached ~= nil then
        for i = 0, attached:size() - 1 do
            local attachedSprite = attached:get(i)
            local attachedName = attachedSprite:getName()
            if attachedName == newSprite then return end
            if attachedName and string.find(attachedName, "^solarmod_tileset_01_") then
                isoObject:RemoveAttachedAnim(i)
                break
            end
        end
    end
    if newSprite ~= nil then
        isoObject:addAttachedAnimSpriteByName(newSprite)
    end
end

--- The bank's own IsoGenerator is what actually powers the surrounding squares, so
--- it is switched on only while the bank is on and has charge to give.
function PowerBank:updateGenerator(dCharge)
    if dCharge == nil then
        dCharge = self.luaSystem:getModifiedSolarOutput(self.npanels) - self.drain
        if sandbox.ChargeFreq == 1 then
            dCharge = dCharge / 6
        end
    end
    local square = self:getSquare()
    if not square then return end
    local generator = square:getGenerator()
    if not generator then return end

    generator:setActivated(self.on and self.charge + dCharge > 0)
    -- The bank is not a combustion generator, so it never gasses the building it is in.
    local building = square:getBuilding()
    if building then building:setToxic(false) end
end

--if freezer timers, Powerbank generator condition / fuel are wrong check here
function PowerBank:loadGenerator()
    local generator = self:getIsoObject()
    if not generator then return end
    generator:setSurroundingElectricity()
    generator:getCell():addToProcessIsoObjectRemove(generator)
    self:updateGenerator()
    self:updateConGenerator()
end

function PowerBank:connectBackupGenerator(generator)
    self.conGenerator = {}
    self.conGenerator.x = generator:getX()
    self.conGenerator.y = generator:getY()
    self.conGenerator.z = generator:getZ()
    self.conGenerator.ison = generator:isActivated()
    self.lastHour = 0
    self:saveData(true)
end

function PowerBank:disconnectBackupGenerator(generator)
    self.conGenerator = false
    self:saveData(true)
end

function PowerBank:autoConnectBackup()
    local area = ISA.WorldUtil.getValidBackupArea(3)

    self.conGenerator = false
    for ix = self.x - area.radius, self.x + area.radius do
        for iy = self.y - area.radius, self.y + area.radius do
            for iz = self.z - area.levels, self.z + area.levels do
                if ix >= 0 and iy >= 0 and iz >= 0 then
                    local isquare = IsoUtils.DistanceToSquared(self.x,self.y,self.z,ix,iy,iz) <= area.distance and getSquare(ix, iy, iz)
                    local generator = isquare and self.luaSystem:getValidBackupOnSquare(isquare)
                    if generator then
                        self:connectBackupGenerator(generator)
                        return
                    end
                end
            end
        end
    end
end

function PowerBank:getConGenerator()
    if self.conGenerator then
        local square = getSquare(self.conGenerator.x,self.conGenerator.y,self.conGenerator.z)
        if square then
            local generator = square:getGenerator()
            if not generator then self.conGenerator = false end
            return generator, square
        end
    end
    return nil
end

function PowerBank:updateConGenerator()
    local currentHour = math.floor(getGameTime():getWorldAgeHours())
    if self.lastHour == currentHour then return end
    local conGenerator,square = self:getConGenerator()
    if conGenerator then

        conGenerator:update()

        if self.on and ISA.WorldUtil.findOnSquare(square, "solarmod_tileset_01_15") then
            -- The threshold is one hour of load, so the backup stops once the bank holds
            -- enough to carry the base on its own for an hour.
            --
            -- Recomputed here rather than read off the field. The bank does not drain
            -- while the backup is running, so updateDrain is not called during that time
            -- and self.drain stays frozen at whatever the load was when the generator
            -- started. Turning appliances off while it ran left the generator running
            -- against a number that had stopped being true.
            self:updateDrain()
            local minfailsafe = self.drain

            if conGenerator:isActivated() then
                if self.charge > minfailsafe then conGenerator:setActivated(false) end
            else
                if self.charge < minfailsafe and conGenerator:getFuel() > 0 and conGenerator:getCondition() > 20 then
                    conGenerator:setActivated(true)
                end
            end
        end
        self.lastHour = currentHour
        -- if isActive ~= setActive then
        self.conGenerator.ison = conGenerator:isActivated()
    end
end

return PowerBank
