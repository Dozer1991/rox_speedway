fx_version 'cerulean'
game 'gta5'

author 'DrCannabis'
description '(Original Author Koala) Alternate version of max_rox_speedway edited by DrCannabis'

shared_scripts {
	'@ox_lib/init.lua',
    '@qb-core/shared/locale.lua',
}

client_scripts {
    'client/*.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/s_main.lua'
   
}

files {
    'config/config.lua',
    'locales/*.lua'
}

dependencies {
    'ox_lib',
    'qb-core',
    'qb-target',
    'oxmysql',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'