local ESX = exports['es_extended']:getSharedObject()
local Peds = {}
local Blips = {}
local Garages = {}

-- Načtení a synchronizace garáží
RegisterNetEvent('lgrs_garage:syncGarages')
AddEventHandler('lgrs_garage:syncGarages', function(garagesData)
    Garages = garagesData
    RefreshGarages()
end)

CreateThread(function()
    ESX.TriggerServerCallback('lgrs_garage:getGarages', function(garagesData)
        Garages = garagesData
        RefreshGarages()
    end)
end)

-- Odstranění starých entit a blipů při restartu/obnově
function CleanupGarages()
    for _, ped in ipairs(Peds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    Peds = {}

    for _, blip in ipairs(Blips) do
        RemoveBlip(blip)
    end
    Blips = {}
end

-- Vytvoření NPC a Targetů s 0.00ms idle
function RefreshGarages()
    CleanupGarages()

    for id, data in pairs(Garages) do
        -- 1. Blip
        local blipCfg = data.type == 'impound' and Config.Blips.Impound or Config.Blips.Garage
        local blip = AddBlipForCoord(data.npc.x, data.npc.y, data.npc.z)
        SetBlipSprite(blip, blipCfg.Sprite)
        SetBlipColour(blip, blipCfg.Color)
        SetBlipScale(blip, blipCfg.Scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(data.name)
        EndTextCommandSetBlipName(blip)
        table.insert(Blips, blip)

        -- 2. Načtení ped modelu
        local model = data.type == 'impound' and Config.ImpoundPedModel or Config.GaragePedModel
        lib.requestModel(model)

        -- 3. Vytvoření Peda (Local)
        local ped = CreatePed(4, joaat(model), data.npc.x, data.npc.y, data.npc.z - 1.0, data.npc.w, false, false)
        SetEntityHeading(ped, data.npc.w)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        table.insert(Peds, ped)

        -- 4. ox_target integrace
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'garage_interact_'..id,
                icon = data.type == 'impound' and 'fas fa-truck-pickup' or 'fas fa-warehouse',
                label = data.type == 'impound' and Config.Locale.impound_menu_title or Config.Locale.garage_menu_title,
                onSelect = function()
                    if data.type == 'impound' then
                        OpenImpoundMenu(id, data)
                    else
                        OpenGarageRootMenu(id, data)
                    end
                end
            }
        })
    end
end

-- =======================================
-- GARÁŽOVÝ SYSTÉM
-- =======================================

CreateThread(function()
    exports.ox_target:addGlobalVehicle({
        {
            name = 'lgrs_garage:store_vehicle',
            icon = 'fas fa-square-parking',
            label = Config.Locale.store_vehicle,
            canInteract = function(entity, distance, coords, name, bone)
                if distance > 3.0 then return false end
                
                local vehCoords = GetEntityCoords(entity)
                for id, data in pairs(Garages) do
                    if data.type == 'garage' then
                        local dist = #(vehCoords - vec3(data.npc.x, data.npc.y, data.npc.z))
                        if dist < 20.0 then
                            return true
                        end
                    end
                end
                return false
            end,
            onSelect = function(data)
                local vehicle = data.entity
                local vehCoords = GetEntityCoords(vehicle)
                local closestGarageId = nil
                local minDistance = 20.0
                
                for id, gData in pairs(Garages) do
                    if gData.type == 'garage' then
                        local dist = #(vehCoords - vec3(gData.npc.x, gData.npc.y, gData.npc.z))
                        if dist < minDistance then
                            minDistance = dist
                            closestGarageId = id
                        end
                    end
                end

                if closestGarageId then
                    local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
                    StoreVehicle(vehicle, plate, closestGarageId)
                end
            end
        }
    })
end)

