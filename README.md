# ESX Garage System

A comprehensive garage and impound system for FiveM (ESX), built using modern elements like `ox_lib` and `ox_target`, completely replacing traditional marker-based garages.

## 🌟 Main Features

### 🚗 Vehicle Parking (New Method)
- Parking is very natural – just drive your vehicle near a garage (within 20 meters).
- Get out of the vehicle and aim directly at the car using `ox_target` (LALT key).
- Select the **"Park Vehicle"** option, which will instantly store the car in the nearest garage.
- Parking the vehicle automatically confiscates the `carkeys` item from your inventory.

### 📋 Garage System (Retrieval)
- Interacting with the garage NPC via `ox_target` instantly displays a clean list of **all owned vehicles**.
- The menu clearly indicates whether the vehicle is in this garage, another garage, or outside.
- Players can see detailed vehicle conditions: current engine health and fuel level (saved directly to the database).
- The system remembers all body damage, broken windows, popped tires, and tuning.
- Pulling a vehicle out gives the player a unique `carkeys` item with the specific vehicle plate metadata, which can be used to lock and unlock the vehicle from a distance (with animations and sounds).

### 💸 Transferring Cars & Ownership Management
- **Garage Transfer:** If a personal vehicle is stored in another garage, the player can click on it and select **"Transfer Here"** for a fixed fee. The vehicle is instantly reassigned and ready for retrieval.
- **Vehicle Gifting:** Players can permanently transfer ownership of their personal vehicles to other nearby players using their server ID.
- **Renaming:** Players can rename their personal vehicles to find them easier in the garage list.

### 🏢 Faction & Job Garages
- **Shared Fleet:** Faction vehicles (e.g. Police, EMS) are tied to the job name rather than a specific player.
- **Free Retrieval:** Faction members can retrieve their faction's stored vehicles from ANY garage instantly and for free (bypassing transfer fees).
- **Boss Features:** The Boss of a faction (`grade_name = 'boss'`) has exclusive privileges:
  - They can **rename** faction vehicles.
  - They can **donate** their own personal vehicles permanently to their faction's fleet.

### 🚜 Impound
- Used for vehicles left anywhere on the map (status `stored = 0`).
- Players can retrieve them from the impound for a preset fee (they spawn immediately and grant the keys).
- Everything is smoothly controlled via `ox_lib` menus and the impound NPC.

## 🛠️ Administrator Features

### 🏗️ In-game Garage Creation (`/garageedit`)
- Fully interactive in-game menu for creating and deleting personal garages and impounds.
- Easy 2-step setup using your character's position and rotation:
  1. **Step 1**: Stand at the NPC position and press `E` to confirm.
  2. **Step 2**: Stand at the vehicle spawn/parking zone (facing the correct direction) and press `E` to confirm.
- The garage is instantly created in the database, and map blips and the NPC will spawn.

### 🎁 Gifting Vehicles (`/givecar`)
- A modern command for gifting any player a new personal vehicle.
- Running the command opens a form (`ox_lib` dialog) to select the player ID, vehicle model, and spawn garage.
- The plate is automatically formatted as 8 valid alphanumeric characters (e.g., AAAA1111) if left blank.

### 🏢 Faction Vehicle Spawning (`/givecompany`)
- Specifically designed to mass-spawn fleet vehicles for jobs.
- Opens an `ox_lib` dialog where an admin can input the target faction (e.g., `police`), vehicle model, garage, and **Quantity** (up to 100 vehicles at once).
- Automatically generates unique valid plates for every vehicle and registers them to the faction in milliseconds.

## ⚙️ Technical Information
- Optimized for the lowest possible client and server load (no `Wait(0)` loops for rendering 3D text or markers).
- Uses local peds implemented with `ox_target`.
- All UI is built purely on `ox_lib` (Menu, Context, TextUI, Dialog, Notify, InputDialog).
- Database access is asynchronous via `oxmysql`.
- Full integration with `ox_inventory` metadata for usable physical car keys.
