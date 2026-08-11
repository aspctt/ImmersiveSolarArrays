if isClient() then return end

---@class PowerbankSystem_Server
local PBSystem = require "ImmersiveSolarArrays/PowerBank/PowerBankSystem_Server"

local Commands = {}

local function noise(message) return PBSystem.instance:noise(message) end

---@param args table
---@return PowerBankObject_Server
local function getPowerBank(args)
    return PBSystem.instance:getLuaObjectAt(args.x, args.y, args.z)
end

function Commands.disconnectPanel(player,args)
    local pb = getPowerBank(args.pb)
    if pb == nil then return end
    for i,panel in ipairs(pb.panels) do
        if panel.x == args.panel.x and panel.y == args.panel.y and panel.z == args.panel.z then
            table.remove(pb.panels,i)
            pb.npanels = pb.npanels - 1
            break
        end
    end
    pb:saveData(true)
end

function Commands.connectPanel(player,args)
    local pb = getPowerBank(args.pb)
    if pb == nil then return end

    local x,y,z = args.panel.x,args.panel.y,args.panel.z
    local square = getSquare(x,y,z)
    if square == nil then return end

    local panel, status = pb:getPanelStatusOnSquare(square)
    if panel == nil or status ~= "not connected" then return end

    -- A panel belongs to one bank. Detach it from whichever it was wired to before,
    -- otherwise the old bank keeps counting it until the next daily sweep.
    PBSystem.instance:removePanel(panel)

    panel:getModData().pbLinked = { x = pb.x, y = pb.y, z = pb.z }
    panel:transmitModData()

    table.insert(pb.panels,{ x = x, y = y, z = z })
    pb.npanels = pb.npanels + 1
    pb:saveData(true)
end

function Commands.moveBattery(player,args)
    local pb = getPowerBank(args[1])
    if pb == nil then return end
    noise("Transfering Battery")
    if args[2] == "take" then
        pb.batteries = pb.batteries - 1
        if pb.batteries > 0 then
            pb.charge = pb.charge - args[3]
            pb.maxcapacity = pb.maxcapacity - args[4]
        else
            pb.charge = 0
            pb.maxcapacity = 0
        end
    elseif args[2] == "put" then
        pb.batteries = pb.batteries + 1
        pb.charge = pb.charge + args[3]
        pb.maxcapacity = pb.maxcapacity + args[4]
    end
    pb:updateGenerator()
    pb:updateSprite()
    pb:saveData(true)
end

---@param pb PowerBankObject_Server
---@param x number
---@param y number
---@param z number
---@return boolean
local function isCloserThanCurrentBackup(pb, x, y, z)
    if not pb.conGenerator then return true end
    local current = IsoUtils.DistanceToSquared(pb.x, pb.y, pb.z, pb.conGenerator.x, pb.conGenerator.y, pb.conGenerator.z)
    return current > IsoUtils.DistanceToSquared(pb.x, pb.y, pb.z, x, y, z)
end

function Commands.plugGenerator(player,args)
    local square = getSquare(args.gen.x,args.gen.y,args.gen.z)
    local generator = square and square:getGenerator()
    for _,i in ipairs(args.pbList) do
        local pb = getPowerBank(i)
        if pb then
            if args.plug and generator then
                -- A bank already wired to something nearer keeps what it has.
                if isCloserThanCurrentBackup(pb, args.gen.x, args.gen.y, args.gen.z) then
                    noise("adding backup")
                    pb:connectBackupGenerator(generator)
                end
            else
                if pb.conGenerator and pb.conGenerator.x == args.gen.x and pb.conGenerator.y == args.gen.y and pb.conGenerator.z == args.gen.z then
                    noise("removing backup")
                    pb.conGenerator = false
                end
            end
            pb:saveData(true)
        end
    end
end

function Commands.activateGenerator(player,args)
    local pb = getPowerBank(args.pb)
    if pb and pb.conGenerator then
        pb.conGenerator.ison = args.activate
        pb:saveData(true)
    end
end

function Commands.activatePowerbank(player,args)
    local pb = getPowerBank(args.pb)
    if pb then
        pb.on = args.activate
        pb.switchchanged = true
        pb:updateDrain()
        pb:updateGenerator()
        pb:saveData(true)
    end
end

function Commands.countBatteries(player,args)
    local pb = getPowerBank(args)
    local isopb = pb and pb:getIsoObject()
    if isopb then
        pb:calculateBatteryStats(isopb:getContainer())
        pb:updateSprite()
        pb:saveData(true)
    end
end

function Commands.troubleshoot(player, args)
    local pb = getPowerBank(args)
    if not pb then return end

    local isoPB = pb:getIsoObject()
    if not isoPB then return end

    -- remove invalid generators
    local objects = pb:getIsoObject():getSquare():getSpecialObjects()
    for i = objects:size() - 1, 0 , -1 do
        local object = objects:get(i)
        if instanceof(object, "IsoGenerator") and (object:getSprite() == nil or object:getModData().generatorFullType == "ISA.PowerBank_test") then
            object:remove()
        end
    end

    -- remove old attached sprites
    isoPB:RemoveAttachedAnims()

    pb:calculateBatteryStats(isoPB:getContainer())
    pb:updateSprite()
    pb:saveData(true)
end

PBSystem.Commands = Commands
