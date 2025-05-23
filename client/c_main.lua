-- client/c_main.lua

--------------------------------------------------------------------------------
-- 1) CONFIG & LOCALE
--------------------------------------------------------------------------------
local Config = require("config.config")
local function loc(key, ...)
    local t   = Config.Locales[Config.Locale] or {}
    local str = t[key] or key
    local args = { ... }
    return (str:gsub("{(%d+)}", function(n)
        return tostring(args[tonumber(n)] or "")
    end))
end

--------------------------------------------------------------------------------
-- 2) PULL IN QBCORE
--------------------------------------------------------------------------------
local QBCore = exports['qb-core']:GetCoreObject()

--------------------------------------------------------------------------------
-- 3) FUEL MODULE (moved to client/c_fuel.lua)
--------------------------------------------------------------------------------
-- SetFullFuel(veh) is defined in client/c_fuel.lua

--------------------------------------------------------------------------------
-- 4) RACE STATE
--------------------------------------------------------------------------------
local hasLobby             = false
local currentLobby         = nil
local currentTrack         = nil
local lobbyOwner           = nil
local currentProps         = {}
local currentLap = 0
local totalLaps  = 0
local myPosition           = 0
local totalRacers          = 0
local racerCheckpointIndex = 0   -- for lap logic (real checkpoints)
local racerRankpointIndex  = 0   -- for ranking logic (rank points)
local inRace               = false

--------------------------------------------------------------------------------
-- 5) TRACK POLYLINE HELPERS (project onto segments)
--------------------------------------------------------------------------------
local trackSegments = {}

local function BuildTrackSegments(trackName)
    trackSegments = {}
    local cps = Config.Checkpoints[trackName] or {}
    local cum = 0
    for i = 1, #cps - 1 do
        local a = vector3(cps[i].x, cps[i].y, cps[i].z)
        local b = vector3(cps[i+1].x, cps[i+1].y, cps[i+1].z)
        local segLen = #(b - a)
        table.insert(trackSegments, {
            start      = a,
            ['end']    = b,
            cumulative = cum,
            length     = segLen
        })
        cum = cum + segLen
    end
end

local function ComputeDistanceAlongTrack(pos)
    -- projects pos onto the nearest segment and returns along-track distance
    local bestDist2 = math.huge
    local bestAlong = 0
    for _, seg in ipairs(trackSegments) do
        local a, b = seg.start, seg['end']
        local ab = b - a
        local ap = pos - a
        local len2 = ab.x*ab.x + ab.y*ab.y + ab.z*ab.z
        if len2 > 0 then
            local t = (ap.x*ab.x + ap.y*ab.y + ap.z*ab.z) / len2
            if t < 0 then t = 0 elseif t > 1 then t = 1 end
            local proj = a + ab * t
            local d2 = #(pos - proj)^2
            if d2 < bestDist2 then
                bestDist2 = d2
                bestAlong = seg.cumulative + math.sqrt(len2) * t
            end
        end
    end
    return bestAlong
end

--------------------------------------------------------------------------------
-- 6) UNIVERSAL NOTIFY & ALERT
--------------------------------------------------------------------------------
local function SpeedwayNotify(title, description, ntype, duration)
    local provider = Config.NotificationProvider or "ox_lib"
    if provider == "okokNotify" then
        exports['okokNotify']:Alert(title or "", description or "", duration or 5000, ntype or "info")
    elseif provider == "ox_lib" then
        lib.notify({ title = title or "", description = description or "", type = ntype or "inform", position = "topLeft", duration = duration or 5000 })
    elseif provider == "rtx_notify" then
        exports['rtx_notify']:SendNotification({ title = title or "", text = description or "", icon = ntype or "info", length = duration or 5000, position = "topLeft" })
    else
        print(("[Speedway][%s] %s: %s"):format(provider, title or "Notice", description or ""))
    end
end

