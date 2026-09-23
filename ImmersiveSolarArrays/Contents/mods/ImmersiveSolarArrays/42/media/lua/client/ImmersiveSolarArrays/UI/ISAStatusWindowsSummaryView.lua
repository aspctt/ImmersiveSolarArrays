require "ISUI/ISPanelJoypad"
local isa = require "ImmersiveSolarArrays/Utilities"

local ISAWindowsSumaryTab = ISPanelJoypad:derive("ISAWindowsSumaryTab")

--- The tab as it was drawn: a 580 by 390 panel, the summary box in the top right corner
--- and each piece of artwork at a fixed x, y, width and height around it.
local DESIGN_WIDTH, DESIGN_HEIGHT = 580, 390
local ART = {
	house = { 321, 185, 254, 185 },
	cables = { 52, 358, 403, 24 },
	battery = { 16, 302, 76, 69 },
	batteryCross = { 17, 305, 72, 72 },
	sun = { 0, 0, 128, 128 },
	moon = { 0, 0, 128, 128 },
	solarPanel = { 123, 267, 155, 103 },
	solarPanelCross = { 166, 268, 72, 72 },
}
--- Room left between the bottom of the summary box and the artwork under it.
local ART_GAP = 8

--- One piece of artwork, placed where layout moved the whole picture to.
---@param texture Texture
---@param rect table x, y, width, height, as in ART
---@return ISImage
function ISAWindowsSumaryTab:addArt(texture, rect)
	local image = ISImage:new(self.artX + rect[1], self.artY + rect[2], rect[3], rect[4], texture)
	image.scaledWidth = rect[3]
	image.scaledHeight = rect[4]
	image:initialise()
	image.parent = self
	self:addChild(image)
	return image
end

function ISAWindowsSumaryTab:initialise()
	ISPanelJoypad.initialise(self)

	-- House
	self.imageHouse = self:addArt(self.textureHouse, ART.house)

	-- Cables
	self.imageCables = self:addArt(self.textureCables, ART.cables)

	-- Battery
	self.imageBattery = self:addArt(self.textureBattery, ART.battery)
	--self.imageBattery:setMouseOverText("Test")

	self.imageBatteryCross = self:addArt(self.textureCross, ART.batteryCross)

	-- Sun and radiation
	self.imageSun = self:addArt(self.textureSun, ART.sun)

--[[
	self.imageSolarRadiation1 = ISImage:new(81, 122, 93, 78, self.textureSolarRadiation)
	self.imageSolarRadiation1.scaledWidth = 93
	self.imageSolarRadiation1.scaledHeight = 78
	self.imageSolarRadiation1:initialise()
	self.imageSolarRadiation1.parent = self
    self:addChild(self.imageSolarRadiation1)

	self.imageSolarRadiation2 = ISImage:new(98, 107, 93, 78, self.textureSolarRadiation)
	self.imageSolarRadiation2.scaledWidth = 93
	self.imageSolarRadiation2.scaledHeight = 78
	self.imageSolarRadiation2:initialise()
	self.imageSolarRadiation2.parent = self
    self:addChild(self.imageSolarRadiation2)

	self.imageSolarRadiation3 = ISImage:new(116, 91, 93, 78, self.textureSolarRadiation)
	self.imageSolarRadiation3.scaledWidth = 93
	self.imageSolarRadiation3.scaledHeight = 78
	self.imageSolarRadiation3:initialise()
	self.imageSolarRadiation3.parent = self
    self:addChild(self.imageSolarRadiation3)

	self.imageSolarRadiationCross = ISImage:new(118, 116, 72, 72, self.textureCross)
	self.imageSolarRadiationCross.scaledWidth = 72
	self.imageSolarRadiationCross.scaledHeight = 72
	self.imageSolarRadiationCross:initialise()
	self.imageSolarRadiationCross.parent = self
    self:addChild(self.imageSolarRadiationCross)
	]]

	-- Moon
	self.imageMoon = self:addArt(self.textureMoon, ART.moon)

	-- Solar Panel (two modes)
	self.imageSolarPanel = self:addArt(self.textureSolarPanel, ART.solarPanel)
	self.imageSolarPanel:setVisible(false)

	self.imageSolarPanelNoEnergy = self:addArt(self.textureSolarPanelNoEnergy, ART.solarPanel)

	self.imageSolarPanelCross = self:addArt(self.textureCross, ART.solarPanelCross)

	-- Fix the daytime/nightime icon
	if isa.isDayTime() then
		self.imageSun:setVisible(true)
		self.imageMoon:setVisible(false)
		self.night = false
	else
		self.imageSun:setVisible(false)
		self.imageMoon:setVisible(true)
		self.night = true
	end
