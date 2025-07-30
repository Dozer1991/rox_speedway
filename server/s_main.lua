-- server/s_main.lua

local Config = require("config.config")
local readyCount = 0
local readyClients = {}

-- LOCALE HELPER (uses your Lua locale modules)
local function locale(key, ...)
    local t = Config.Locales[Config.Locale] or {}
    local str = t[key] or key
    local args = { ... }
    return (str:gsub("{(%d+)}", function(n)
        return tostring(args[tonumber(n)] or "")
    end))
end

--------------------------------------------------------------------------------
-- re-add table helpers from s_function.lua
--------------------------------------------------------------------------------
local function table_contains(tbl, val)
  for _, v in ipairs(tbl) do
    if v == val then return true end
  end
  return false
end

local function table_count(tbl)
  local count = 0
  for _ in pairs(tbl) do count = count + 1 end
  return count
end

--------------------------------------------------------------------------------
-- lobby storage
--------------------------------------------------------------------------------
local lobbies        = {}    -- [lobbyName] = { owner, track, laps, players, ... }
local pendingChoices = {}    -- for vehicle selection

math.randomseed(GetGameTimer())

--------------------------------------------------------------------------------
-- callbacks for client queries
--------------------------------------------------------------------------------
lib.callback.register("speedway:getLobbies", function(source)
  local result = {}
  for name, lobby in pairs(lobbies) do
    table.insert(result, {
      label = name .. " | " .. lobby.track .. " (" .. #lobby.players .. " players)",
      value = name
    })
  end
  return result
end)

lib.callback.register("speedway:getLobbyPlayers", function(source, lobbyName)
  local lobby = lobbies[lobbyName]
  return lobby and lobby.players or {}
end)

--------------------------------------------------------------------------------
-- CREATE LOBBY
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:createLobby", function(lobbyName, trackType, lapCount)
  local src = source
  if lobbies[lobbyName] then
    TriggerClientEvent('ox_lib:notify', src, {
      description = locale("lobby_exists"),
      type        = "error"
    })
    return
  end

  lobbies[lobbyName] = {
    owner              = src,
    track              = trackType,
    laps               = lapCount or 1,
    players            = { src },
    checkpointProgress = {},
    isStarted          = false,
    lapProgress        = {},
    finished           = {},
    lapTimes           = {},
    startTime          = {},
    progress           = {},
  }

  -- tell the creator
  TriggerClientEvent('ox_lib:notify', src, {
    description = locale("lobby_created", lobbyName),
    type        = "success"
  })
  TriggerClientEvent('speedway:updateLobbyInfo', src, {
    name    = lobbyName,
    track   = trackType,
    players = lobbies[lobbyName].players,
    owner   = src,
    laps    = lobbies[lobbyName].laps
  })
  TriggerClientEvent('speedway:setLobbyState', -1, next(lobbies) ~= nil)
end)

--------------------------------------------------------------------------------
-- JOIN LOBBY
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:joinLobby", function(lobbyName)
  local src   = source
  local lobby = lobbies[lobbyName]
  if not lobby then
    TriggerClientEvent('ox_lib:notify', src, {
      title       = "Speedway",
      description = locale("lobby_not_found"),
      type        = "error"
    })
    return
  end

  if not table_contains(lobby.players, src) then
    table.insert(lobby.players, src)
    -- BROADCAST who joined
    local playerName = GetPlayerName(src)
    for _, id in ipairs(lobby.players) do
      TriggerClientEvent("speedway:client:playerJoined", id, playerName)
    end
  end

  -- update everyone’s lobby info
  for _, id in ipairs(lobby.players) do
    TriggerClientEvent("speedway:updateLobbyInfo", id, {
      name    = lobbyName,
      track   = lobby.track,
      players = lobby.players,
      owner   = lobby.owner,
      laps    = lobby.laps
    })
  end
end)

--------------------------------------------------------------------------------
-- LEAVE LOBBY
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:leaveLobby", function()
  local src = source
  for name, lobby in pairs(lobbies) do
    for i, id in ipairs(lobby.players) do
      if id == src then
        table.remove(lobby.players, i)
        if lobby.owner == src then
          -- owner left → close lobby
          for _, player in ipairs(lobby.players) do
            TriggerClientEvent('ox_lib:notify', player, {
              title       = "Speedway",
              description = locale("lobby_closed_by_owner", name),
              type        = "warning"
            })
            TriggerClientEvent("speedway:updateLobbyInfo", player, nil)
          end
          lobbies[name] = nil
        else
          -- member left → update remaining
          for _, player in ipairs(lobby.players) do
            TriggerClientEvent("speedway:updateLobbyInfo", player, {
              name    = name,
              track   = lobby.track,
              players = lobby.players,
              owner   = lobby.owner,
              laps    = lobby.laps
            })
          end
        end

        -- clear leaver’s UI
        TriggerClientEvent("speedway:updateLobbyInfo", src, nil)
        TriggerClientEvent("speedway:setLobbyState", -1, next(lobbies) ~= nil)
        return
      end
    end
  end
