local QBCore = exports['qb-core']:GetCoreObject()

local stashes = {}
local oxRegistered = {}

local function isPlayerAdmin(src)
	local ok = false
	if QBCore.Functions and QBCore.Functions.HasPermission then
		ok = QBCore.Functions.HasPermission(src, 'admin') or false
	end
	if (not ok) and QBCore.Functions and QBCore.Functions.IsPlayerAdmin then
		ok = QBCore.Functions.IsPlayerAdmin(src) or false
	end
	return ok
end

local function serializeCoords(coords)
	if type(coords) == 'table' then
		return json.encode({ x = coords.x, y = coords.y, z = coords.z })
	end
	return json.encode({})
end

local function deserializeCoords(str)
	local ok, res = pcall(json.decode, str or '{}')
	if ok and type(res) == 'table' then return res end
	return nil
end

local function broadcastStashes()
	TriggerClientEvent('ghost-stash:client:refreshStashes', -1, stashes)
end

local function sendWebhook(title, description, fields)
    if not Config.Webhook or not Config.Webhook.enabled or not Config.Webhook.url or Config.Webhook.url == '' then
        return
    end
    local embed = {
        title = title or 'Ghost Stash',
        description = description or '',
        color = 5793266,
        fields = fields or {},
        footer = { text = os.date('%Y-%m-%d %H:%M:%S') }
    }
    local payload = {
        username = Config.Webhook.username or 'Ghost Stash Logger',
        avatar_url = Config.Webhook.avatar or nil,
        embeds = { embed }
    }
    PerformHttpRequest(Config.Webhook.url, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

local function t(key)
    local L = (Config.Locales and Config.Locales[Config.Locale]) or {}
    return L[key] or key
end

local function getIdentifier(src, prefix)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, #prefix) == prefix then return id end
    end
    return nil
end

local function loadStashes()
    stashes = {}
    if not MySQL or not MySQL.query or not MySQL.query.await then
        print('^3[ghost-stash]^7 SQL library not found. Skipping DB load. Ensure oxmysql is installed and started.')
        broadcastStashes()
        return
    end
    local rows = MySQL.query.await('SELECT id, label, access_type, job, gang, coords_json, stash_id, radius FROM advanced_stashes') or {}
    for _, r in ipairs(rows) do
        table.insert(stashes, {
            id = r.id,
            label = r.label,
            accessType = r.access_type,
            job = r.job,
            gang = r.gang,
            coords = deserializeCoords(r.coords_json),
            stashId = r.stash_id,
            radius = r.radius or 1.8,
        })
    end
    if Config.inventoryType == 'ox' then
        oxRegistered = {}
        for _, s in ipairs(stashes) do
            if s.stashId and not oxRegistered[s.stashId] then
                -- slots/weight sabit veya ileride configlenebilir
                pcall(function()
                    exports.ox_inventory:RegisterStash(s.stashId, s.label or 'Stash', 50, 50000)
                    oxRegistered[s.stashId] = true
                end)
            end
        end
    end
    broadcastStashes()
end

----------------------------------------------------------------
--  DÜZENLENEN KISIM: Duplicate column hatasını engelleyen blok
----------------------------------------------------------------

AddEventHandler('onResourceStart', function(res)
	if res ~= GetCurrentResourceName() then return end

    if not MySQL or not MySQL.query then
        print('^3[ghost-stash]^7 SQL library not found. Table migration skipped. Import sql/advanced_stashes.sql manually.')
        loadStashes()
        return
    end

    -- Ana tabloyu oluştur
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `advanced_stashes` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `label` VARCHAR(100) NOT NULL,
            `access_type` VARCHAR(20) NOT NULL,
            `job` VARCHAR(50) NULL,
            `gang` VARCHAR(50) NULL,
            `coords_json` LONGTEXT NULL,
            `stash_id` VARCHAR(100) NOT NULL,
            `radius` FLOAT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uniq_stash_id` (`stash_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- "radius" kolonu varsa tekrar ekleme
    pcall(function()
        local result = MySQL.query.await("SHOW COLUMNS FROM `advanced_stashes` LIKE 'radius'")
        if not result or #result == 0 then
            print("^2[ghost-stash]^7 radius kolonu ekleniyor...")
            MySQL.query.await("ALTER TABLE `advanced_stashes` ADD COLUMN `radius` FLOAT NULL")
        end
    end)

	loadStashes()
end)

----------------------------------------------------------------
-- Kalan tüm kod senin orijinal kodundur — değiştirilmemiştir.
----------------------------------------------------------------

RegisterNetEvent('ghost-stash:server:addStash', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pname = (Player and Player.PlayerData and Player.PlayerData.name) or ('Player '..tostring(src))
    local cid = (Player and Player.PlayerData and Player.PlayerData.citizenid) or 'unknown'
    local license = getIdentifier(src, 'license:')
    local discord = getIdentifier(src, 'discord:')
    if not MySQL or not MySQL.insert then
        print('^3[ghost-stash]^7 SQL library not found. Cannot save stash to DB.')
        table.insert(stashes, data)
        broadcastStashes()
        sendWebhook(t('webhookStashCreated'), ('%s bir depo oluşturdu.'):format(pname), {
            { name = t('fieldCitizenID') or 'CitizenID', value = cid, inline = true },
            { name = t('fieldLicense') or 'License', value = license or 'n/a', inline = true },
            { name = t('fieldDiscordID') or 'DiscordID', value = discord or 'n/a', inline = true },
            { name = 'Label', value = data.label or 'n/a', inline = false },
            { name = 'Access', value = data.accessType or 'everyone', inline = true },
            { name = 'Job', value = data.job or 'n/a', inline = true },
            { name = 'Gang', value = data.gang or 'n/a', inline = true },
            { name = 'Coords', value = (data.coords and (('%.2f, %.2f, %.2f'):format(data.coords.x or 0.0, data.coords.y or 0.0, data.coords.z or 0.0))) or 'n/a', inline = false },
            { name = 'StashID', value = data.stashId or 'n/a', inline = false },
        })
        return
    end
    -- save to DB (insert or update on duplicate stashId)
    if MySQL.insert and MySQL.insert.await then
        MySQL.insert.await('INSERT INTO advanced_stashes (label, access_type, job, gang, coords_json, stash_id, radius) VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE label=VALUES(label), access_type=VALUES(access_type), job=VALUES(job), gang=VALUES(gang), coords_json=VALUES(coords_json), radius=VALUES(radius)', {
        data.label,
        data.accessType,
        data.job,
        data.gang,
        serializeCoords(data.coords),
        data.stashId,
        data.radius or 1.8,
        })
    else
        MySQL.insert('INSERT INTO advanced_stashes (label, access_type, job, gang, coords_json, stash_id, radius) VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE label=VALUES(label), access_type=VALUES(access_type), job=VALUES(job), gang=VALUES(gang), coords_json=VALUES(coords_json), radius=VALUES(radius)', {
            data.label,
            data.accessType,
            data.job,
            data.gang,
            serializeCoords(data.coords),
            data.stashId,
            data.radius or 1.8,
        })
        Wait(100)
    end
    loadStashes()
    if Config.inventoryType == 'ox' and data.stashId and not oxRegistered[data.stashId] then
        pcall(function()
            exports.ox_inventory:RegisterStash(data.stashId, data.label or 'Stash', 50, 50000)
            oxRegistered[data.stashId] = true
        end)
    end
    sendWebhook(t('webhookStashCreated'), ('%s bir depo oluşturdu.'):format(pname), {
        { name = t('fieldCitizenID') or 'CitizenID', value = cid, inline = true },
        { name = t('fieldLicense') or 'License', value = license or 'n/a', inline = true },
        { name = t('fieldDiscordID') or 'DiscordID', value = discord or 'n/a', inline = true },
        { name = 'Label', value = data.label or 'n/a', inline = false },
        { name = 'Access', value = data.accessType or 'everyone', inline = true },
        { name = 'Job', value = data.job or 'n/a', inline = true },
        { name = 'Gang', value = data.gang or 'n/a', inline = true },
        { name = 'Coords', value = (data.coords and (('%.2f, %.2f, %.2f'):format(data.coords.x or 0.0, data.coords.y or 0.0, data.coords.z or 0.0))) or 'n/a', inline = false },
        { name = 'StashID', value = data.stashId or 'n/a', inline = false },
    })
end)

RegisterNetEvent('ghost-stash:server:deleteStash', function(stashId)
    local src = source
    if not stashId or stashId == '' then return end
    if not isPlayerAdmin(src) then return end
    if MySQL and MySQL.query then
        MySQL.query('DELETE FROM advanced_stashes WHERE stash_id = ?', { stashId })
    end
    for i = #stashes, 1, -1 do
        if stashes[i].stashId == stashId then table.remove(stashes, i) end
    end
    broadcastStashes()
    local Player = QBCore.Functions.GetPlayer(src)
    local pname = (Player and Player.PlayerData and Player.PlayerData.name) or ('Player '..tostring(src))
    sendWebhook(t('webhookStashDeleted'), ('%s bir depoyu sildi.'):format(pname), {
        { name = 'StashID', value = stashId, inline = false },
        { name = t('fieldDiscordID') or 'DiscordID', value = getIdentifier(src, 'discord:') or 'n/a', inline = true }
    })
end)

RegisterNetEvent('ghost-stash:server:updateStash', function(data)
    local src = source
    if not isPlayerAdmin(src) then return end
    if not data or not data.stashId then return end
    if MySQL and MySQL.query then
        MySQL.query('UPDATE advanced_stashes SET label = ?, access_type = ?, job = ?, gang = ?, coords_json = ?, radius = ? WHERE stash_id = ?', {
            data.label,
            data.accessType,
            data.job,
            data.gang,
            serializeCoords(data.coords),
            data.radius or 1.8,
            data.stashId
        })
    end
    local updated = false
    for i = 1, #stashes do
        if stashes[i].stashId == data.stashId then
            stashes[i].label = data.label
            stashes[i].accessType = data.accessType
            stashes[i].job = data.job
            stashes[i].gang = data.gang
            stashes[i].coords = data.coords
            stashes[i].radius = data.radius or 1.8
            updated = true
            break
        end
    end
    if not updated then loadStashes() else broadcastStashes() end
end)

if Config.inventoryType == 'ox' then
    AddEventHandler('ox_inventory:removedItem', function(source, inventory, item, count, slot)
        local invId = inventory and (inventory.id or inventory)
        if type(invId) == 'string' and invId:sub(1, 6) == 'stash:' then
            local stashId = invId:sub(7)
            local Player = QBCore.Functions.GetPlayer(source)
            local pname = (Player and Player.PlayerData and Player.PlayerData.name) or ('Player '..tostring(source))
            sendWebhook(t('webhookItemRemoved'), ('%s depodan eşya aldı.'):format(pname), {
                { name = 'StashID', value = stashId, inline = true },
                { name = 'Item', value = (item and (item.label or item.name)) or 'item', inline = true },
                { name = 'Count', value = tostring(count or 1), inline = true },
                { name = t('fieldDiscordID') or 'DiscordID', value = getIdentifier(source, 'discord:') or 'n/a', inline = true },
            })
        end
    end)

    AddEventHandler('ox_inventory:addedItem', function(source, inventory, item, count, slot)
        local invId = inventory and (inventory.id or inventory)
        if type(invId) == 'string' and invId:sub(1, 6) == 'stash:' then
            local stashId = invId:sub(7)
            local Player = QBCore.Functions.GetPlayer(source)
            local pname = (Player and Player.PlayerData and Player.PlayerData.name) or ('Player '..tostring(source))
            sendWebhook(t('webhookItemAdded'), ('%s depoya eşya koydu.'):format(pname), {
                { name = 'StashID', value = stashId, inline = true },
                { name = 'Item', value = (item and (item.label or item.name)) or 'item', inline = true },
                { name = 'Count', value = tostring(count or 1), inline = true },
                { name = t('fieldDiscordID') or 'DiscordID', value = getIdentifier(source, 'discord:') or 'n/a', inline = true },
            })
        end
    end)
end

QBCore.Functions.CreateCallback('ghost-stash:server:getStashes', function(source, cb)
	local admin = isPlayerAdmin(source)
	cb({ stashes = stashes, isAdmin = admin })
end)

RegisterNetEvent('ghost-stash:server:openStash', function(stashData)
	local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	local invType = Config.inventoryType
    local stashId = stashData.stashId or ('ghoststash_'..tostring(src))

    local serverStash = nil
    for _, s in ipairs(stashes) do
        if s.stashId == stashId then serverStash = s break end
    end
    if not serverStash then
        TriggerClientEvent('QBCore:Notify', src, 'Depo bulunamadı.', 'error')
        return
    end

    local isAdmin = isPlayerAdmin(src)

    if not isAdmin and Player and serverStash and serverStash.accessType then
        local jobName = Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.name or nil
        local gangName = Player.PlayerData and Player.PlayerData.gang and Player.PlayerData.gang.name or nil
        if serverStash.accessType == 'job' then
            if not serverStash.job or serverStash.job ~= jobName then
                TriggerClientEvent('QBCore:Notify', src, 'Bu depoya erişim yetkiniz yok.', 'error')
                return
            end
        elseif serverStash.accessType == 'gang' then
            if not serverStash.gang or serverStash.gang ~= gangName then
                TriggerClientEvent('QBCore:Notify', src, 'Bu depoya erişim yetkiniz yok.', 'error')
                return
            end
        elseif serverStash.accessType == 'everyone' then
        else
            TriggerClientEvent('QBCore:Notify', src, 'Bu depoya erişim yetkiniz yok.', 'error')
            return
        end
    end

    if invType == 'qb' then
		TriggerClientEvent('inventory:client:SetCurrentStash', src, stashId)
		TriggerClientEvent('inventory:client:OpenInventory', src, 'stash', {maxweight = 50000, slots = 50, label = stashData.label, id = stashId})
	elseif invType == 'ox' then
        if not oxRegistered[stashId] then
            pcall(function()
                exports.ox_inventory:RegisterStash(stashId, stashData.label or 'Stash', 50, 50000)
                oxRegistered[stashId] = true
            end)
        end
        local ok = pcall(function()
            exports.ox_inventory:OpenInventory(src, 'stash', stashId)
        end)
        if not ok then
            TriggerClientEvent('ox_inventory:openInventory', src, 'stash', { id = stashId })
        end
	end
end)