end

function ISAWindowsSumaryTab:createChildren()
	self:setScrollChildren(true)
	self:addScrollBars()
end

function ISAWindowsSumaryTab:setVisible(visible)
    self.javaObject:setVisible(visible)
	if visible then
		self:setWidthAndParentWidth(self.viewWidth)
		self:setHeightAndParentHeight(self.viewHeight)
		self.currentFrame = 0
	end
end

function ISAWindowsSumaryTab:render()
	local pb = self.parent.parent.luaPB
	if not (pb and pb:getIsoObject()) then return self.parent.parent:close() end

	-- Update every ~1 sec
	if self.currentFrame == 0 then
		pb:updateFromIsoObject()
		self.maxCapacity = pb.maxcapacity
		self.charge = pb.charge
		self.drain = pb.drain
		self.batteryLevel = pb.maxcapacity > 0 and pb.charge / pb.maxcapacity or 0
		self.panelsMaxInput = pb.luaSystem:getMaxSolarOutput(pb.npanels)
		self.panelsInput = pb.luaSystem:getModifiedSolarOutput(pb.npanels)
		self.difference = self.panelsInput - (pb:shouldDrain() and pb.drain or 0)

		if isa.isDayTime() then
			if (self.night == true) then
				self.imageSun:setVisible(true)
				self.imageMoon:setVisible(false)
				self.night = false
			end
		else
			if (self.night == false) then
				self.imageSun:setVisible(false)
				self.imageMoon:setVisible(true)
				self.night = true
			end
		end

		if (pb.batteries > 0) then
			if (self.thereAreBatteries == false) then
				self.imageBatteryCross:setVisible(false)
				self.thereAreBatteries = true
			end
		else
			if (self.thereAreBatteries == true) then
				self.imageBatteryCross:setVisible(true)
				self.thereAreBatteries = false
			end
		end

		if (pb.npanels > 0) then
			if (self.thereArePanels == false) then
				self.imageSolarPanelCross:setVisible(false)
				self.thereArePanels = true
			end
		else
			-- Tested for false here until now, so once panels had been seen the cross
			-- never came back after the last one was disconnected.
			if (self.thereArePanels == true) then
				self.imageSolarPanelCross:setVisible(true)
				self.thereArePanels = false
			end
		end

		if self.difference > 0 then
			if (self.batteryCharging == false) then
				self.imageSolarPanel:setVisible(true)
				self.imageSolarPanelNoEnergy:setVisible(false)
				self.batteryCharging = true
			end
		else
			if (self.batteryCharging == true) then
				self.imageSolarPanel:setVisible(false)
				self.imageSolarPanelNoEnergy:setVisible(true)
				self.batteryCharging = false
			end
		end

		self.currentFrame = self.fps - 1
	else
		self.currentFrame = self.currentFrame - 1
	end

	-- Summary box
	local line = self.sumBox.line
	local rectX, rectY, rectW, rectH = self.sumBox.x, self.sumBox.y, self.sumBox.width, self.sumBox.height
	local text_x = self.sumBox.textX
	local text_x2 = text_x + self.sumBox.pad1
	local text_y = rectY + 10
	self:drawRect(rectX, rectY, rectW, rectH, 0.5, 0.16, 0.16, 0.16)
	self:drawRectBorder(rectX, rectY, rectW, rectH, 1, 1, 1, 1)

	-- Summary text
	self:drawTextRight(getText("IGUI_ISAWindowsSumaryTab_PanelsStatus") .. ":", text_x, text_y + line * 0, 0, 1, 0, 1, UIFont.Small)
	self:drawTextRight(getText("IGUI_ISAWindowsSumaryTab_BatteryLevel") .. ":", text_x, text_y + line *1, 0, 1, 0, 1, UIFont.Small)

	-- Solar panels status
	if (self.drain > self.panelsMaxInput) then
		self:drawText(getText("IGUI_ISAWindowsSumaryTab_NoEnoughPanels"), text_x2, text_y + line * 0, 0, 1, 0, 1, UIFont.Small)
	else
		if (self.drain > self.panelsInput) then
			self:drawText(getText("IGUI_ISAWindowsSumaryTab_NoEnoughSun"), text_x2, text_y + line * 0, 0, 1, 0, 1, UIFont.Small)
		else
			self:drawText(getText("IGUI_ISAWindowsSumaryTab_Working"), text_x2, text_y + line * 0, 0, 1, 0, 1, UIFont.Small)
		end
	end

	if (self.maxCapacity > 0) then
		self:drawText(string.format("%d%%", self.batteryLevel * 100), text_x2, text_y + line * 1, 0, 1, 0, 1, UIFont.Small)

		if (self.difference > 0) then
			if self.maxCapacity == self.charge then
				self:drawTextRight(getText("IGUI_ISAWindowsSumaryTab_BatteryStatus") .. ":", text_x, text_y + line *2, 0, 1, 0, 1, UIFont.Small)
				self:drawText(getText("IGUI_ISAWindowsSumaryTab_FullyCharged"), text_x2, text_y + line *2, 0, 1, 0, 1, UIFont.Small)
			else
				local ctime = ((self.maxCapacity - self.charge) / self.difference)
				local days = math.floor(ctime / 24)
				local hours = math.floor(ctime % 24)
				local minutes = math.floor((ctime - math.floor(ctime)) * 60)
				self:drawTextRight(getText("IGUI_ISAWindowsSumaryTab_ChargedIn"), text_x, text_y + line *2, 0, 1, 0, 1, UIFont.Small)
				self:drawText(days > 0 and (days .. " " .. getText("IGUI_Gametime_days")) or hours > 0 and (hours .. " " .. getText("IGUI_Gametime_hours")) or (minutes .. " " .. getText("IGUI_Gametime_minutes")), text_x2, text_y + line *2, 0, 1, 0, 1, UIFont.Small)
			end
		elseif (self.difference < 0) then
			if (self.charge == 0) then
				self:drawTextRight(getText("IGUI_ISAWindowsSumaryTab_BatteryStatus") .. ":", text_x, text_y + line *2, 0, 1, 0, 1, UIFont.Small)
				self:drawText(getText("IGUI_ISAWindowsSumaryTab_FullyDischarged"), text_x2, text_y + line *2, 0, 1, 0, 1, UIFont.Small)
			else
				local dtime = math.abs(self.charge / self.difference)
				local days = math.floor(dtime / 24)
				local hours = math.floor(dtime % 24)
				local minutes = math.floor((dtime - math.floor(dtime)) * 60)
				self:drawTextRight(getText("IGUI_ISAWindowsSumaryTab_DischargedIn"), text_x, text_y + line *2, 0, 1, 0, 1, UIFont.Small)
				self:drawText(days > 0 and (days .. " " .. getText("IGUI_Gametime_days")) or hours > 0 and (hours .. " " .. getText("IGUI_Gametime_hours")) or (minutes .. " " .. getText("IGUI_Gametime_minutes")), text_x2, text_y + line * 2, 0, 1, 0, 1, UIFont.Small)
			end
		else
			self:drawText(getText("IGUI_ISAWindowsSumaryTab_NotCharging"), text_x2, text_y + line *2, 0, 1, 0, 1, UIFont.Small)
		end
		if self.charge > 0 and self.drain > 0 then
			local dtime = self.charge / self.drain
			local days = math.floor(dtime / 24)
			local hours = math.floor(dtime % 24)
			local minutes = math.floor((dtime - math.floor(dtime)) * 60)
			self:drawTextRight(getText("IGUI_ISAWindowsSumaryTab_BatteryRemaining"), text_x, text_y + line *3, 0, 1, 0, 1, UIFont.Small)
			self:drawText(string.format("%d %s\n%d %s\n%d %s",days,getText("IGUI_Gametime_days"),hours,getText("IGUI_Gametime_hours"),minutes,getText("IGUI_Gametime_minutes")), text_x2, text_y + line *3, 0, 1, 0, 1, UIFont.Small)
		end
	else
		self:drawText(getText("IGUI_ISAWindowsSumaryTab_NoBatteries"), text_x2, text_y + line *1, 0, 1, 0, 1, UIFont.Small)
		self:drawText(getText("IGUI_ISAWindowsSumaryTab_NotCharging"), text_x2, text_y + line *2, 0, 1, 0, 1, UIFont.Small)
	end
