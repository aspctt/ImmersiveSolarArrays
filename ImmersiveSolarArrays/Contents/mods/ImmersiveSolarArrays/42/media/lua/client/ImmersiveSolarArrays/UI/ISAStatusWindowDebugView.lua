require "ISUI/ISPanelJoypad"
require "ImmersiveSolarArrays/UI/ISAUI"
---@class ImmersiveSolarArrays
local ISA = require "ImmersiveSolarArrays/Utilities"

local rgbBad = ISA.UI.rgbBad

local WindowDebug = ISPanelJoypad:derive("ISAWindowDebug")

function WindowDebug:new(x, y, width, height)
    return ISPanelJoypad.new(self, x, y, width, height)
end

function WindowDebug:createChildren()
    local buttonHeight = math.floor(getTextManager():getFontHeight(UIFont.Small) * 1.5)
    local y = buttonHeight
    local width = math.max(self.width, getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_ISAWindow_Debug_ShowBackup")) + 10, getDebug() and getTextManager():MeasureStringX(UIFont.Small, "Connect Backup Generator") or 0)

    self.showBackupDetailsButton = ISButton:new(0, 0, width, buttonHeight, getText("IGUI_ISAWindow_Debug_ShowBackup"), self, self.showBackupDetails)
    self.showBackupDetailsButton:setBackgroundRGBA(0.2,0.2,0.2,1)
    self.showBackupDetailsButton:setBorderRGBA(0.2,0.2,0.2,1)
    self:addChild(self.showBackupDetailsButton)

    self.troubleshootButton = ISButton:new(0, y, width, buttonHeight, "Troubleshoot", self, self.troubleshoot)
    self.troubleshootButton:setBackgroundRGBA(0.3, 0.12, 0.12, 1)
    self.troubleshootButton:setBorderRGBA(0.3, 0.12, 0.12, 1)
    self.troubleshootButton.tooltip = "Use after bugfix updates if you're having issues."
    self:addChild(self.troubleshootButton)
    y = y + buttonHeight

    if getDebug() then
        self.containerButton = ISButton:new(0, y, width, buttonHeight, "Update Container Items", self, self.checkContainer)
        self.containerButton:setBackgroundRGBA(0.3,0.12,0.12,1)
        self.containerButton:setBorderRGBA(0.3,0.12,0.12,1)
        self.containerButton.tooltip = "Use if Battery Bank doesn't update after Inventory Transfer Action"
        self:addChild(self.containerButton)
        y = y + buttonHeight

        self.plugBackupButton = ISButton:new(0, y, width, buttonHeight, "Connect Backup Generator", self, self.plugBackup)
        self.plugBackupButton:setBackgroundRGBA(0.3,0.12,0.12,1)
        self.plugBackupButton:setBorderRGBA(0.3,0.12,0.12,1)
        self:addChild(self.plugBackupButton)
        y = y + buttonHeight
    end

    if width > self.width then self:setWidth(width) end
    self:setHeight(y)
end

function WindowDebug:setVisible(visible)
    ISPanelJoypad.setVisible(self,visible)
    if visible then
        self:setWidthAndParentWidth(self.width)
        self:setHeightAndParentHeight(self.height)
    end
end

function WindowDebug:prerender()
    local pb = self.parent.parent.luaPB
    if not (pb and pb:getIsoObject()) then return self.parent.parent:close() end

    if self.troubleshootButton.disableFrame then
        self.troubleshootButton.disableFrame = self.troubleshootButton.disableFrame -1
        if self.troubleshootButton.disableFrame <= 0 then self.troubleshootButton.enable = true; self.troubleshootButton.disableFrame = nil end
    end
    if getDebug() then
        if self.containerButton.disableFrame then
            self.containerButton.disableFrame = self.containerButton.disableFrame -1
            if self.containerButton.disableFrame <= 0 then self.containerButton.enable = true; self.containerButton.disableFrame = nil end
        end
        if self.plugBackupButton:isVisible() then
            local square = self.parent.parent.playerObj:getSquare()
            local generator = square and square:getGenerator()
            self.plugBackupButton.generator = generator
            self.plugBackupButton.enable = false
            if not generator then self.plugBackupButton.tooltip = rgbBad.rich .. "No generator on player's square"
            elseif not generator:isConnected() then self.plugBackupButton.tooltip = rgbBad.rich .. "Generator is not connected"
            elseif ISA.WorldUtil.findTypeOnSquare(square,"PowerBank") then self.plugBackupButton.tooltip = rgbBad.rich .. "This is a Powerbank"
            else
                self.plugBackupButton.enable = true
                self.plugBackupButton.tooltip = "Warning: No area check"
            end
        end
    end
end

function WindowDebug:showBackupDetails()
    local show = not self.parent.parent.detailsView.showBackupDetails
    self.parent.parent.detailsView.showBackupDetails = show
    self.showBackupDetailsButton.title = show and getText("IGUI_ISAWindow_Debug_HideBackup") or getText("IGUI_ISAWindow_Debug_ShowBackup")
end

function WindowDebug:checkContainer()
    local luapb = self.parent.parent.luaPB
    ISA.PBSystem_Client:sendCommand(self.parent.parent.playerObj,"countBatteries", { x = luapb.x, y = luapb.y, z = luapb.z })
    self.containerButton.enable = false
    self.containerButton.disableFrame = 3 * getPerformance():getUIRenderFPS()
end

function WindowDebug:plugBackup()
    local generator = self.plugBackupButton.generator
    if generator then
        local pb = self.parent.parent.luaPB
        ISA.PBSystem_Client:sendCommand(self.parent.parent.playerObj,"plugGenerator", { pbList = { { x = pb.x, y = pb.y, z = pb.z } }, gen = { x = generator:getX(), y = generator:getY(), z = generator:getZ() }, plug = true })
    end
end

function WindowDebug:troubleshoot()
    local luapb = self.parent.parent.luaPB
    ISA.PBSystem_Client:sendCommand(self.parent.parent.playerObj, "troubleshoot", { x = luapb.x, y = luapb.y, z = luapb.z })
    self.troubleshootButton.enable = false
    self.troubleshootButton.disableFrame = 5 * getPerformance():getUIRenderFPS()
end

ISA.StatusWindowDebugView = WindowDebug
