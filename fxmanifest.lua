fx_version 'cerulean'
game 'gta5'

author 'Koala'
description 'piste de cource pour roxwood'

shared_scripts {
	'@ox_lib/init.lua',
    '@qb-core/shared/locale.lua',      -- for QBCore locale support (optional)
}

client_scripts {
    'client/*.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/s_main.lua',
    'server/s_function.lua'
   
}

files {
    'config/config.lua',
    'locales/*.json'
}

dependencies {
    'ox_lib',
    'qb-core',
    'qb-target',
    'oxmysql',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'