end

function ISAWindowsSumaryTab:new(x, y, width, height)
	local o = ISPanelJoypad.new(self, x, y, width, height)
	o:noBackground()

	-- Textures
	o.textureBattery = getTexture("media/ui/isa_battery.png")
	o.textureCables = getTexture("media/ui/isa_cables.png")
	o.textureHouse = getTexture("media/ui/isa_house.png")
	o.textureSolarPanel = getTexture("media/ui/isa_solar_panel.png")
	o.textureSolarPanelNoEnergy = getTexture("media/ui/isa_solar_panel_no_energy.png")
	o.textureCross = getTexture("media/ui/isa_cross.png")
	o.textureSolarRadiation = getTexture("media/ui/isa_solar_radiation.png")
	o.textureSun = getTexture("media/ui/isa_sun.png")
	o.textureMoon = getTexture("media/ui/isa_moon.png")

	o:layout()

	-- Used variables
	o.currentFrame = 0
	o.thereAreBatteries = false
	o.thereArePanels = false
	o.panelsMaxInput = 0
	o.panelsInput = 0
	o.batteryLevel = 0
	o.batteryCharging = false
	o.difference = 0
	o.night = false

	o.fps = getCore():getOptionUIRenderFPS()
   return o
end

--- Fit the summary box to the font, then move the artwork clear of it.
---
--- The tab was laid out in fixed pixels for the 19 pixel font. The box is six lines of
--- text tall, so it grew with the font while the artwork stayed where it was, and the
--- artwork is drawn over the box. The game's default font setting scales with the
--- window: 19 pixels at 1080 lines, 26 at 1440, where the house already covered the
--- bottom of the box. At 33 and 38 pixels it covered the last lines of text, and the sun
--- the left end of the box. A language with longer text was squeezed into 580 pixels
--- rather than widening the tab.
---
--- The box keeps its old place against the right edge, and the tab widens when the box
--- needs more room. The artwork then moves down as one picture, just far enough that no
--- piece of it overlaps the box, so at the smallest font nothing moves at all.
function ISAWindowsSumaryTab:layout()
	local line = getTextManager():getFontHeight(UIFont.Small)
	local maxMeasured = self.measureTexts()
	local maxLR = maxMeasured.left + maxMeasured.right

	local box = { y = 20, width = maxLR + 50, height = 25 + line * 6, line = line, pad1 = 10 }
	self.viewWidth = math.max(DESIGN_WIDTH, box.width + 30)
	box.x = self.viewWidth - 20 - box.width
	box.textX = box.x + 20 + maxMeasured.left
	self.sumBox = box

	self.artX = math.floor((self.viewWidth - DESIGN_WIDTH) / 2)
	self.artY = 0
	local clear = box.y + box.height + ART_GAP
	for _, rect in pairs(ART) do
		local left = self.artX + rect[1]
		if left < box.x + box.width and left + rect[3] > box.x then
			self.artY = math.max(self.artY, clear - rect[2])
		end
	end
	self.viewHeight = DESIGN_HEIGHT + self.artY
