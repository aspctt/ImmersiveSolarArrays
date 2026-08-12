--[[
    Inventory presentation for the mod's batteries.

    A battery bank battery is a drainable, so vanilla shows its remaining uses where the
    condition bar would be. These two patches show condition instead, which is what
    actually decides how much charge the battery can still hold.

    Loaded last, hence the name: the tooltip patch wraps whatever the previous mod in
    the chain installed rather than replacing it.

    Both are wrapped, because neither is worth taking the rest of the file down with it
    if the engine moves the method out from under us.
--]]

local ISA = require "ImmersiveSolarArrays/Utilities"
require "ImmersiveSolarArrays/UI/ISAUI"
require "ISUI/ISInventoryPane"

local ok, err = pcall(function()
    ISA.patchClassMetaMethod(zombie.inventory.types.DrainableComboItem.class, "DoTooltip", ISA.UI.DoTooltip_patch)
end)
if not ok then
    print("ISA: could not patch the drainable tooltip, battery tooltips will be vanilla. " .. tostring(err))
end

ISInventoryPane.drawItemDetails = ISA.UI.ISInventoryPane_drawItemDetails_patch(ISInventoryPane.drawItemDetails)