local function SpeedwayAlert(header, content, duration)
    local provider = Config.NotificationProvider or "ox_lib"
    if provider == "okokNotify" or provider == "ox_lib" then
        lib.alertDialog({ header = header or "", content = content or "", centered = true, duration = duration or 10000 })
    elseif provider == "rtx_notify" then
        exports['rtx_notify']:SendNotification({ title = header or "", text = content or "", icon = "info", length = duration or 10000 })
    else
        lib.notify({ title = header or "", description = content or "", type = "error", position = "topLeft", duration = duration or 5000 })
    end
end

--------------------------------------------------------------------------------
-- 7) COUNTDOWN UI
--------------------------------------------------------------------------------
function ShowCountdownText(text, duration)
    local endTime = GetGameTimer() + duration
    while GetGameTimer() < endTime do
        SetTextFont(4); SetTextScale(1.5,1.5); SetTextCentre(true)
        SetTextDropshadow(0,0,0,0,255)
        BeginTextCommandDisplayText("STRING")
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandDisplayText(0.5,0.4)
        Wait(0)
    end
end

--------------------------------------------------------------------------------
-- 8) LOBBY PED & TARGET SETUP
--------------------------------------------------------------------------------
CreateThread(function()
    local cfg = Config.LobbyPed
    RequestModel(cfg.model)
    while not HasModelLoaded(cfg.model) do Wait(0) end

    local ped = CreatePed(0, cfg.model, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.coords.w, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            { event = 'speedway:client:createLobby', icon = 'fa-solid fa-flag-checkered', label = loc("create_lobby"), canInteract = function() return not hasLobby end },
            { event = 'speedway:client:joinLobby',   icon = 'fa-solid fa-user-plus',         label = loc("join_lobby"),   canInteract = function() return hasLobby and not currentLobby end },
            { event = 'speedway:client:startRace',   icon = 'fa-solid fa-flag-checkered',   label = loc("start_race"),    canInteract = function() return currentLobby and lobbyOwner == GetPlayerServerId(PlayerId()) end },
            { event = 'speedway:client:leaveLobby',  icon = 'fa-solid fa-sign-out-alt',     label = loc("leave_lobby"),   canInteract = function() return currentLobby end },
        },
        distance = 2.5
    })

    local blip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
    SetBlipSprite(blip, 315); SetBlipDisplay(blip, 4); SetBlipScale(blip, 0.8); SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING"); AddTextComponentString("Roxwood Speedway"); EndTextCommandSetBlipName(blip)
end)

--------------------------------------------------------------------------------
-- 9) LOBBY STATE HANDLERS
--------------------------------------------------------------------------------
RegisterNetEvent('speedway:setLobbyState', function(state)
    hasLobby = state
    if not state then currentLobby, lobbyOwner = nil, nil end
end)
RegisterNetEvent('speedway:updateLobbyInfo', function(info)
    if info and info.name then
        hasLobby     = true
        currentLobby = info.name
        lobbyOwner   = info.owner
        totalLaps      = info.laps
    else
        hasLobby, currentLobby, lobbyOwner = false, nil, nil
        totalLaps      = 0
    end
end)

--------------------------------------------------------------------------------
-- 10) CREATE / JOIN / START / LEAVE
--------------------------------------------------------------------------------
RegisterNetEvent('speedway:client:createLobby', function()
    local dialog = exports['qb-input']:ShowInput({
        header     = loc("create_lobby"),
        submitText = loc("submit"),
        inputs     = {
            { text = loc("number_of_laps"), name = "lapCount", type = "number", isRequired = true, min = 1, max = 10, default = 3 },
            { text = loc("select_track"),   name = "trackType", type = "select", isRequired = true, default = "Short_Track",
              options = {
                  { value = "Short_Track", text = loc("Short_Track") },
                  { value = "Drift_Track",  text = loc("Drift_Track")  },
                  { value = "Speed_Track",  text = loc("Speed_Track")  },
                  { value = "Long_Track",   text = loc("Long_Track")   },
              },
            },
        },
    })
    if not dialog then return end

    local lapCount  = tonumber(dialog.lapCount) or 1
    local trackType = dialog.trackType
    local lobbyName = GetPlayerName(PlayerId()) .. "_" .. math.random(1000,9999)
    TriggerServerEvent("speedway:createLobby", lobbyName, trackType, lapCount)
end)

