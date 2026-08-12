-- fixme SandboxVars are sometimes the default values at this stage - MP server values are loaded OnPreDistributionMerge???, SP are loaded when creating a character

require 'Items/Distributions'
require 'Items/ProceduralDistributions'
---@class ImmersiveSolarArrays
local ISA = require "ImmersiveSolarArrays/Utilities"

----------------------------------------------------------------------------------------------------------------------
local subDist = SuburbsDistributions
local pdList = ProceduralDistributions.list
local vehDist = VehicleDistributions

----------------------------------------------------------------------------------------------------------------------
---

ISA.Distributions = {}

local function insertRecursive(insertKey,insertInto,insertFrom,default)
    for key,value in pairs(insertFrom) do
        local _insertInto = insertInto[key]
        if not _insertInto and default then
            _insertInto = copyTable(default)
            insertInto[key] = _insertInto
        end
        if type(_insertInto) == "table" then
            if key == insertKey then
                for _,i in ipairs(value) do
                    table.insert(_insertInto,i)
                end
            else
                insertRecursive(insertKey,_insertInto,value,default)
            end
        end
    end
end

----------------------------------------------------------------------------------------------------------------------
--- add custom tables to ProceduralDistributions

pdList.ISABatteries = {
    rolls = 4,
    items = {
        "ISA.DeepCycleBattery", 36,
        "ISA.SuperBattery", 8,
        "ISA.DIYBattery", 8,
        "ISA.WiredCarBattery", 8,
    }
}
pdList.ISABatteriesCache = {
    rolls = 4,
    items = {
        "ISA.DeepCycleBattery", 64,
        "ISA.SuperBattery", 32,
        "ISA.DIYBattery", 32,
        "ISA.WiredCarBattery", 32,
    }
}
pdList.ISASolarBox = {
    rolls = 4,
    items = {
        "ISA.SolarPanel", 48,
        "ISA.DeepCycleBattery", 48,
        "ISA.SuperBattery", 24,
    },
    junk = {
        rolls = 1,
        items = {
            "ISA.ISAMag1", 64,
            "ISA.ISAInverter", 64,
            "ISA.SolarPanel", 16,
            "ISA.DeepCycleBattery", 16,
            "ISA.SuperBattery", 16,
            "ISA.SolarFailsafe", 0.1,
            "Base.ElectronicsScrap", 20,
            "Base.MetalBar", 10,
            "Base.SmallSheetMetal", 10,
            "Base.Screws", 5,
            "Base.ElectricWire", 20,
            "Base.RemoteCraftedV3", 0.1,
        }
    }
}

----------------------------------------------------------------------------------------------------------------------
---edit procList tables for room / cache house types

subDist.all.BatteryBank = {
    procedural = true,
    procList = {
        {name="ISABatteries", min=0, max=99},
    },
}
subDist.all.SolarBox = {
    procedural = true,
    procList = {
        { name = "ISASolarBox", min = 0, max = 99, weightChance = 80 },
        { name = "ISABatteries", min = 0, max = 99, weightChance = 20 },
        { name = "ISABatteriesCache", min = 0, max = 99, weightChance = 10 },
    },
}

subDist.ISASolarBoxCache = copyTable(subDist.electronicsstorage)
subDist.ISASolarBoxCache.isStore = nil
subDist.ISASolarBoxCache.SolarBox = copyTable(pdList.ISASolarBox)
subDist.ISASolarBoxCache.SolarBox.rolls = 32

insertRecursive("procList", subDist, {
    electronicsstorage = {
        metal_shelves = {
            procList = {
                { name = "ISASolarBox", min = 0, max = 1, weightChance = 10 },
            },
        },
        crate = {
            procList = {
                { name = "ISASolarBox", min = 0, max = 1, weightChance = 20 },
                { name = "ISABatteries", min = 0, max = 1, weightChance = 5 },
                { name = "ISABatteriesCache", min = 0, max = 1, weightChance = 5 },
            },
        },
    },
    garagestorage = {
        crate = {
            procList = {
                { name = "ISASolarBox", min = 0, max = 1, weightChance = 3 },
            },
        },
    },
    storageunit = {
        crate = {
            procList = {
                { name = "ISASolarBox", min = 0, max = 1, weightChance = 5 },
            },
        },
        metal_shelves = {
            procList = {
                { name = "ISASolarBox", min = 0, max = 1, weightChance = 3 },
            }
        }
    },
    warehouse = {
        crate = {
            procList = {
                { name = "ISASolarBox", min = 0, max = 1, weightChance = 5 },
                { name = "ISABatteries", min = 0, max = 1, weightChance = 5 },
            },
        },
    },
    --Cache
    SafehouseLoot = {
        metal_shelves = {
            procList = {
                { name = "ISASolarBox", min = 0, max = 1, weightChance = 5 },
            },
        },
    },
    ISASolarBoxCache = {
        crate = {
            procList = {
                { name = "ISASolarBox", min = 0, max = 3, weightChance = 25 },
                { name = "ISABatteries", min = 0, max = 1, weightChance = 10 },
            },
        },
        metal_shelves = {
            procList = {
                { name = "ISASolarBox", min = 0, max = 3, weightChance = 20 },
            },
        },
    }
})

