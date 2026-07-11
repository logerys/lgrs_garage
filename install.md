# ESX Garage Installation (with ox_inventory and ox_target support)

Follow these steps for a correct and error-free installation of the garage system on your FiveM server.

## 1. Dependencies
Ensure you have the following scripts installed, running, and up to date on your server:
- `es_extended` (Legacy version)
- `ox_lib`
- `ox_target`
- `ox_inventory`
- `oxmysql`

Your `server.cfg` should look something like this (order is important):
```cfg
ensure oxmysql
ensure ox_lib
ensure es_extended
ensure ox_target
ensure ox_inventory
...
ensure lgrs_garage
```

## 2. Database Preparation
For proper garage and vehicle saving, you must import the necessary tables and modifications into your MySQL database.

1. Open your database management tool (HeidiSQL, phpMyAdmin, DBeaver).
2. Run the entire content of **`lgrs_garage.sql`** (This file creates the `garage_locations` table).
3. Run the content of **`update.sql`** (This file adds the `nickname` column to the existing `owned_vehicles` table for the vehicle renaming feature).

*Note: The script assumes you are using the standard ESX `owned_vehicles` table (containing plate, vehicle, stored, parking, owner columns).*

## 3. Inventory Setup (ox_inventory)
To enable the retrieval and storage of vehicle keys, you must add a new item to your inventory.

1. Go to your inventory folder: `[ox]/ox_inventory/data/items.lua`
2. Add the following block anywhere in your item list (e.g., below keys or money):

```lua
    ['carkeys'] = {
        label = 'Vehicle Keys',
        weight = 50,
        stack = false,
        close = true,
        description = 'Used to access and park the vehicle.'
    },
```
3. Save the file. (If you use a newer version of ox_inventory with an item generator, don't forget to apply the changes or restart the server).

## 4. Configuration (Optional)
Open the `config.lua` file inside the `lgrs_garage` folder.
Here you can adjust:
- `Config.AdminGroups`: Which admin groups have permission for `/garageedit` and `/givecar` commands.
- `Config.ImpoundPrice`: The price for the impound.
- `Config.TransferPrice`: The price to transfer a car between garages.
- `Config.LocksmithPrice`: The price for creating new car keys.
- Ped models and map icons (Blips).

## 5. Startup
Once everything is done, restart your server or type into the server console:
```cmd
refresh
ensure ox_inventory
ensure lgrs_garage
```

And you're done! You can join the server and use the `/garageedit` command to create your first garage.
