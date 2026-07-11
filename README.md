# ESX Garage System

A comprehensive garage and impound system for FiveM (ESX), built using modern elements like `ox_lib` and `ox_target`.

## 🌟 Main Features

### 🚗 Vehicle Parking (New Method)
- Parking is very natural – just drive your vehicle near a garage (within 20 meters).
- Get out of the vehicle and aim directly at the car using `ox_target` (LALT key).
- Select the **"Park Vehicle"** option, which will instantly store the car in the nearest garage.

### 📋 Garage System (Retrieval)
- Interacting with the garage NPC via `ox_target` instantly displays a clean list of **all owned vehicles**.
- The menu clearly indicates whether the vehicle is in this garage, another garage, or outside.
- Players can see detailed vehicle conditions: current engine health and fuel level (saved directly to the database).
- The system remembers all body damage, broken windows, popped tires, and tuning.

### 💸 Transferring Cars from Other Garages
- If a vehicle is stored in another garage, the player can clearly see this in the menu, including the name of that garage.
- Clicking on the vehicle provides the **"Transfer Here"** option for a fixed fee (configurable in Config).
- The vehicle is instantly reassigned to the current garage and ready for retrieval.

### 🚜 Impound
- Used for vehicles left anywhere on the map (status `stored = 0`).
- Players can retrieve them from the impound for a preset fee (they spawn immediately).
- Everything is smoothly controlled via `ox_lib` menus and the impound NPC.

## 🛠️ Administrator Features

### 🏗️ In-game Garage Creation (`/garageedit`)
- Fully interactive in-game menu for creating and deleting garages/impounds.
- After entering a name for the new garage, precise positioning is done via `lib.showTextUI`:
  1. **Step 1**: Stand at the NPC position and press `E` to confirm.
  2. **Step 2**: Stand at the vehicle spawn position (facing the correct direction) and press `E` to confirm.
- The garage is instantly created in the database, and map blips and the NPC will spawn.
- Garages can be deleted at any time through the menu.

### 🎁 Gifting Vehicles (`/givecar`)
- A modern command for gifting any player a new vehicle.
- Running the command opens a form (`ox_lib` dialog):
  - **Player ID** to give the car to.
  - **Vehicle Model** (e.g., t20).
  - **License Plate** (optional - if left blank, a random valid format plate is generated).
  - **Garage** - option to immediately store the vehicle in any existing garage or leave it outside.
- The vehicle is automatically saved to the player's database.

## ⚙️ Technical Information
- Optimized for the lowest possible client and server load (no unnecessary `Wait(0)` loops for rendering markers).
- Uses local peds implemented with `ox_target`.
- All UI is built purely on `ox_lib` (Menu, Context, TextUI, Dialog, Notify).
- Database access is asynchronous via `oxmysql`.