function OpenGarageRootMenu(garageId, garageData)
    local options = {
        {
            title = Config.Locale.personal_garage,
            icon = 'user',
            onSelect = function()
                OpenGarageMenu(garageId, garageData, false)
            end
        }
    }

    if ESX.PlayerData.job and ESX.PlayerData.job.name ~= 'unemployed' then
        table.insert(options, {
            title = Config.Locale.faction_garage,
            icon = 'building',
            onSelect = function()
                OpenGarageMenu(garageId, garageData, true)
            end
        })
    end

    lib.registerContext({
        id = 'garage_root_menu',
        title = Config.Locale.garage_type_selection,
        options = options
    })
    lib.showContext('garage_root_menu')
end

function OpenGarageMenu(garageId, garageData, isFaction)
    local callbackName = isFaction and 'lgrs_garage:getFactionVehicles' or 'lgrs_garage:getVehicles'
    ESX.TriggerServerCallback(callbackName, function(vehicles)
        if #vehicles == 0 then
            lib.notify({title = Config.Locale.no_vehicles, type = 'error'})
            return
        end

        local options = {}
        for i=1, #vehicles do
            local veh = vehicles[i]
            local props = type(veh.vehicle) == 'string' and json.decode(veh.vehicle) or veh.vehicle
            local isStored = (veh.stored == 1 or veh.stored == true)
            local inThisGarage = (tostring(veh.parking) == tostring(garageId))
            
            local vehName = GetLabelText(GetDisplayNameFromVehicleModel(props.model))
            if vehName == 'NULL' then vehName = 'Vozidlo' end
            if veh.nickname and veh.nickname ~= '' then vehName = veh.nickname .. ' (' .. vehName .. ')' end

            local desc = 'SPZ: ' .. veh.plate .. '\n'
            local icon = 'car'

            if isStored then
                if inThisGarage then
                    desc = desc .. Config.Locale.vehicle_stored
                else
                    local otherGarageName = Garages[veh.parking] and Garages[veh.parking].name or 'Neznámá garáž'
                    desc = desc .. string.format(Config.Locale.vehicle_in_other, otherGarageName)
                    icon = 'truck-fast'
                end
            else
                desc = desc .. Config.Locale.vehicle_out
            end

            local metadata = {
                {label = 'Motor', value = math.floor((props.engineHealth or 1000) / 10) .. '%'},
                {label = 'Palivo', value = math.floor(props.fuelLevel or 100) .. '%'}
            }

            table.insert(options, {
                title = vehName,
                description = desc,
                metadata = metadata,
                icon = icon,
                onSelect = function()
                    OpenVehicleSubMenu(veh, props, isStored, inThisGarage, garageId, garageData, isFaction)
                end
            })
        end

        lib.registerContext({
            id = 'garage_vehicle_list',
            title = garageData.name,
            options = options
        })
        lib.showContext('garage_vehicle_list')
    end, garageId)
end

