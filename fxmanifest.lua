fx_version 'cerulean'
game 'gta5'

author 'LGRS SCRIPTS'
description 'Advanced Garage for ESX Legacy with ox_lib & ox_target'
version '2.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'locales/en.lua',
    'locales/cs.lua',
    'locales/de.lua',
    'locales/pl.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'oxmysql'
}
