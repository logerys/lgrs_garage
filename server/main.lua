local ESX = exports['es_extended']:getSharedObject()
local Garages = {}

-- Načtení garáží z databáze při startu
MySQL.ready(function()
    LoadGarages()
end)

function LoadGarages()
    Garages = {}
    local result = MySQL.query.await('SELECT * FROM garage_locations')
    if result then
        for i=1, #result do
            local row = result[i]
            Garages[row.id] = {
                id = row.id,
                name = row.name,
                type = row.type,
                npc = vector4(row.npc_x, row.npc_y, row.npc_z, row.npc_w),
                spawn = vector4(row.spawn_x, row.spawn_y, row.spawn_z, row.spawn_w)
            }
        end
    end
    print('[^2lgrs_garage^7] Loaded ' .. #result .. ' garages from database.')
end

-- Odeslání dat garáží nově připojenému hráči
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    TriggerClientEvent('lgrs_garage:syncGarages', playerId, Garages)
end)

-- Možnost vyžádat garáže ze strany klienta
ESX.RegisterServerCallback('lgrs_garage:getGarages', function(source, cb)
    cb(Garages)
end)

-- Získání všech vozidel (pro možnost převozu z jiných garáží)
ESX.RegisterServerCallback('lgrs_garage:getVehicles', function(source, cb, garageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end

    MySQL.query('SELECT plate, vehicle, stored, parking, nickname FROM owned_vehicles WHERE owner = ?', {xPlayer.identifier}, function(result)
        cb(result)
    end)
end)

ESX.RegisterServerCallback('lgrs_garage:getFactionVehicles', function(source, cb, garageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name == 'unemployed' then return cb({}) end

    MySQL.query('SELECT plate, vehicle, stored, parking, nickname FROM owned_vehicles WHERE owner = ?', {xPlayer.job.name}, function(result)
        cb(result)
    end)
end)

-- Zaplacení a převoz vozidla do aktuální garáže
ESX.RegisterServerCallback('lgrs_garage:transferVehicle', function(source, cb, plate, newGarageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end

    if xPlayer.getMoney() >= Config.TransferPrice then
        -- Aktualizace lokace v DB
        MySQL.update('UPDATE owned_vehicles SET parking = ? WHERE plate = ?', {newGarageId, plate}, function(rows)
            -- MySQL returns 0 rows affected if the value was already the same. We will still consider it successful or notify differently, but here if rows > 0 we deduct money.
            if rows > 0 then
                xPlayer.removeMoney(Config.TransferPrice)
                cb(true)
            else
                cb(false, "Převoz selhal, auto nebylo nalezeno nebo už tam je.")
            end
        end)
    else
        cb(false, Config.Locale.transfer_no_money)
    end
end)

-- Získání vozidel pro odtahovku (všechny co nejsou uložené)
ESX.RegisterServerCallback('lgrs_garage:getImpoundVehicles', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end

    MySQL.query('SELECT plate, vehicle, parking FROM owned_vehicles WHERE (owner = ? OR owner = ?) AND stored = 0', {xPlayer.identifier, xPlayer.job.name}, function(result)
        cb(result)
    end)
end)

-- Zaparkování vozidla
ESX.RegisterServerCallback('lgrs_garage:storeVehicle', function(source, cb, plate, vehicleProps, garageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false, Config.Locale.not_owner) end

    -- Check if player has keys in ox_inventory
    local count = exports.ox_inventory:Search(source, 'count', 'carkeys', { plate = plate })
    if count < 1 then
        return cb(false, "Nemáš klíče od tohoto vozidla! Nech si vyrobit nové u zámečníka.")
    end

    -- Ověření majitele
    MySQL.query('SELECT owner FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        if result[1] and (result[1].owner == xPlayer.identifier or result[1].owner == xPlayer.job.name) then
            -- Uložení vozidla a aktualizace JSON s kompletním poškozením (vehicleProps)
            MySQL.update('UPDATE owned_vehicles SET stored = 1, parking = ?, vehicle = ? WHERE plate = ?', {
                garageId, json.encode(vehicleProps), plate
            }, function(affectedRows)
                if affectedRows > 0 then
                    -- Remove keys from inventory with exact metadata
                    local meta = {
                        plate = plate,
                        description = "Klíče od vozidla (SPZ: " .. plate .. ")"
                    }
                    exports.ox_inventory:RemoveItem(source, 'carkeys', 1, meta)
                    cb(true, Config.Locale.store_success)
                else
                    cb(false, "Chyba při ukládání vozidla do DB.")
                end
            end)
        else
            cb(false, Config.Locale.not_owner)
        end
    end)
end)

-- Vyzvednutí vozidla
ESX.RegisterServerCallback('lgrs_garage:spawnVehicle', function(source, cb, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end

    -- Bezpečnostní kontrola, abychom zabránili duplikaci (zda je opravdu uložené)
    MySQL.query('SELECT stored, vehicle FROM owned_vehicles WHERE plate = ? AND (owner = ? OR owner = ?)', {plate, xPlayer.identifier, xPlayer.job.name}, function(result)
        if result[1] and result[1].stored == 1 then
            -- Změníme status na 0 (vytaženo) předtím, než ho reálně spawne klient
            MySQL.update('UPDATE owned_vehicles SET stored = 0 WHERE plate = ?', {plate}, function(rows)
                if rows > 0 then
                    -- Give keys
                    local meta = {
                        plate = plate,
                        description = "Klíče od vozidla (SPZ: " .. plate .. ")"
                    }
                    exports.ox_inventory:AddItem(source, 'carkeys', 1, meta)
                    cb(true, json.decode(result[1].vehicle))
                else
                    cb(false)
                end
            end)
        else
            cb(false)
        end
    end)
end)

-- Platba a vyzvednutí z odtahovky
ESX.RegisterServerCallback('lgrs_garage:payImpound', function(source, cb, plate, garageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end

    if xPlayer.getMoney() >= Config.ImpoundPrice then
        xPlayer.removeMoney(Config.ImpoundPrice)
        
        -- Nastavíme vozidlo jako uložené v nějaké garáži (nebo ho necháme přesunout rovnou)
        -- Aby to bylo co nejednodušší, po zaplacení rovnou dovolíme spawn.
        MySQL.update('UPDATE owned_vehicles SET stored = 0 WHERE plate = ?', {plate}, function(rows)
            if rows > 0 then
                MySQL.query('SELECT vehicle FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
                    if result[1] then
                        -- Give keys
                        local meta = {
                            plate = plate,
                            description = "Klíče od vozidla (SPZ: " .. plate .. ")"
                        }
                        exports.ox_inventory:AddItem(source, 'carkeys', 1, meta)
                        cb(true, json.decode(result[1].vehicle))
                    else
                        cb(false)
                    end
                end)
            else
                cb(false)
            end
        end)
    else
        cb(false, Config.Locale.no_money)
    end
end)


-- =======================================
-- ADMIN PŘÍKAZY (/garageedit, /admincar)
-- =======================================
ESX.RegisterCommand('garageedit', 'admin', function(xPlayer, args, showError)
    TriggerClientEvent('lgrs_garage:adminMenu', xPlayer.source)
end, true, {help = 'Otevře administrátorské menu pro tvorbu a úpravu garáží a odtahovek.'})

ESX.RegisterCommand('givecar', 'admin', function(xPlayer, args, showError)
    TriggerClientEvent('lgrs_garage:giveCarMenu', xPlayer.source)
end, true, {help = 'Otevře menu pro darování vozidla hráči.'})

-- Funkce pro generování náhodné SPZ
local function GeneratePlate()
    local letters = string.char(math.random(65, 90), math.random(65, 90), math.random(65, 90))
    local numbers = string.format("%03d", math.random(0, 999))
    return letters .. " " .. numbers
end

RegisterNetEvent('lgrs_garage:giveCar')
AddEventHandler('lgrs_garage:giveCar', function(targetId, model, plate, garageId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not Config.AdminGroups[xPlayer.getGroup()] then return end

    local tPlayer = ESX.GetPlayerFromId(targetId)
    if not tPlayer then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Chyba', description = 'Zadaný hráč není online.', type = 'error'})
        return
    end

    if not plate or plate == '' then
        plate = GeneratePlate()
    else
        plate = string.upper(plate)
    end
    plate = string.sub(plate, 1, 8) -- Oříznutí na max 8 znaků (limit FiveM SPZ)

    -- Základní properties, aby auto fungovalo (zbytek se doplní při spawnu nebo přes tuning)
    local vehicleProps = {
        model = joaat(model),
        plate = plate
    }

    local stored = garageId and 1 or 0
    local parking = garageId or nil

    MySQL.query('SELECT owner FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        if result[1] then
            TriggerClientEvent('ox_lib:notify', src, {title = 'Chyba', description = 'Vozidlo s touto SPZ ('..plate..') už někomu patří!', type = 'error'})
        else
            MySQL.insert('INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored, parking) VALUES (?, ?, ?, ?, ?, ?)', {
                tPlayer.identifier, plate, json.encode(vehicleProps), 'car', stored, parking
            }, function(id)
                TriggerClientEvent('ox_lib:notify', src, {title = 'Úspěch', description = 'Vozidlo (SPZ: '..plate..') bylo úspěšně darováno.', type = 'success'})
                TriggerClientEvent('ox_lib:notify', tPlayer.source, {title = 'Nové Vozidlo', description = 'Dostal jsi vozidlo s SPZ '..plate, type = 'success'})
            end)
        end
    end)
end)

RegisterNetEvent('lgrs_garage:createGarage')
AddEventHandler('lgrs_garage:createGarage', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not Config.AdminGroups[xPlayer.getGroup()] then return end

    MySQL.insert('INSERT INTO garage_locations (name, type, npc_x, npc_y, npc_z, npc_w, spawn_x, spawn_y, spawn_z, spawn_w) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        data.name, data.type, 
        data.npc.x, data.npc.y, data.npc.z, data.npc.w,
        data.spawn.x, data.spawn.y, data.spawn.z, data.spawn.w
    }, function(id)
        if id then
            LoadGarages()
            TriggerClientEvent('ox_lib:notify', src, {title = 'Garáž Vytvořena', description = 'Garáž '..data.name..' byla úspěšně přidána.', type = 'success'})
            TriggerClientEvent('lgrs_garage:syncGarages', -1, Garages)
        end
    end)
end)

RegisterNetEvent('lgrs_garage:deleteGarage')
AddEventHandler('lgrs_garage:deleteGarage', function(garageId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not Config.AdminGroups[xPlayer.getGroup()] then return end

    MySQL.update('DELETE FROM garage_locations WHERE id = ?', {garageId}, function(affectedRows)
        if affectedRows > 0 then
            LoadGarages()
            TriggerClientEvent('ox_lib:notify', src, {title = 'Garáž Smazána', type = 'success'})
            TriggerClientEvent('lgrs_garage:syncGarages', -1, Garages)
        end
    end)
end)

-- =======================================
-- NOVÉ FUNKCE: Rename, Transfer Ownership, Locksmith
-- =======================================

ESX.RegisterServerCallback('lgrs_garage:renameVehicle', function(source, cb, plate, newName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end

    -- Verify ownership
    MySQL.query('SELECT owner FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        if result[1] then
            local isOwner = (result[1].owner == xPlayer.identifier)
            local isFactionBoss = (result[1].owner == xPlayer.job.name and xPlayer.job.grade_name == 'boss')

            if isOwner or isFactionBoss then
                MySQL.update('UPDATE owned_vehicles SET nickname = ? WHERE plate = ?', {newName, plate}, function(rows)
                    if rows > 0 then
                        cb(true)
                    else
                        cb(false, "Nepodařilo se přejmenovat vozidlo.")
                    end
                end)
            else
                cb(false, Config.Locale.not_owner)
            end
        else
            cb(false, Config.Locale.not_owner)
        end
    end)
end)

ESX.RegisterServerCallback('lgrs_garage:transferToFaction', function(source, cb, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end

    if xPlayer.job.grade_name ~= 'boss' then
        return cb(false, "Pouze boss frakce může přepsat vozidlo na frakci.")
    end

    local factionName = xPlayer.job.name

    -- Verify ownership
    MySQL.query('SELECT owner FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        if result[1] and result[1].owner == xPlayer.identifier then
            MySQL.update('UPDATE owned_vehicles SET owner = ? WHERE plate = ?', {factionName, plate}, function(rows)
                if rows > 0 then
                    cb(true)
                else
                    cb(false, "Nepodařilo se přepsat vozidlo na frakci.")
                end
            end)
        else
            cb(false, "Toto vozidlo ti nepatří!")
        end
    end)
end)

ESX.RegisterServerCallback('lgrs_garage:transferOwnership', function(source, cb, plate, targetId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end

    local tPlayer = ESX.GetPlayerFromId(tonumber(targetId))
    if not tPlayer then return cb(false, "Hráč není online.") end
    
    if tPlayer.source == source then return cb(false, "Nemůžeš přepsat vozidlo sám na sebe.") end

    -- Verify ownership
    MySQL.query('SELECT owner FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        if result[1] and result[1].owner == xPlayer.identifier then
            MySQL.update('UPDATE owned_vehicles SET owner = ? WHERE plate = ?', {tPlayer.identifier, plate}, function(rows)
                if rows > 0 then
                    TriggerClientEvent('ox_lib:notify', tPlayer.source, {title = 'Nové vozidlo', description = 'Bylo na tebe přepsáno vozidlo s SPZ '..plate, type = 'success'})
                    cb(true)
                else
                    cb(false, "Chyba při přepisu v databázi.")
                end
            end)
        else
            cb(false, Config.Locale.not_owner)
        end
    end)
end)

ESX.RegisterServerCallback('lgrs_garage:buyKeys', function(source, cb, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end

    local price = Config.LocksmithPrice or 500

    MySQL.query('SELECT owner FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        if result[1] and (result[1].owner == xPlayer.identifier or result[1].owner == xPlayer.job.name) then
            if xPlayer.getMoney() >= price then
                xPlayer.removeMoney(price)
                local meta = {
                    plate = plate,
                    description = "Klíče od vozidla (SPZ: " .. plate .. ")"
                }
                exports.ox_inventory:AddItem(source, 'carkeys', 1, meta)
                cb(true)
            else
                cb(false, "Nemáš dostatek peněz ($"..price..")")
            end
        else
            cb(false, "Toto vozidlo ti nepatří!")
        end
    end)
end)


-- Usable item (carkeys) via ox_inventory Native Export
exports('useKeys', function(event, item, inventory, slot, data)
    print("OX INVENTORY EVENT TRIGGERED:", event)
    if event == 'usingItem' then
        local source = inventory.id
        print("OX INVENTORY: usingItem for source:", source)
        if not item or not item.metadata or not item.metadata.plate then
            print("OX INVENTORY: No metadata or plate found")
            TriggerClientEvent('ox_lib:notify', source, {title = 'Chyba', description = 'Tyto klíče nemají žádnou SPZ.', type = 'error'})
            return false
        end

        local plate = item.metadata.plate
        print("OX INVENTORY: Plate found, triggering client event:", plate)
        TriggerClientEvent('lgrs_garage:useKeys', source, plate)
        return false -- Return false to prevent consuming the item
    end
end)

-- Usable item (carkeys) via ESX Compatibility
ESX.RegisterUsableItem('carkeys', function(source, itemName, itemData)
    print("CARKEYS USED! source: ", source, "itemName: ", itemName)
    if not itemData or not itemData.metadata or not itemData.metadata.plate then
        print("CARKEYS: No metadata found.")
        TriggerClientEvent('ox_lib:notify', source, {title = 'Chyba', description = 'Tyto klíče nemají žádnou SPZ.', type = 'error'})
        return
    end

    print("CARKEYS: Plate found -> ", itemData.metadata.plate)

    local plate = itemData.metadata.plate
    TriggerClientEvent('lgrs_garage:useKeys', source, plate)
end)

RegisterNetEvent('lgrs_garage:bounceKeys')
AddEventHandler('lgrs_garage:bounceKeys', function(plate)
    local src = source
    print("SERVER: Bouncing keys for source " .. tostring(src) .. " with plate " .. tostring(plate))
    TriggerClientEvent('lgrs_garage:useKeys', src, plate)
end)