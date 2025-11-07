local QBCore = exports['qb-core']:GetCoreObject()
local stashes = {}
local uiOpen = false
local nearbyStash = nil
local isAdmin = false
local zones = {}

RegisterNetEvent('ghost-stash:client:refreshStashes', function(newStashes)
	stashes = newStashes
	local ped = PlayerPedId()
	local playerCoords = GetEntityCoords(ped)
	-- Rebuild PolyZones
	for id, z in pairs(zones) do
		if z and z.destroy then pcall(function() z:destroy() end) end
		zones[id] = nil
	end
	nearbyStash = nil
	SendNUIMessage({ action = 'hideTextUI' })
	
	for _, s in ipairs(stashes) do
		if s.coords and s.coords.x and s.coords.y and s.coords.z then
			local radius = tonumber(s.radius or 1.8) or 1.8
			if CircleZone then
				local z = CircleZone:Create(vector3(s.coords.x + 0.0, s.coords.y + 0.0, s.coords.z + 0.0), radius, { useZ = false, name = s.stashId or ('stash_'.._) })
				z:onPlayerInOut(function(isPointInside)
					if uiOpen then return end
					if isPointInside then
						nearbyStash = s
						local text = (Config.Locales[Config.Locale] and Config.Locales[Config.Locale].textuiOpen) or 'Depoyu Aç'
						SendNUIMessage({ action = 'showTextUI', text = text })
					else
						if nearbyStash and nearbyStash.stashId == s.stashId then
							nearbyStash = nil
							SendNUIMessage({ action = 'hideTextUI' })
						end
					end
				end)
				zones[s.stashId or ('stash_'.._)] = z
				
				-- Zone oluşturulduktan sonra oyuncu içindeyse TextUI göster
				if not uiOpen then
					local dist = #(playerCoords - vector3(s.coords.x, s.coords.y, s.coords.z))
					if dist <= radius then
						nearbyStash = s
						local text = (Config.Locales[Config.Locale] and Config.Locales[Config.Locale].textuiOpen) or 'Depoyu Aç'
						SendNUIMessage({ action = 'showTextUI', text = text })
					end
				end
			end
		end
	end
	if uiOpen then
		SendNUIMessage({action = 'updateStashes', stashes = stashes})
	end
end)

