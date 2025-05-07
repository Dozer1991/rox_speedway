local QBCore = exports['qb-core']:GetCoreObject()
lib.locale()
local config = require "config.shared"

local lobbies = {}
local selectedVehicles = {}
RaceVehicles = {} -- [playerId] = vehicleEntity
--#region registeevent
RegisterNetEvent("speedway:createLobby", function(lobbyName, trackType, lapCount)
    local src = source

    -- Empêche les doublons
    if lobbies[lobbyName] then
        TriggerClientEvent('ox_lib:notify', src, {
            description = locale("lobby_exists"),
            type = "error"
        })

        return
    end

    lobbies[lobbyName] = {
        owner = src,
        track = trackType,
        laps = lapCount or 1,
        players = { src },
        isStarted = false,
        lapProgress = {},
        finished = {},
        lapTimes = {},  -- [playerId] = { tour1 = ms, tour2 = ms, ... }
        startTime = {}, -- [playerId] = timestamp du dernier passage de ligne
        vehicles = {}

    }

    for _, id in ipairs(lobbies[lobbyName].players) do
        TriggerClientEvent("speedway:updateLobbyInfo", id, {
            name = lobbyName,
            track = lobbies[lobbyName].track,
            players = lobbies[lobbyName].players,
            owner = lobbies[lobbyName].owner,
            laps = lobbies[lobbyName].laps
        })
    end


    -- Confirmation côté client
    TriggerClientEvent('ox_lib:notify', src, {
        description = locale("lobby_created", lobbyName),
        type = "success"
    })

    -- Mets à jour l’état de disponibilité côté client (pour afficher "rejoindre un lobby")
    TriggerClientEvent('speedway:setLobbyState', -1, next(lobbies) ~= nil)
end)

RegisterNetEvent("speedway:joinLobby", function(lobbyName)
    local src = source
    local lobby = lobbies[lobbyName]

    if not lobby then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Speedway",
            description = locale("lobby_not_found"),
            type = "error"
        })
        return
    end

    -- Si le joueur n’est pas déjà dans le lobby, on l’ajoute
    if not table.contains(lobby.players, src) then
        table.insert(lobby.players, src)
    end

    -- Envoie la mise à jour à tous les joueurs du lobby
    for _, id in ipairs(lobby.players) do
        TriggerClientEvent("speedway:updateLobbyInfo", id, {
            name = lobbyName,
            track = lobby.track,
            players = lobby.players,
            owner = lobby.owner
        })
    end

    -- Notification de confirmation
    TriggerClientEvent('ox_lib:notify', src, {
        title = "Speedway",
        description = locale("joined_lobby", lobbyName),
        type = "success"
    })
end)

RegisterNetEvent("speedway:leaveLobby", function()
    local src = source

    for name, lobby in pairs(lobbies) do
        for i, id in ipairs(lobby.players) do
            if id == src then
                table.remove(lobby.players, i)

                -- Si c'était le créateur, on supprime tout le lobby
                if lobby.owner == src then
                    for _, player in ipairs(lobby.players) do
                        TriggerClientEvent("ox_lib:notify", player, {
                            title = "Speedway",
                            description = locale("lobby_closed_by_owner", name),
                            type = "warning"
                        })
                        TriggerClientEvent("speedway:updateLobbyInfo", player, nil)
                    end
                    lobbies[name] = nil
                else
                    -- Sinon, mise à jour des autres joueurs
                    for _, player in ipairs(lobby.players) do
                        TriggerClientEvent("speedway:updateLobbyInfo", player, {
                            name = name,
                            track = lobby.track,
                            players = lobby.players,
                            owner = lobby.owner
                        })
                    end
                end

                -- Met à jour la disponibilité globale
                TriggerClientEvent("speedway:setLobbyState", -1, next(lobbies) ~= nil)
                return
            end
        end
    end
end)

RegisterNetEvent("speedway:startRace", function(lobbyName)
    local src = source
    print(("[speedway] SERVER received startRace from %d for lobby '%s'"):format(src, tostring(lobbyName)))

    local lobby = lobbies[lobbyName]
    if not lobby then
        print("[speedway] SERVER startRace — lobby not found")
        TriggerClientEvent('ox_lib:notify', src, {
            description = locale("lobby_not_found"),
            type        = "error"
        })
        return
    end

    if lobby.owner ~= src then
        print(("[speedway] SERVER startRace — src (%d) is not owner (%d)"):format(src, lobby.owner))
        TriggerClientEvent('ox_lib:notify', src, {
            description = locale("not_authorized_to_start_race"),
            type        = "error"
        })
        return
    end

    print("[speedway] SERVER startRace — host verified, starting vehicle selection")
    lobby.isStarted = true

    local selectedVehicles = {}
    for i, pid in ipairs(lobby.players) do
        lib.callback("speedway:getVehicleChoice", pid, function(model)
            print(("[speedway] SERVER got choice from %d: %s"):format(pid, tostring(model)))
            if model then
                selectedVehicles[pid] = model
            end

            if #lobby.players == table.count(selectedVehicles) then
                print("[speedway] SERVER all choices in, spawning vehicles")
                for idx, p in ipairs(lobby.players) do
                    local spawn  = config.GridSpawnPoints[idx]
                    local vehMdl = selectedVehicles[p] or config.RaceVehicles[1].model
                    local veh    = CreateVehicle(joaat(vehMdl), spawn.x, spawn.y, spawn.z, spawn.w, true, false)
                    while not DoesEntityExist(veh) do Wait(0) end

                    local netId = NetworkGetNetworkIdFromEntity(veh)
                    local plate = "RACE" .. math.random(1000,9999)
                    SetVehicleNumberPlateText(veh, plate)
                    FreezeEntityPosition(veh, true)

                    -- give the temp key so they can hotwire if nearby
                    exports['qb-vehiclekeys']:GiveKeys(p, veh)

                    -- **correct** plate‐ownership event
                    TriggerClientEvent('vehiclekeys:client:SetOwner', p, plate)

                    RaceVehicles[p] = veh

                    TriggerClientEvent("speedway:prepareStart", p, {
                        track = lobby.track,
                        netId = netId
                    })
                end

                selectedVehicles = {}
            end
        end)
    end
end)