function OpenVehicleSubMenu(veh, props, isStored, inThisGarage, garageId, garageData, isFaction)
    local options = {}

    if isStored and inThisGarage then
        table.insert(options, {
            title = Config.Locale.retrieve_vehicle,
            icon = 'key',
            description = 'Vytáhne vozidlo z garáže',
            onSelect = function()
                SpawnVehicle(veh.plate, garageData.spawn)
            end
        })
    elseif isStored and not inThisGarage then
        table.insert(options, {
            title = string.format(Config.Locale.transfer_vehicle, Config.TransferPrice),
            icon = 'money-bill',
            description = 'Přesunout sem z jiné garáže',
            onSelect = function()
                ESX.TriggerServerCallback('lgrs_garage:transferVehicle', function(success, errorMsg)
                    if success then
                        lib.notify({title = 'Úspěch', description = Config.Locale.transfer_success, type = 'success'})
                        OpenGarageMenu(garageId, garageData, isFaction)
                    else
                        lib.notify({title = 'Chyba', description = errorMsg or Config.Locale.transfer_no_money, type = 'error'})
                    end
                end, veh.plate, garageId)
            end
        })
    end

    if not isFaction then
        -- Přejmenovat
        table.insert(options, {
            title = 'Přejmenovat vozidlo',
            icon = 'pen',
            onSelect = function()
                local input = lib.inputDialog('Nové jméno vozidla', {
                    {type = 'input', label = 'Zadej název', required = true}
                })
                if not input then return OpenGarageMenu(garageId, garageData, isFaction) end
                
                ESX.TriggerServerCallback('lgrs_garage:renameVehicle', function(success, errorMsg)
                    if success then
                        lib.notify({title = 'Úspěch', description = 'Vozidlo přejmenováno.', type = 'success'})
                        OpenGarageMenu(garageId, garageData, isFaction)
                    else
                        lib.notify({title = 'Chyba', description = errorMsg, type = 'error'})
                    end
                end, veh.plate, input[1])
            end
        })

        -- Přepsat vozidlo
        table.insert(options, {
            title = 'Přepsat vozidlo (Darovat)',
            icon = 'hand-holding-hand',
            onSelect = function()
                local input = lib.inputDialog('Přepsat vozidlo', {
                    {type = 'number', label = 'ID Hráče (ve hře)', required = true}
                })
                if not input then return OpenGarageMenu(garageId, garageData, isFaction) end
                
                ESX.TriggerServerCallback('lgrs_garage:transferOwnership', function(success, errorMsg)
                    if success then
                        lib.notify({title = 'Úspěch', description = 'Vozidlo úspěšně přepsáno.', type = 'success'})
                        OpenGarageMenu(garageId, garageData, isFaction)
                    else
                        lib.notify({title = 'Chyba', description = errorMsg, type = 'error'})
                    end
                end, veh.plate, input[1])
            end
        })
    end

    -- Locksmith (Vyrobit nové klíče)
    table.insert(options, {
        title = 'Vyrobit nové klíče ($'..(Config.LocksmithPrice or 500)..')',
        icon = 'key',
        onSelect = function()
            ESX.TriggerServerCallback('lgrs_garage:buyKeys', function(success, errorMsg)
                if success then
                    lib.notify({title = 'Úspěch', description = 'Klíče od vozidla '..veh.plate..' vyhotoveny.', type = 'success'})
                else
                    lib.notify({title = 'Chyba', description = errorMsg, type = 'error'})
                end
                OpenGarageMenu(garageId, garageData, isFaction)
            end, veh.plate)
        end
    })

    lib.registerContext({
        id = 'garage_vehicle_actions_' .. veh.plate,
        title = 'Akce: ' .. veh.plate,
        menu = 'garage_vehicle_list',
        options = options
    })
    lib.showContext('garage_vehicle_actions_' .. veh.plate)
end

function StoreVehicle(vehicle, plate, garageId)
    local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)

    -- Přidání detailního poškození (pro jistotu, kdyby ESX Game Properties nepobralo úplně všechno ideálně)
    vehicleProps.engineHealth = GetVehicleEngineHealth(vehicle)
    vehicleProps.bodyHealth = GetVehicleBodyHealth(vehicle)
    vehicleProps.fuelLevel = GetVehicleFuelLevel(vehicle)
    vehicleProps.dirtLevel = GetVehicleDirtLevel(vehicle)
    
    ESX.TriggerServerCallback('lgrs_garage:storeVehicle', function(success, msg)
        if success then
            -- Úspěšné smazání entity z klienta
            ESX.Game.DeleteVehicle(vehicle)
            lib.notify({title = 'Úspěch', description = msg, type = 'success'})
        else
            lib.notify({title = 'Chyba', description = msg, type = 'error'})
        end
    end, plate, vehicleProps, garageId)
end