-- İlk yüklemede admin ve stash verisini çek, TextUI konumunu uygula
CreateThread(function()
    Wait(1000)
    QBCore.Functions.TriggerCallback('ghost-stash:server:getStashes', function(resp)
        if resp then
            stashes = resp.stashes or {}
            isAdmin = resp.isAdmin or false
            -- İlk yüklemede zones'u oluştur
            for _, s in ipairs(stashes) do
                if s.coords and s.coords.x and s.coords.y and s.coords.z then
                    local radius = tonumber(s.radius or 1.8) or 1.8
                    if CircleZone then
                        local z = CircleZone:Create(vector3(s.coords.x + 0.0, s.coords.y + 0.0, s.coords.z + 0.0), radius, { useZ = false, name = s.stashId or ('stash_'..#zones+1) })
                        z:onPlayerInOut(function(isPointInside)
                            if uiOpen then return end
                            if isPointInside then
                                nearbyStash = s
                                local text = (Config.Locales[Config.Locale] and Config.Locales[Config.Locale].textuiOpen) or 'Depoyu Aç'
                                SendNUIMessage({ action = 'showTextUI', text = text })
                            else
                                if nearbyStash and nearbyStash.stashId == s.stashId then
                                    nearbyStash = nil
                                    SendNUIMessage({ action = 'hideTextUI' })
                                end
                            end
                        end)
                        zones[s.stashId or ('stash_'..#zones+1)] = z
                    end
                end
            end
        end
    end)
    -- TextUI konumunu NUI'ya bildir
    Wait(500)
    local align = (Config.TextUI and Config.TextUI.align) or 'center'
    local bottomPercent = (Config.TextUI and Config.TextUI.bottomPercent) or 7
    local sidePercent = (Config.TextUI and Config.TextUI.sidePercent) or 3
    SendNUIMessage({ action = 'configTextUI', align = align, bottomPercent = bottomPercent, sidePercent = sidePercent })
end)

function OpenStashMenu()
    QBCore.Functions.TriggerCallback('ghost-stash:server:getStashes', function(resp)
        local serverStashes = resp and resp.stashes or {}
        isAdmin = resp and resp.isAdmin or false
        if not isAdmin then
            QBCore.Functions.Notify('Bu komuta sadece admin erişebilir.', 'error')
            return
        end
		SetNuiFocus(true, true)
		uiOpen = true
        SendNUIMessage({action = 'openStashMenu', stashes = serverStashes, locale = Config.Locales[Config.Locale], isAdmin = isAdmin, uiTitle = (Config.UI and Config.UI.title) or 'Ghost Stash'})
	end)
end

RegisterNetEvent('ghost-stash:client:openStash', function(stashData)
	TriggerServerEvent('ghost-stash:server:openStash', stashData)
end)

-- Sadece açma komutu kaldı - sadece admin erişebilir
RegisterCommand(Config.OpenCommand, OpenStashMenu)

-- NUI kapandığında focus geri alınmalı (kapanış js'de, yeni bir event yakalanabilir)
RegisterNetEvent('ghost-stash:client:closeUI', function()
	SetNuiFocus(false, false)
	uiOpen = false
end)

-- NUI Callbacks
RegisterNUICallback('close', function(_, cb)
	SetNuiFocus(false, false)
	uiOpen = false
	cb('ok')
end)

RegisterNUICallback('openStash', function(data, cb)
	TriggerServerEvent('ghost-stash:server:openStash', data)
	cb('ok')
end)

RegisterNUICallback('addStash', function(data, cb)
	-- data should contain: label, coords {x,y,z}, accessType ('everyone'|'job'|'gang'), job, gang, stashId
	TriggerServerEvent('ghost-stash:server:addStash', data)
	-- Server-side refresh eventi bekleniyor, ama garantilemek için thread'de refresh et
	CreateThread(function()
		Wait(500)
		QBCore.Functions.TriggerCallback('ghost-stash:server:getStashes', function(resp)
			if resp then
				local serverStashes = resp.stashes or {}
				isAdmin = resp.isAdmin or false
				if uiOpen then
					SendNUIMessage({action = 'updateStashes', stashes = serverStashes})
				end
			end
		end)
	end)
	cb('ok')
end)

RegisterNUICallback('getCoords', function(_, cb)
	local ped = PlayerPedId()
	local coords = GetEntityCoords(ped)
	cb({ x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 })
end)

RegisterNUICallback('teleportTo', function(data, cb)
    local coords = data and data.coords
    if coords and coords.x and coords.y and coords.z then
        local ped = PlayerPedId()
        SetEntityCoords(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, false, false, false, false)
        -- Işınlandıktan sonra yakındaki depoyu kontrol et
        CreateThread(function()
            Wait(100) -- Kısa bir bekleme, konum güncellensin
            if not uiOpen then
                local playerCoords = GetEntityCoords(ped)
                nearbyStash = nil
                SendNUIMessage({ action = 'hideTextUI' })
                
                for _, s in ipairs(stashes) do
                    if s.coords and s.coords.x and s.coords.y and s.coords.z then
                        local radius = tonumber(s.radius or 1.8) or 1.8
                        local dist = #(playerCoords - vector3(s.coords.x, s.coords.y, s.coords.z))
                        if dist <= radius then
                            nearbyStash = s
                            local text = (Config.Locales[Config.Locale] and Config.Locales[Config.Locale].textuiOpen) or 'Depoyu Aç'
                            SendNUIMessage({ action = 'showTextUI', text = text })
                            break
                        end
                    end
                end
            end
        end)
    end
    cb('ok')
end)

RegisterNUICallback('deleteStash', function(data, cb)
    if data and data.stashId then
        TriggerServerEvent('ghost-stash:server:deleteStash', data.stashId)
    end
    cb('ok')
end)

RegisterNUICallback('updateStash', function(data, cb)
    if data and data.stashId then
        TriggerServerEvent('ghost-stash:server:updateStash', data)
    end
    cb('ok')
end)

-- Proximity TextUI thread
CreateThread(function()
    while true do
        Wait(0)
        if nearbyStash and not uiOpen then
            if IsControlJustPressed(0, 38) then -- E
                TriggerServerEvent('ghost-stash:server:openStash', nearbyStash)
            end
        end
    end
end)