RegisterNetEvent('speedway:client:joinLobby', function()
    local lobbies = lib.callback.await("speedway:getLobbies", true)
    if not lobbies or #lobbies == 0 then
        SpeedwayNotify(loc("no_lobbies"), "", "error")
        return
    end
    local opts = {}
    for _, e in ipairs(lobbies) do table.insert(opts, { value = e.value, text = e.label }) end
    local dialog = exports['qb-input']:ShowInput({
        header     = loc("join_lobby"),
        submitText = loc("submit"),
        inputs     = {{ text = loc("select_lobby"), name = "selectedLobby", type = "select", isRequired = true, options = opts }},
    })
    if dialog and dialog.selectedLobby then
        TriggerServerEvent("speedway:joinLobby", dialog.selectedLobby)
    end
end)

RegisterNetEvent('speedway:client:startRace', function()
    if lobbyOwner ~= GetPlayerServerId(PlayerId()) then
        SpeedwayNotify("", loc("not_authorized_to_start_race"), "error")
        return
    end
    local players = lib.callback.await("speedway:getLobbyPlayers", false, currentLobby)
    local names   = {}
    for _, sid in ipairs(players) do
        local pid   = GetPlayerFromServerId(sid)
        local pname = pid and GetPlayerName(pid) or ("ID"..sid)
        table.insert(names, pname)
    end
    SpeedwayNotify(loc("lobby_preview"), table.concat(names, "\n"), "inform", 10000)
    TriggerServerEvent("speedway:startRace", currentLobby)
end)

RegisterNetEvent('speedway:client:leaveLobby', function()
    if not hasLobby then
        SpeedwayNotify(loc("no_lobby_joined"), loc("no_lobby_joined_desc"), "error")
        return
    end
    TriggerServerEvent("speedway:leaveLobby", currentLobby)
end)

--------------------------------------------------------------------------------
-- 11) VEHICLE SELECTION
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:chooseVehicle", function(lobbyName)
    local opts = {}
    for _, v in ipairs(Config.RaceVehicles) do
        table.insert(opts, { value = v.model, text = v.label })
    end
    local dialog = exports['qb-input']:ShowInput({
        header     = loc("choose_vehicle_title"),
        submitText = loc("submit"),
        inputs     = {{
            text       = loc("choose_vehicle_label"),
            name       = "selectedModel",
            type       = "select",
            isRequired = true,
            options    = opts,
            default    = opts[1].value
        }},
    })
    local sel = dialog and dialog.selectedModel or nil
    TriggerServerEvent("speedway:selectedVehicle", lobbyName, sel)
end)