end)

--------------------------------------------------------------------------------
-- START RACE & VEHICLE SELECTION
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:startRace", function(lobbyName)
  local src = source
  local lob = lobbies[lobbyName]
  if not lob then
    TriggerClientEvent('ox_lib:notify', src, {
      title       = "Speedway",
      description = locale("lobby_not_found"),
      type        = "error"
    })
    return
  end
  if lob.owner ~= src then
    TriggerClientEvent('ox_lib:notify', src, {
      title       = "Speedway",
      description = locale("not_authorized_to_start_race"),
      type        = "error"
    })
    return
  end

  lob.isStarted          = true
  lob.progress           = {}
  lob.checkpointProgress = {}
  lob.lapProgress        = {}
  lob.startTime          = {}
  lob.lapTimes           = {}
  lob.finished           = {}

  local now = GetGameTimer()
  for _, pid in ipairs(lob.players) do
    lob.startTime[pid]   = now
    lob.lapProgress[pid] = 0
    lob.lapTimes[pid]    = {}
  end

  if Config.Leaderboard and Config.Leaderboard.enabled then
    -- ─ Initialize AMIR leaderboard at race start ───────────────────
    do
      local names, times = {}, {}
      for i, pid in ipairs(lob.players) do
        names[i] = GetPlayerName(pid) or ""
        times[i] = 0
      end
      -- pad to exactly 9 entries
      for i = #names + 1, 9 do names[i], times[i] = "", 0 end
      -- show “1/totalLaps” instead of “0/totalLaps”
      local title = ("1/%d"):format(lob.laps)
      TriggerEvent("amir-leaderboard:setPlayerNames", title, names)
      TriggerEvent("amir-leaderboard:setPlayerTimes", title, times)
    end
    -- ───────────────────────────────────────────────────────────────
  end

  pendingChoices[lobbyName] = { total = #lob.players, received = 0, selected = {} }
  for _, pid in ipairs(lob.players) do
    TriggerClientEvent("speedway:chooseVehicle", pid, lobbyName)
  end
end)

