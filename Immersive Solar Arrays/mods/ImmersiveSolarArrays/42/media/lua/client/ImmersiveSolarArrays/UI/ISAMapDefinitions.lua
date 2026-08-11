require 'Maps/ISMapDefinitions'

local LootMaps = LootMaps
local MapUtils = MapUtils

-- V3 is what every vanilla loot map uses in build 42. It is V1 plus the text layers, so
-- a stash map drawn with V1 came out missing all its street and place names.
local function addMapInit(name,x1,y1,x2,y2)
    LootMaps.Init[name] = function(mapUI)
        local mapAPI = mapUI.javaObject:getAPIv1()
        MapUtils.initDirectoryMapData(mapUI, LootMaps.DEFAULT_MAP_DIRECTORY)
        MapUtils.initDefaultStyleV3(mapUI)
        mapAPI:setBoundsInSquares(x1,y1,x2,y2)
        MapUtils.overlayPaper(mapUI)
    end
end
addMapInit("ISA_Stash_RiversideW1",5400, 5820, 5649, 6119)
addMapInit("ISA_Stash_RosewoodE1",8000, 12100, 8399, 12349)
addMapInit("ISA_Stash_Louisville1",13030, 2860, 13439, 3139)