--------------------------------------------------------------------------------
-- 12) PREPARE & START THE RACE (SPAWN + COUNTDOWN)
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:prepareStart", function(data)
    inRace       = true
    currentTrack = data.track
    currentLap    = 1

    -- clear old props
    TriggerEvent("speedway:client:destroyprops")

    -- spawn new props
    for _, pd in ipairs(Config.TrackProps[data.track] or {}) do
        RequestModel(pd.prop); while not HasModelLoaded(pd.prop) do Wait(0) end
        for _, c in ipairs(pd.cords) do
            local obj = CreateObject(pd.prop, c.x, c.y, c.z - 1.0, false, false, false)
            PlaceObjectOnGroundProperly(obj); SetEntityHeading(obj, c.w); FreezeEntityPosition(obj, true)
            table.insert(currentProps, obj)
        end
    end

    -- build our segment list from checkpoints
    BuildTrackSegments(data.track)
    print(("[Speedway][DEBUG] Built %d track segments for track %q"):format(#trackSegments, data.track))

    -- RESET BOTH INDICES
    racerCheckpointIndex = 0
    racerRankpointIndex  = 0

    -- 1) LAP‐CHECKPOINT SPHERES
    for idx, coord in ipairs(Config.Checkpoints[currentTrack] or {}) do
        local cpRadius = (idx == 2) and 25.0 or 15.0  -- apex larger, adjust to taste
        lib.zones.sphere({
            coords = coord,
            radius = 10.0,
            debug  = Config.debug,
            onEnter = function()
                if idx == racerCheckpointIndex + 1 then
                    racerCheckpointIndex = idx
                end
            end
        })
    end

    -- 2) RANKPOINT SPHERES
    for idx, coord in ipairs(Config.RankingPoints[currentTrack] or {}) do
        local rad = (idx == 1) and 10.0 or 15.0
        lib.zones.sphere({
            coords = coord,
            radius = rad,
            debug  = Config.debug,
            onEnter = function()
                if idx == racerRankpointIndex + 1 then
                    racerRankpointIndex = idx
                end
            end
        })
    end

    -- finish line zone
    lib.zones.sphere({
        name   = "finish_line",
        coords = Config.FinishLine.coords,
        radius = Config.FinishLine.radius,
        debug  = Config.debug,
        onEnter = function()
            print(("[Speedway][DEBUG] finish_line onEnter; cpIndex=%d/%d"):format(
                racerCheckpointIndex, #Config.Checkpoints[currentTrack]
            ))
            if racerCheckpointIndex == #Config.Checkpoints[currentTrack] then
                racerCheckpointIndex = 0
                TriggerServerEvent("speedway:lapPassed", currentLobby, GetPlayerServerId(PlayerId()))
            end
        end
    })

    -- spawn & race
    CreateThread(function()
        while not NetworkDoesNetworkIdExist(data.netId) do Wait(0) end
        local veh = NetworkGetEntityFromNetworkId(data.netId)
        while not DoesEntityExist(veh) do Wait(0); veh = NetworkGetEntityFromNetworkId(data.netId) end

        SetEntityAsMissionEntity(veh, true, true)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        repeat Wait(0) until IsPedInAnyVehicle(PlayerPedId(), false)
        FreezeEntityPosition(veh, true)

        for i = 3, 1, -1 do ShowCountdownText(tostring(i), 1000) end
        ShowCountdownText("GO", 1000)
        FreezeEntityPosition(veh, false)

        SetFullFuel(veh)

        -- random mods…
        SetVehicleModKit(veh, 0)
        local perfSlots = {11,12,13,15,16}
        for _, slot in ipairs(perfSlots) do
            local maxIndex = GetNumVehicleMods(veh, slot) - (slot == 15 and 2 or 1)
            if maxIndex >= 0 then
                SetVehicleMod(veh, slot, maxIndex, false)
            end
        end
        ToggleVehicleMod(veh, 17, true)
        ToggleVehicleMod(veh, 18, true)
        ToggleVehicleMod(veh, 19, true)
        ToggleVehicleMod(veh, 21, true)

        SetVehicleModKit(veh, 0)
        for i = 1, 47 do
            SetVehicleMod(veh, i, math.random(1, 4), true)
        end
        SetVehicleMod(veh, 49, math.random(1, 4), true)

        -- REPORT PROGRESS TO speedway-leaderboard instead of our own server
        CreateThread(function()
            while inRace do
                local v = GetVehiclePedIsIn(PlayerPedId(), false)
                if v and v ~= 0 then
                    local coords    = GetEntityCoords(v)
                    local rawDist   = ComputeDistanceAlongTrack(coords)
                    local startCP   = Config.Checkpoints[currentTrack][1]
                    local startPos  = vector3(startCP.x, startCP.y, startCP.z)
                    local planarDist= #(coords - startPos)
                    TriggerServerEvent(
                        'speedway-leaderboard:server:updateProgress',
                        currentLobby,
                        rawDist,
                        racerRankpointIndex,
                        planarDist
                    )
                end
                Wait(200)
            end
        end)
    end)
