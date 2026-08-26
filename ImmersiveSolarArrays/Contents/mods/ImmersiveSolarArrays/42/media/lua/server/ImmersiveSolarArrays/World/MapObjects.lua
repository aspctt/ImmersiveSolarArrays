local ISA = require "ImmersiveSolarArrays/Utilities"
local RandomWorldSpawns = require "ImmersiveSolarArrays/World/RandomWorldSpawns"

--- The failsafe goes down as a floor rug, which is the only way it can be placed on a
--- tile a generator already occupies, and that also buries it under the generator when
--- the square is drawn. Lifting it on every chunk load keeps it visible, and repairs the
--- ones already sitting in a world.
local function LoadFailsafe(isoObject)
    ISA.WorldUtil.raiseToTopOfSquare(isoObject)
end
MapObjects.OnLoadWithSprite("solarmod_tileset_01_15", LoadFailsafe, 6)

--- The same lift, at the moment the failsafe is put down rather than on the next chunk
--- load, and on this side rather than the server's.
---
--- Raising it reorders the square's object list, and an object's place in that list is
--- its address on the wire: IsoGenerator.syncIsoObjectSend writes x, y, z and
--- getObjectIndex, and the far end resolves the object out of the square by that index.
--- The server was lifting the failsafe from its own copy of the square and the client
--- was not, so from the placement until the chunk next streamed the two disagreed by one
--- about where the generator sat, and every state the server sent for it landed on the
--- wrong object. The generator stopped following its switch, its fuel stopped moving,
--- and the failsafe looked broken because the machine it drives had stopped listening.
---
--- Both sides now lift it at the same point, so the lists agree without a packet: there
--- is no reorder message in the protocol, and resending the object would be sending the
--- other end something it already has. The chunk load half above stays as it is, which
--- is what puts an already placed one right.
---
--- Registered here only for the side without one. The server does it from the powerbank
--- system's own OnObjectAdded, which a client never reaches.
if isClient() then
    Events.OnObjectAdded.Add(function(isoObject)
        if not isoObject then return end
        if isoObject:getTextureName() ~= "solarmod_tileset_01_15" then return end
        ISA.WorldUtil.raiseToTopOfSquare(isoObject)
    end)
end

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

        -- And a bank is only usable once it has the container the tiledef gives it.
        -- One that came out of a failed placement is a battery bank you cannot open, so
        -- no batteries go in, nothing charges, and the client's own refresh walks a
        -- container that is not there. Picking it up and putting it down again built it,
        -- which is not something a player should have to work out.
        --
        -- The engine returns at once when the container is already there, so this is a
        -- field read on every other bank. Sent on only when one was really missing.
        local container = isoObject:getContainer()
        if not container then
            isoObject:createContainersFromSpriteProperties()
            container = isoObject:getContainer()
            if container then
                container:setExplored(true)
                isoObject:transmitCompleteItemToClients()
            end
        end

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