end

function ISAWindowsSumaryTab.measureTexts()
	local textTable = {
		left = {
			"IGUI_ISAWindowsSumaryTab_PanelsStatus",
			"IGUI_ISAWindowsSumaryTab_BatteryLevel",
			"IGUI_ISAWindowsSumaryTab_BatteryStatus",
			"IGUI_ISAWindowsSumaryTab_ChargedIn",
			"IGUI_ISAWindowsSumaryTab_DischargedIn",
			"IGUI_ISAWindowsSumaryTab_BatteryRemaining",
		},
		right = {
			"IGUI_ISAWindowsSumaryTab_NoEnoughPanels",
			"IGUI_ISAWindowsSumaryTab_NoEnoughSun",
			"IGUI_ISAWindowsSumaryTab_FullyCharged",
			"IGUI_ISAWindowsSumaryTab_FullyDischarged",
			"IGUI_ISAWindowsSumaryTab_NotCharging",
			"IGUI_ISAWindowsSumaryTab_NoBatteries",
		}
	}

	local max = { left = 0, right = 0}
	for type,texts in pairs(textTable) do
		for _,text in ipairs(texts) do
			local width = getTextManager():MeasureStringX(UIFont.Small, getText(text))
			max[type] = math.max(max[type], width)
		end
	end

	return max
end

isa.StatusWindowSummaryView = ISAWindowsSumaryTab