--------------------------------------------------------------------------------
-- VEHICLE SELECTION RESPONSE
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:selectedVehicle", function(lobbyName, model)
    local src  = source
    local data = pendingChoices[lobbyName]
    local lob  = lobbies[lobbyName]

    if not data then
        print("[DEBUG] No pendingChoices for lobby:", lobbyName)
        return
    end

    if not lob then
        print("[DEBUG] No lobby found with name:", lobbyName)
        return
    end

    if model and not data.selected[src] then
        data.selected[src] = model
        data.received = data.received + 1
        print(("[DEBUG] Model '%s' saved for player %s. (%d/%d)"):format(
            model, src, data.received, data.total))
    else
        print("[DEBUG] Model already selected or invalid input.")
    end

    -- Kontroll: har alla spelare valt?
    if data.received == data.total then
        print("[DEBUG] All players have selected their vehicle.")
        pendingChoices[lobbyName] = nil

        for idx, pid in ipairs(lob.players) do
            local m = data.selected[pid]
            local sp = Config.GridSpawnPoints[idx]

            if not m then
                print("[DEBUG] Missing vehicle model for player:", pid)
                goto continue
            end

            local vec = vector4(sp.x, sp.y, sp.z, sp.w)

            -- 🧭 Teleportera spelare till sin plats innan fordon spawna
            TriggerClientEvent("speedway:client:teleportToStart", pid, vec)

            -- ⏱ Vänta på att klienten laddar platsen
            Wait(500)

            print(("[DEBUG] Spawning '%s' for player %s at grid index %d"):format(m, pid, idx))

            -- 🔍 Debug: Kolla avstånd
            local pedCoords = GetEntityCoords(GetPlayerPed(pid))
            print(("→ Spawning for %s at distance: %.2f"):format(pid, #(pedCoords - vec.xyz)))

            -- 🚗 Spawna fordon via qbx
            local netId, veh = qbx.spawnVehicle({
                model = m,
                spawnSource = vec,
                warp = GetPlayerPed(pid),
                bucket = GetPlayerRoutingBucket(pid)
            })

            if not veh then
                print(("[ERROR] Failed to spawn vehicle for player %s (model: %s)"):format(pid, m))
                goto continue
            end

            -- 🔑 Plåt & ownership
            local plate = "R0X" .. math.random(100, 999)
            SetVehicleNumberPlateText(veh, plate)

            TriggerClientEvent("speedway:client:fillFuel", pid, netId)
            TriggerClientEvent("vehiclekeys:client:SetOwner", pid, plate)
            TriggerClientEvent("speedway:prepareStart", pid, {
                track = lob.track,
                netId = netId,
                plate = plate,
                laps = lob.laps
            })

            ::continue::
        end

        -- Skicka gridorder till leaderboard
        TriggerEvent("speedway-leaderboard:server:setGridOrder", lobbyName, lob.players)
    else
        print(("[DEBUG] Waiting for more players... (%d/%d)"):format(data.received, data.total))
    end
end)


--------------------------------------------------------------------------------
-- LAP PASSED, LEADERBOARD UPDATE & RACE END
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:lapPassed", function(lobbyName, forcedSrc)
    local src = forcedSrc or source
    local lob = lobbies[lobbyName]
    if not lob then return end

    -- ✅ Skydd: Spelaren är redan i mål
    if lob.finished[src] then
        print(("[Speedway] %s (%s) already finished. Ignoring lap."):format(GetPlayerName(src), src))
        return
    end

    -- ➕ Öka varv
    lob.lapProgress[src] = (lob.lapProgress[src] or 0) + 1
    local curLap = lob.lapProgress[src]

    -- ⏱️ Spara varvtid
    local now = GetGameTimer()
    table.insert(lob.lapTimes[src], now - (lob.startTime[src] or now))
    lob.startTime[src] = now

    -- 🔁 Uppdatera klient om nuvarande varv
    TriggerClientEvent("speedway:updateLap", src, curLap, lob.laps)

    -- 📊 Leaderboard (AMIR)
    if Config.Leaderboard and Config.Leaderboard.enabled then
        local names, times = {}, {}
        for i, pid in ipairs(lob.players) do
            names[i] = GetPlayerName(pid) or ""
            local sum = 0
            for _, t in ipairs(lob.lapTimes[pid] or {}) do sum = sum + t end
            times[i] = sum
        end
        -- Pad till 9 platser
        for i = #names + 1, 9 do names[i], times[i] = "", 0 end
        local title = ("%d/%d"):format(curLap, lob.laps)
        TriggerEvent("amir-leaderboard:setPlayerNames", title, names)
        TriggerEvent("amir-leaderboard:setPlayerTimes", title, times)
    end

    -- 🏁 Om spelaren slutfört racet
    if curLap >= lob.laps then
        if not lob.finished[src] then
            lob.finished[src] = true

            -- Teleportera tillbaka
            TriggerClientEvent("speedway:client:finishTeleport", src, Config.outCoords)
            TriggerClientEvent("speedway:youFinished", src)

            -- Skicka spelarens resultat
            local totalT, best = 0, math.huge
            for _, t in ipairs(lob.lapTimes[src]) do
                totalT, best = totalT + t, math.min(best, t)
            end
            if best == math.huge then best = 0 end

            TriggerClientEvent("speedway:finalRanking", src, {
                position  = table_count(lob.finished),
                totalTime = totalT,
                lapTimes  = lob.lapTimes[src],
                bestLap   = best
            })
        end

        -- 📣 Kolla om alla är klara
        local allFin = true
        for _, pid in ipairs(lob.players) do
            if not lob.finished[pid] then allFin = false break end
        end

        -- 🏆 Visa resultat till alla, rensa lobby
        if allFin then
            local results = {}
            for _, pid in ipairs(lob.players) do
                local sum = 0
                for _, t in ipairs(lob.lapTimes[pid]) do sum = sum + t end
                table.insert(results, { id = pid, time = sum })
            end
            table.sort(results, function(a, b) return a.time < b.time end)

            for _, pid in ipairs(lob.players) do
                TriggerClientEvent("speedway:finalRanking", pid, { allResults = results })
                TriggerClientEvent("speedway:client:destroyprops", pid)
            end

            -- Rensa lobby
            lobbies[lobbyName] = nil
            TriggerClientEvent("speedway:setLobbyState", -1, next(lobbies) ~= nil)
        end
    end
end)

--------------------------------------------------------------------------------
-- FINISH TELEPORT, FUEL, ETC.
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:finishTeleport", function(coords)
  TriggerClientEvent("speedway:client:finishTeleport", source, coords)
end)

RegisterNetEvent("speedway:client:fillFuel", function(netId)
  local v = NetworkGetEntityFromNetworkId(netId)
  if not DoesEntityExist(v) then return end
  SetVehicleFuelLevel(v, 100.0)
  if GetResourceState("LegacyFuel")    == "started" then exports["LegacyFuel"]:SetFuel(v,100) end
  if GetResourceState("cdn-fuel")      == "started" then exports["cdn-fuel"]:SetFuel(v,100) end
  if GetResourceState("okokGasStation")== "started" then exports["okokGasStation"]:SetFuel(v,100) end
  if GetResourceState("ox_fuel")       == "started" then Entity(v).state.fuel = 100.0 end
end)

RegisterNetEvent("speedway:clientReady", function(lobbyName)
    local src = source
    if not readyClients[lobbyName] then
        readyClients[lobbyName] = {}
    end

    if not readyClients[lobbyName][src] then
        readyClients[lobbyName][src] = true
        readyCount = readyCount + 1
    end

    if readyCount >= #lobbies[lobbyName].players then
        -- alla är redo, skicka countdown till alla
        for _, pid in ipairs(lobbies[lobbyName].players) do
            TriggerClientEvent("speedway:startCountdown", pid)
        end
        readyClients[lobbyName] = nil
        readyCount = 0
    end
end)
