fx_version 'cerulean'

game 'gta5'

author 'KanlıAy'
description 'Advanced Stash Creator in Game for QBCore'
version '1.0.0'

shared_script 'config.lua'
client_scripts {
    'client/*.lua',
    '@PolyZone/client.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/BoxZone.lua'
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
    'html/style.css',
    'html/assets/img/*',
    'html/assets/img/*.png',
}

escrow_ignore {
    'sql/*.sql',
    'config.lua',
    'html/index.html',
    'html/app.js',
    'html/style.css',
    'html/assets/img/*',
    'html/assets/img/*.png',
}

dependency {
    'qb-core',
    'PolyZone',
}

