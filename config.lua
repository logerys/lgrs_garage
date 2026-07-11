Config = {}

-- Security
Config.AdminGroups = {
    ['admin'] = true,
    ['superadmin'] = true
}

-- Impound and Pricing
Config.ImpoundPrice = 500 -- Price to retrieve vehicle from impound
Config.TransferPrice = 100 -- Price to transfer vehicle from another garage
Config.LocksmithPrice = 500 -- Price to generate new keys

-- NPC (Ped) settings
Config.GaragePedModel = 's_m_y_valet_01'
Config.ImpoundPedModel = 's_m_m_autoshop_01'

-- Map Blips
Config.Blips = {
    Garage = {
        Sprite = 357,
        Color = 3,
        Scale = 0.8,
        Name = "Garage"
    },
    Impound = {
        Sprite = 430,
        Color = 1,
        Scale = 0.8,
        Name = "Impound"
    }
}

-- Language Selection (en, cs, de, pl)
Config.Language = 'en'
Config.Locale = Locales[Config.Language]
