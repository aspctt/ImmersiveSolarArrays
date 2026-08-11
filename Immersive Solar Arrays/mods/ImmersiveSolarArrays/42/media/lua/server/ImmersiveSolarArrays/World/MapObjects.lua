local ISA = require "ImmersiveSolarArrays/Utilities"
local RandomWorldSpawns = require "ImmersiveSolarArrays/World/RandomWorldSpawns"

if isClient() then

    ---update isoObjects when chunk loads
    local function LoadPowerbank(isoObject)
        isoObject:getCell():addToProcessIsoObjectRemove(isoObject)
        -- The server converts the object to a generator and the change reaches the
        -- client a moment later, so on this side the container is not always there yet.
        local container = isoObject:getContainer()
        if container then
            container:setAcceptItemFunction("AcceptItemFunction.ISA_Batteries")
        end
    end
    MapObjects.OnLoadWithSprite("solarmod_tileset_01_0", LoadPowerbank, 6)

else

    ---update isoObjects when chunk loads
    local function LoadPowerbank(isoObject)
        -- A bank is only a bank once it is an IsoGenerator, and only then does it get a
        -- Lua object. One that was left as a plain IsoObject, by a failed placement or a
        -- save made against a broken version, would otherwise stay inert forever: no
        -- charge, no status window, and invisible to every panel looking for a bank.
        -- Converting here means a chunk reload repairs it.
        if not instanceof(isoObject, "IsoGenerator") then
            isoObject = ISA.WorldUtil.replaceIsoObjectWithGenerator(isoObject)
        end

        ISA.PBSystem_Server:loadIsoObject(isoObject)

        local container = isoObject:getContainer()
        if container then
            container:setAcceptItemFunction("AcceptItemFunction.ISA_Batteries")
        end
    end
    MapObjects.OnLoadWithSprite("solarmod_tileset_01_0", LoadPowerbank, 6)

    ---update isoObjects when chunk loads first time
    local function OnNewWithSprite(isoObject)
        local isaType = ISA.WorldUtil.getType(isoObject)
        local square = isoObject:getSquare()
        if not square then error("ISA: OnNewWithSprite no square") return end

        if isaType == "PowerBank" then
            local index = isoObject:getObjectIndex()
            local spriteName = isoObject:getTextureName()
            square:transmitRemoveItemFromSquare(isoObject)
            RandomWorldSpawns.addToWorld(square, spriteName, index)
        else
            square:getSpecialObjects():add(isoObject)
        end
    end

    local MapObjects = MapObjects
    for sprite, type in pairs(ISA.WorldUtil.ISATypes) do
        MapObjects.OnNewWithSprite(sprite, OnNewWithSprite, 5)
    end

end
