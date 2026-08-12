--[[
    Throwing the battery bank's switch.

    Client, for the same reason as ConnectPanel: it is queued from the world context menu
    and the result travels to the server as a command. The build 41 version mutated the
    server system in place, which only ever worked in singleplayer.
--]]

require "TimedActions/ISBaseTimedAction"
---@class ImmersiveSolarArrays
local ISA = require "ImmersiveSolarArrays/Utilities"
local PBSystem = require "ImmersiveSolarArrays/PowerBank/PowerBankSystem_Client"

local ActivatePowerBank = ISBaseTimedAction:derive("ISA_ActivatePowerBank")

function ActivatePowerBank:new(character, powerbank, activate)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.activate = activate
    o.isoPb = powerbank
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end

function ActivatePowerBank:isValid()
    return self.isoPb:getObjectIndex() ~= -1
end

function ActivatePowerBank:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 40 - 3 * self.character:getPerkLevel(Perks.Electricity)
end

function ActivatePowerBank:complete()
    local square = self.isoPb:getSquare()
    local instance = PBSystem.instance
    if not (square and instance) then return end

    local pb = instance:getLuaObjectOnSquare(square)

    -- Below electrical 3 the switch does not always take, and the odds improve with skill.
    if self.activate then
        local level = self.character:getPerkLevel(Perks.Electricity)
        if level < 3 and ZombRand(6 - 2 * level) ~= 0 then
            square:playSound("GeneratorFailedToStart")
            self.activate = false
        end
    end

    if self.activate and pb and pb.charge > 0 then
        square:playSound("GeneratorStarting")
    elseif self.activate then
        square:playSound("GeneratorFailedToStart")
    else
        square:playSound("GeneratorStopping")
    end

    if not pb then return end
    instance:sendCommand(self.character, "activatePowerbank", {
        pb = { x = pb.x, y = pb.y, z = pb.z },
        activate = self.activate,
    })
end

ISA.ActivatePowerbank = ActivatePowerBank