end)

--------------------------------------------------------------------------------
-- 13) LAP & FINISH TOASTS
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:updateLap", function(cur, tot)
    currentLap = cur + 1
    totalLaps  = tot
    SpeedwayNotify("🏁 Speedway", ("Lap %s/%s"):format(cur, tot), "inform", 3000)
end)
RegisterNetEvent("speedway:youFinished", function()
    SpeedwayNotify("🏁 Speedway", loc("you_finished"), "success", 5000)
end)

--------------------------------------------------------------------------------
-- 14) FINAL RANKING
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:finalRanking", function(data)
    local results = data.allResults or {}
    if not data.position then
        local lines = { loc("podium_header") }
        for i,e in ipairs(results) do
            local name = GetPlayerName(GetPlayerFromServerId(e.id)) or ("ID"..e.id)
            lines[#lines+1] = ("%d. %s — %ds"):format(i, name, math.floor(e.time/1000))
        end
        SpeedwayNotify("", table.concat(lines, "\n"), "inform", 10000)
        return
    end

    local totalTime = math.floor((data.totalTime or 0)/1000)
    if data.position == 1 then
        SpeedwayNotify("🏆 Speedway", loc("you_won", totalTime), "success", 5000)
    else
        SpeedwayNotify("🏁 Speedway", loc("you_placed", data.position, #results, totalTime), "inform", 5000)
    end
    if data.lapTimes then
        local lapLines = { loc("lap_summary") }
        for i,t in ipairs(data.lapTimes) do
            lapLines[#lapLines+1] = loc("lap_time", i, math.floor(t/1000))
        end
        lapLines[#lapLines+1] = loc("best_lap", math.floor((data.bestLap or 0)/1000))
        SpeedwayNotify(loc("lap_summary"), table.concat(lapLines, "\n"), "info", 10000)
    end
end)

--------------------------------------------------------------------------------
-- 15) FINISH TELEPORT
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:client:finishTeleport", function(coords)
    inRace = false
    CreateThread(function()
        DoScreenFadeOut(1000); while not IsScreenFadedOut() do Wait(0) end

        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local v = GetVehiclePedIsIn(ped, false)
            TaskLeaveVehicle(ped, v, 0); Wait(500)
            if DoesEntityExist(v) then DeleteVehicle(v) end
        end

        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
        SetEntityHeading(ped, coords.w)
        Wait(500); DoScreenFadeIn(1000)
    end)
end)

--------------------------------------------------------------------------------
-- 16) FUEL AUTO-FILL EVENT
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:client:fillFuel", function(netId)
    local v = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(v) then SetFullFuel(v) end
end)

--------------------------------------------------------------------------------
-- 17) RANK & POSITION HANDLERS
--------------------------------------------------------------------------------
RegisterNetEvent('speedway-leaderboard:client:updateRank', function(rank, total)
    print(("[Speedway][HUD] got updateRank → %d/%d"):format(rank, total))
    myPosition  = rank
    totalRacers = total
end)

-- 18) RANK & POSITION HUD (native DrawText, solid, bottom-center)
CreateThread(function()
    while true do
        Wait(0)
        if inRace then
            -- draw lap counter
            SetTextFont(4); SetTextScale(0.5,0.5); SetTextCentre(true)
            SetTextColour(255,255,255,255); SetTextOutline()
            BeginTextCommandDisplayText("STRING")
            AddTextComponentSubstringPlayerName(("Lap %d / %d"):format(currentLap, totalLaps))
            EndTextCommandDisplayText(0.5, 0.92)

            -- draw position (exactly as before)
            SetTextFont(4); SetTextScale(0.5,0.5); SetTextCentre(true)
            SetTextColour(255,255,255,255); SetTextOutline()
            BeginTextCommandDisplayText("STRING")
            AddTextComponentSubstringPlayerName(("Position %d / %d"):format(myPosition, totalRacers))
            EndTextCommandDisplayText(0.5, 0.95)
        end
    end
end)