function SpawnVehicle(plate, spawnCoords)
    -- Bezpečnostní kontrola, zda je místo prázdné
    if not ESX.Game.IsSpawnPointClear(vec3(spawnCoords.x, spawnCoords.y, spawnCoords.z), 3.0) then
        lib.notify({title = 'Chyba', description = Config.Locale.spawn_blocked, type = 'error'})
        return
    end

    ESX.TriggerServerCallback('lgrs_garage:spawnVehicle', function(success, vehicleProps)
        if success and vehicleProps then
            ESX.Game.SpawnVehicle(vehicleProps.model, spawnCoords, spawnCoords.w, function(vehicle)
                ESX.Game.SetVehicleProperties(vehicle, vehicleProps)
                SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
                
                -- Dodatečné explicitní nastavení poškození po setnutí properties
                if vehicleProps.engineHealth then SetVehicleEngineHealth(vehicle, vehicleProps.engineHealth + 0.0) end
                if vehicleProps.bodyHealth then SetVehicleBodyHealth(vehicle, vehicleProps.bodyHealth + 0.0) end
                if vehicleProps.fuelLevel then SetVehicleFuelLevel(vehicle, vehicleProps.fuelLevel + 0.0) end
                if vehicleProps.dirtLevel then SetVehicleDirtLevel(vehicle, vehicleProps.dirtLevel + 0.0) end
                
                -- Opětovné zapnutí zničených dveří a oken pokud SetVehicleProperties selže
                if vehicleProps.doorsBroken then
                    for k, v in pairs(vehicleProps.doorsBroken) do
                        if v then SetVehicleDoorBroken(vehicle, tonumber(k), true) end
                    end
                end
                if vehicleProps.windowsBroken then
                    for k, v in pairs(vehicleProps.windowsBroken) do
                        if not v then SmashVehicleWindow(vehicle, tonumber(k)) end
                    end
                end
                if vehicleProps.burstTires then
                    for k, v in pairs(vehicleProps.burstTires) do
                        if v then SetVehicleTyreBurst(vehicle, tonumber(k), true, 1000.0) end
                    end
                end

                lib.notify({title = 'Úspěch', description = Config.Locale.spawn_success, type = 'success'})
            end)
        else
            lib.notify({title = 'Chyba', description = 'Vozidlo nebylo možné vytáhnout.', type = 'error'})
        end
    end, plate)
end


-- =======================================
-- ODTAHOVKA (IMPOUND)
-- =======================================
function OpenImpoundMenu(impoundId, impoundData)
    ESX.TriggerServerCallback('lgrs_garage:getImpoundVehicles', function(vehicles)
        if #vehicles == 0 then
            lib.notify({title = Config.Locale.no_impound_vehicles, type = 'error'})
            return
        end

        local options = {}
        for i=1, #vehicles do
            local veh = vehicles[i]
            local props = type(veh.vehicle) == 'string' and json.decode(veh.vehicle) or veh.vehicle
            local vehName = GetLabelText(GetDisplayNameFromVehicleModel(props.model))
            if vehName == 'NULL' then vehName = 'Vozidlo' end

            table.insert(options, {
                title = vehName,
                description = 'SPZ: ' .. veh.plate,
                icon = 'truck-pickup',
                onSelect = function()
                    PayAndSpawnImpound(veh.plate, impoundId, impoundData.spawn)
                end
            })
        end

        lib.registerContext({
            id = 'impound_vehicle_list',
            title = impoundData.name .. ' (Poplatek: $'..Config.ImpoundPrice..')',
            options = options
        })
        lib.showContext('impound_vehicle_list')
    end)
end

function PayAndSpawnImpound(plate, impoundId, spawnCoords)
    if not ESX.Game.IsSpawnPointClear(vec3(spawnCoords.x, spawnCoords.y, spawnCoords.z), 3.0) then
        lib.notify({title = 'Chyba', description = Config.Locale.spawn_blocked, type = 'error'})
        return
    end

    ESX.TriggerServerCallback('lgrs_garage:payImpound', function(success, vehicleProps)
        if success and vehicleProps then
            ESX.Game.SpawnVehicle(vehicleProps.model, spawnCoords, spawnCoords.w, function(vehicle)
                ESX.Game.SetVehicleProperties(vehicle, vehicleProps)
                SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
                
                -- Aplikace poškození (stejně jako v garáži)
                if vehicleProps.engineHealth then SetVehicleEngineHealth(vehicle, vehicleProps.engineHealth + 0.0) end
                if vehicleProps.bodyHealth then SetVehicleBodyHealth(vehicle, vehicleProps.bodyHealth + 0.0) end
                
                lib.notify({title = 'Úspěch', description = string.format(Config.Locale.impound_success, Config.ImpoundPrice), type = 'success'})
            end)
        else
            lib.notify({title = 'Chyba', description = Config.Locale.no_money, type = 'error'})
        end
    end, plate, impoundId)
