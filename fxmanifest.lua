fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'DrCannabis'
description '(Original Author Koala) Alternate version of max_rox_speedway edited by DrCannabis'

ui_page 'html/index.html'

shared_scripts {
  '@ox_lib/init.lua',
  'config/config.lua',
  'locales/*.lua',           -- load your Lua locale modules
  '@qbx_core/modules/lib.lua',
  '@qbx_core/shared/locale.lua',
}

client_scripts {
  'client/c_fuel.lua',       -- <-- matches your filename
  'client/c_function.lua',
  'client/c_main.lua',
  --'client/c_pit.lua', <-- working pitcrew coming in next update
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/s_main.lua',
  'server/s_leaderboard.lua',
}

files {
  'locales/*.lua',
  'html/index.html',
  'html/**',
}

dependencies {
  'ox_lib',
  'oxmysql',
}