----------------------------------------------------------------------------------------------------------------------
--- Insert items to item lists

--- Resolve one of the "proc:Name", "proc:Name.junk", "veh:Name" or "sub:a.b" references
--- above to the items list it names, or nil if the game no longer has that list.
---
--- Naming the lists rather than indexing them where the table is written matters: a
--- vanilla list that gets renamed between builds would otherwise take this whole file
--- down with it on load, and with it every distribution and the stash maps that read
--- ISA.Distributions afterwards.
---@param reference string
---@return table?
local function resolveItemList(reference)
    local kind, name = reference:match("^(%a+):(.+)$")
    if not kind then return nil end

    local table_
    if kind == "proc" then
        local listName = name:match("^([^.]+)%.junk$")
        if listName then
            table_ = pdList[listName] and pdList[listName].junk
        else
            table_ = pdList[name]
        end
    elseif kind == "veh" then
        table_ = vehDist[name]
    elseif kind == "sub" then
        table_ = subDist
        for part in name:gmatch("[^.]+") do
            table_ = table_ and table_[part]
        end
    end

    return table_ and table_.items or nil
end

--- Item lists are flat: name, weight, name, weight. Both halves of a pair go in
--- together or neither does, because a weight with no name in front of it shifts every
--- pair after it and quietly corrupts the vanilla table.
function ISA.Distributions.distributeItem(info)
    local multiplier = SandboxVars.ISA[info.LRM]
    if not info.fullType then
        print("ISA: distributeItem called with no fullType, skipped")
        return
    end
    for i = 1, #info.entries do
        local entry = info.entries[i]
        local items = resolveItemList(entry[2])
        if items then
            table.insert(items, info.fullType)
            table.insert(items, entry[1] * multiplier)
        else
            print("ISA: no loot list '" .. tostring(entry[2]) .. "' for " .. info.fullType .. ", skipped")
        end
    end
end

function ISA.Distributions.insertItemsToMultipleLists(distTable, targetNames, items)
    local itemsSize = #items
    for i = 1, #targetNames do
        local target = distTable[targetNames[i]]
        target = target ~= nil and target.items or nil
        if target ~= nil then
            for ii = 1, itemsSize do
                table.insert(target, items[ii])
            end
        end
    end
end