end


-- =======================================
-- ADMIN MENU (/garageedit)
-- =======================================
RegisterNetEvent('lgrs_garage:adminMenu')
AddEventHandler('lgrs_garage:adminMenu', function()
    lib.registerContext({
        id = 'garage_admin_main',
        title = Config.Locale.admin_menu_title,
        options = {
            {
                title = Config.Locale.admin_create_garage,
                icon = 'plus',
                onSelect = function()
                    StartGarageCreation('garage')
                end
            },
            {
                title = Config.Locale.admin_create_impound,
                icon = 'plus-circle',
                onSelect = function()
                    StartGarageCreation('impound')
                end
            },
            {
                title = Config.Locale.admin_manage,
                icon = 'list',
                onSelect = function()
                    OpenManageGaragesMenu()
                end
            }
        }
    })
    lib.showContext('garage_admin_main')
end)

function StartGarageCreation(type)
    local title = type == 'garage' and 'Vytvořit Garáž' or 'Vytvořit Odtahovku'
    local input = lib.inputDialog(title, {
        {type = 'input', label = Config.Locale.admin_garage_name, required = true}
    })
    
    if not input then return end
    local name = input[1]

    CreateThread(function()
        -- Krok 1: NPC
        lib.showTextUI('[E] - Potvrdit pozici NPC\nStoupni si přesně tam, kam chceš umístit NPC.', {
            position = "top-center",
            icon = 'location-dot',
            style = {
                borderRadius = 5,
                backgroundColor = '#1e1e24',
                color = 'white'
            }
        })

        -- Čekání na stisk tlačítka E (38)
        while not IsControlJustReleased(0, 38) do
            Wait(0)
        end
        lib.hideTextUI()

        local playerPed = PlayerPedId()
        local npcCoords = GetEntityCoords(playerPed)
        local npcHeading = GetEntityHeading(playerPed)
        local npcVector = vector4(npcCoords.x, npcCoords.y, npcCoords.z, npcHeading)

        -- Malá pauza proti double-clicku
        Wait(500)

        -- Krok 2: Spawn
        lib.showTextUI('[E] - Potvrdit pozici pro vozidla\nStoupni si tam, kde se budou spawnovat vozidla.', {
            position = "top-center",
            icon = 'car',
            style = {
                borderRadius = 5,
                backgroundColor = '#1e1e24',
                color = 'white'
            }
        })

        -- Čekání na stisk tlačítka E (38)
        while not IsControlJustReleased(0, 38) do
            Wait(0)
        end
        lib.hideTextUI()

        local spawnCoords = GetEntityCoords(playerPed)
        local spawnHeading = GetEntityHeading(playerPed)
        local spawnVector = vector4(spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnHeading)
        
        TriggerServerEvent('lgrs_garage:createGarage', {
            name = name,
            type = type,
            npc = npcVector,
            spawn = spawnVector
        })
        lib.notify({title = 'Úspěch', description = 'Garáž byla úspěšně vytvořena.', type = 'success'})
    end)
end

function OpenManageGaragesMenu()
    local options = {}
    for id, data in pairs(Garages) do
        table.insert(options, {
            title = data.name .. ' (' .. data.type .. ')',
            description = 'ID: ' .. id,
            icon = 'warehouse',
            onSelect = function()
                lib.registerContext({
                    id = 'garage_admin_manage_'..id,
                    title = data.name,
                    menu = 'garage_admin_main',
                    options = {
                        {
                            title = Config.Locale.admin_delete,
                            icon = 'trash',
                            onSelect = function()
                                TriggerServerEvent('lgrs_garage:deleteGarage', id)
                            end
                        }
                    }
                })
                lib.showContext('garage_admin_manage_'..id)
            end
        })
    end

    if #options == 0 then
        lib.notify({title = 'Žádné garáže nenalezeny', type = 'error'})
        return
    end

    lib.registerContext({
        id = 'garage_admin_list',
        title = 'Správa Garáží',
        menu = 'garage_admin_main',
        options = options
    })
    lib.showContext('garage_admin_list')
