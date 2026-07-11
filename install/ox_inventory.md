# ox_inventory Setup (Vehicle Keys)

For the garage system and vehicle parking to work properly, the system must be able to handle vehicle keys.

## 1. Adding the Item
Open the file `[ox]/ox_inventory/data/items.lua` (or wherever your items for ox_inventory are defined).
Add this block of code to the list:

```lua
    ['carkeys'] = {
        label = 'Vehicle Keys',
        weight = 50,
        stack = false,
        close = true,
        description = 'Used to unlock and park your vehicle.'
    },
```

## 2. Icon (Image)
Place any image named `carkeys.png` into the `img` folder located next to this guide.
Then copy this image into `[ox]/ox_inventory/web/images/carkeys.png`.

Once you have done this, restart the server or type `ensure ox_inventory` in the console.
When you retrieve a car from the garage, the keys will automatically appear in your inventory (they contain the license plate as unique metadata), and when you park the car, they will be removed from your inventory.