function ISA.Distributions.insertDistributions()

    ISA.Distributions.distributeItem({
        fullType = "ISA.ISAMag1",
        LRM = "LRMMisc",
        entries = {
            { 1.0, "proc:BookstoreBooks" },
            { 0.5, "proc:BookstoreMisc" },
            { 1.0, "proc:CrateMagazines" },
            { 2.0, "proc:ElectronicStoreMagazines" },
            { 0.2, "proc:EngineerTools" },
            { 0.8, "proc:LibraryBooks" },
            { 0.5, "proc:LivingRoomShelf" },
            { 0.5, "proc:LivingRoomShelfNoTapes" },
            { 0.6, "proc:MagazineRackMixed" },
            { 0.5, "proc:PostOfficeBooks" },
            { 0.8, "proc:PostOfficeMagazines" },
            { 0.2, "proc:ShelfGeneric" },
            { 1.0, "veh:ElectricianTruckBed" }
        },
    })

    ISA.Distributions.distributeItem({
        fullType = "ISA.SolarPanel",
        LRM = "LRMSolarPanels",
        entries = {
            { 0.05, "proc:ArmyHangarTools" },
            { 0.10, "proc:ArmyStorageElectronics" },
            { 0.05, "proc:CrateCarpentry" },
            { 0.10, "proc:CrateElectronics" },
            { 0.05, "proc:CrateFarming" },
            { 0.10, "proc:CrateMechanics" },
            { 0.05, "proc:CrateMetalwork" },
            { 0.10, "proc:CrateRandomJunk" },
            { 0.05, "proc:CrateTools" },
            { 0.10, "proc:ElectronicStoreAppliances" },
            { 0.15, "proc:ElectronicStoreMisc" },
            { 0.10, "proc:EngineerTools" },
            { 0.10, "proc:GarageMechanics" },
            { 0.05, "proc:GarageMetalwork" },
            { 0.05, "proc:GarageTools" },
            { 0.10, "proc:GigamartHouseElectronics" },
            { 0.05, "proc:GigamartFarming" },
            { 0.05, "proc:LoggingFactoryTools" },
            { 0.05, "proc:MechanicShelfElectric" },
            { 0.05, "proc:MechanicShelfMisc" },
            { 0.05, "proc:MetalShopTools" },
            { 0.20, "proc:StoreShelfElectronics" },
            { 0.10, "proc:ToolStoreFarming" },
            { 0.10, "proc:ToolStoreMetalwork" },
            { 0.15, "proc:ToolStoreMisc" },
            { 0.10, "proc:ToolStoreTools" },
            { 0.10, "proc:OtherGeneric" },
            { 0.01, "sub:all.metal_shelves" },
            { 1.00, "veh:ElectricianTruckBed" }
        },
    })

    ISA.Distributions.distributeItem({
        fullType = "ISA.DeepCycleBattery",
        LRM = "LRMBatteries",
        entries = {
            { 0.15, "proc:JanitorMisc" },
            { 0.15, "proc:StoreShelfElectronics" },
            { 0.15, "proc:MechanicShelfElectric" },
            { 0.20, "proc:StoreShelfMechanics" },
            { 0.15, "proc:CrateElectronics" },
            { 0.15, "proc:CrateMechanics" },
            { 0.15, "proc:ToolStoreTools" },
            { 0.20, "proc:ToolStoreMisc" },
            { 0.15, "proc:ArmyStorageElectronics" },
            { 0.15, "proc:ElectronicStoreMisc" },
            { 0.15, "proc:CrateRandomJunk" },
            { 0.15, "proc:CrateTools" },
            { 0.15, "proc:OtherGeneric" },
            { 0.15, "proc:GarageMechanics" },
            { 0.15, "proc:ToolStoreFarming" },
            { 0.03, "proc:CrateFarming" },
            { 0.03, "proc:CrateMetalwork" },
            { 0.01, "sub:all.metal_shelves" },
            { 1.00, "veh:ElectricianTruckBed" }
        },
    })

    ISA.Distributions.distributeItem({
        fullType = "ISA.SuperBattery",
        LRM = "LRMBatteries",
        entries = {
            { 0.05, "proc:JanitorMisc" },
            { 0.05, "proc:StoreShelfElectronics" },
            { 0.05, "proc:MechanicShelfElectric" },
            { 0.10, "proc:StoreShelfMechanics" },
            { 0.05, "proc:CrateElectronics" },
            { 0.05, "proc:CrateMechanics" },
            { 0.05, "proc:ToolStoreTools" },
            { 0.10, "proc:ToolStoreMisc" },
            { 0.20, "proc:ArmyStorageElectronics" },
            { 0.05, "proc:ElectronicStoreMisc" },
            { 0.05, "proc:CrateRandomJunk" },
            { 0.05, "proc:CrateTools" },
            { 0.05, "proc:OtherGeneric" },
            { 0.05, "proc:GarageMechanics" },
            { 0.05, "proc:ToolStoreFarming" },
            { 0.05, "proc:CrateFarming" },
            { 0.05, "proc:CrateMetalwork" },
            { 0.01, "sub:all.metal_shelves" },
            { 0.40, "veh:ElectricianTruckBed" }
        },
    })

    ISA.Distributions.distributeItem({
        fullType = "ISA.ISAInverter",
        LRM = "LRMMisc",
        entries = {
            { 0.10, "proc:StoreShelfElectronics" },
            { 0.10, "proc:StoreShelfMechanics" },
            { 0.10, "proc:CrateElectronics" },
            { 0.10, "proc:CrateMechanics" },
            { 0.10, "proc:MechanicShelfMisc" },
            { 0.10, "proc:MechanicShelfElectric" },
            { 0.10, "proc:ToolStoreMisc" },
            { 0.10, "proc:ToolStoreTools" },
            { 0.10, "proc:GigamartHouseElectronics" },
            { 0.10, "proc:ArmyStorageElectronics" },
            { 0.10, "proc:ElectronicStoreMisc" },
            { 0.10, "proc:CrateRandomJunk" },
            { 0.10, "proc:CrateTools" },
            { 0.10, "proc:OtherGeneric" },
            { 0.10, "proc:GarageMechanics" },
            { 0.10, "proc:ElectronicStoreAppliances" },
            { 0.10, "proc:ToolStoreFarming" },
            { 0.03, "proc:CrateFarming" },
            { 0.03, "proc:CrateMetalwork" },
            { 0.01, "sub:all.metal_shelves" },
            { 0.60, "veh:ElectricianTruckBed" }
        },
    })

    ISA.Distributions.distributeItem({
        fullType = "ISA.SolarFailsafe",
        LRM = "LRMMisc",
        entries = {
            { 0.01, "proc:CrateElectronics.junk" },
            { 0.01, "proc:GigamartHouseElectronics.junk" },
            { 0.01, "proc:ArmyStorageElectronics.junk" },
            { 0.01, "proc:ElectronicStoreMisc.junk" },
            { 0.01, "veh:ElectricianTruckBed" }
        },
    })

    ---TODO after debugging sandbox options load
    -- ISA.Distributions = nil
end

--- remake distributions based on sandbox, used by stash items
local function OnLoadedMapZones()
    if ItemPickerJava.doParse then
        ItemPickerJava.doParse = nil
        ItemPickerJava.Parse()
    end
    ISA.distributions = nil
    ISA.Distributions = nil
end

ISA.Distributions.insertDistributions()
Events.OnLoadedMapZones.Add(OnLoadedMapZones)