end

-- Úklid při zastavení resourcu
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        CleanupGarages()
    end
end)

-- Admin příkaz pro darování vozidla
RegisterNetEvent('lgrs_garage:giveCarMenu')
AddEventHandler('lgrs_garage:giveCarMenu', function()
    local garageOptions = {}
    -- Umožníme dát auto i ven (neuložené v žádné garáži)
    table.insert(garageOptions, { value = 'none', label = 'Neukládat do garáže (nechat venku)' })
    
    for id, data in pairs(Garages) do
        table.insert(garageOptions, { value = id, label = data.name .. ' (ID: ' .. id .. ')' })
    end

    local input = lib.inputDialog('Darovat Vozidlo', {
        {type = 'number', label = 'ID Hráče', required = true},
        {type = 'input', label = 'Model Vozidla (např. t20)', required = true},
        {type = 'input', label = 'SPZ (nepovinné, vygeneruje se)'},
        {type = 'select', label = 'Garáž', options = garageOptions, default = 'none'}
    })

    if not input then return end

    local targetId = input[1]
    local model = input[2]
    local plate = input[3]
    local garage = input[4]
    
    if garage == 'none' then garage = nil end

    TriggerServerEvent('lgrs_garage:giveCar', targetId, model, plate, garage)
end)

RegisterNetEvent('lgrs_garage:useKeys')
AddEventHandler('lgrs_garage:useKeys', function(plate)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local vehicles = GetGamePool('CVehicle')
    local foundVeh = nil

    for i=1, #vehicles do
        local veh = vehicles[i]
        local vehPlate = ESX.Math.Trim(GetVehicleNumberPlateText(veh))
        if vehPlate == ESX.Math.Trim(plate) then
            local dist = #(coords - GetEntityCoords(veh))
            if dist <= 20.0 then
                foundVeh = veh
                break
            end
        end
    end

    if foundVeh then
        local lockStatus = GetVehicleDoorLockStatus(foundVeh)
        
        -- Přehrání animace klíčku
        lib.requestAnimDict('anim@mp_player_intmenu@key_fob@')
        TaskPlayAnim(playerPed, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 8.0, 8.0, -1, 48, 1, false, false, false)

        if lockStatus == 1 or lockStatus == 0 then
            -- Zamknout (status 2 = locked)
            SetVehicleDoorsLocked(foundVeh, 2)
            lib.notify({title = 'Vozidlo', description = 'Vozidlo s SPZ '..plate..' bylo zamčeno.', type = 'success', icon = 'lock'})
            ExecuteCommand("me zamknul auto")
        else
            -- Odemknout (status 1 = unlocked)
            SetVehicleDoorsLocked(foundVeh, 1)
            lib.notify({title = 'Vozidlo', description = 'Vozidlo s SPZ '..plate..' bylo odemčeno.', type = 'success', icon = 'lock-open'})
            ExecuteCommand("me odemknul auto")
        end

        -- Bliknutí a zatroubení
        SetVehicleLights(foundVeh, 2)
        StartVehicleHorn(foundVeh, 50, "HELDDOWN", false)
        Wait(200)
        SetVehicleLights(foundVeh, 0)
        Wait(200)
        SetVehicleLights(foundVeh, 2)
        StartVehicleHorn(foundVeh, 50, "HELDDOWN", false)
        Wait(200)
        SetVehicleLights(foundVeh, 0)
    else
        lib.notify({title = 'Chyba', description = 'Vozidlo (SPZ: '..plate..') není v dosahu.', type = 'error'})
    end
end)