RegisterNetEvent("speedway:lapPassed", function(lobbyName)
    local src = source
    local lobby = lobbies[lobbyName]
    if not lobby then return end

    -- Init structures
    lobby.lapProgress[src] = (lobby.lapProgress[src] or -1) + 1
    local currentLap = lobby.lapProgress[src]
    local totalLaps = lobby.laps
    local now = GetGameTimer()

    -- Init chrono structures
    lobby.startTime = lobby.startTime or {}
    lobby.lapTimes = lobby.lapTimes or {}
    lobby.lapTimes[src] = lobby.lapTimes[src] or {}

    -- 🚫 Ignore le premier faux passage (TP)
    if currentLap <= 0 then
        lobby.startTime[src] = now
        return
    end

    -- ⏱️ Calcul temps du tour
    if lobby.startTime[src] then
        local lapDuration = now - lobby.startTime[src]
        table.insert(lobby.lapTimes[src], lapDuration)
    end

    lobby.startTime[src] = now

    -- ✅ Si le joueur a fini
    if currentLap >= totalLaps then
        if not lobby.finished[src] then
            lobby.finished[src] = true
            TriggerEvent("speedway:server:youFinished", src)
        end

        -- 🔁 Check fin de course
        local allFinished = true
        for _, pid in ipairs(lobby.players) do
            if not lobby.finished[pid] then
                allFinished = false
                break
            end
        end

        if allFinished then
            -- 🏆 CLASSEMENT
            local results = {}
            for _, pid in ipairs(lobby.players) do
                local total = 0
                for _, t in ipairs(lobby.lapTimes[pid] or {}) do
                    total = total + t
                end
                table.insert(results, { id = pid, time = total })
            end

            table.sort(results, function(a, b) return a.time < b.time end)

            -- send each their personal ranking…
            for pos, entry in ipairs(results) do
                -- grab this player’s lap times
                local lapTimes = lobby.lapTimes[entry.id] or {}
                -- compute best lap (in ms)
                local bestLap  = 0
                if #lapTimes > 0 then
                    bestLap = lapTimes[1]
                    for _, t in ipairs(lapTimes) do
                        if t < bestLap then bestLap = t end
                    end
                end
    
                TriggerClientEvent("speedway:finalRanking", entry.id, {
                    position   = pos,
                    totalTime  = entry.time,
                    allResults = results,
                    lapTimes   = lapTimes,
                    bestLap    = bestLap
                })
            end

        -- broadcast the podium to all clients
        TriggerClientEvent("speedway:finalRanking", -1, {
            position   = nil,
            totalTime  = nil,
            allResults = results
        })

        -- cleanup…
        for _, pid in ipairs(lobby.players) do
            TriggerClientEvent("speedway:client:destroyprops", pid)
        end
        lobbies[lobbyName] = nil
        TriggerClientEvent("speedway:setLobbyState", -1, next(lobbies) ~= nil)


            -- 🧹 Nettoyage des props : uniquement joueurs du lobby
            for _, pid in ipairs(lobby.players) do
                TriggerClientEvent("speedway:client:destroyprops", pid)
            end

            -- 🗑️ Suppression du lobby
            lobbies[lobbyName] = nil
            TriggerClientEvent("speedway:setLobbyState", -1, next(lobbies) ~= nil)


            -- 🔄 MAJ côté client pour masquer le bouton "Rejoindre un lobby"
            TriggerClientEvent("speedway:setLobbyState", -1, next(lobbies) ~= nil)

        end
    else
        TriggerClientEvent("speedway:updateLap", src, currentLap, totalLaps)
    end
end)
AddEventHandler("speedway:server:youFinished", function(playerId)
    local ped = GetPlayerPed(playerId)

    local veh = RaceVehicles[playerId]
    if veh and DoesEntityExist(veh) then
        DeleteEntity(veh)
    end
    RaceVehicles[playerId] = nil

    local outCoords = config.outCoords
    SetEntityCoords(ped, outCoords.x, outCoords.y, outCoords.z)
    SetEntityHeading(ped, outCoords.w)
end)



--#endregion registeevent

--#region callback
lib.callback.register("speedway:getLobbies", function()
    local result = {}

    for name, data in pairs(lobbies) do
        result[#result + 1] = {
            label = name .. " | " .. data.track,
            value = name
        }
    end

    return result
end)
--#endregion callback
