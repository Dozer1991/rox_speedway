fx_version 'cerulean'
game 'gta5'

author 'Original Author Koala'
description 'alternate version of max_rox_speedway edited by DrCannabis'

shared_scripts {
	'@ox_lib/init.lua',
    '@qb-core/shared/locale.lua',
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