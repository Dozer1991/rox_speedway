-- c_main.lua

local Config = require("config.config")

--------------------------------------------------------------------------------
-- 1) locale helper
--------------------------------------------------------------------------------
local function loc(key, ...)
    local t   = Config.Locales[Config.Locale] or {}
    local str = t[key] or key
    local args = { ... }
    return (str:gsub("{(%d+)}", function(n)
        return tostring(args[tonumber(n)] or "")
    end))
end

--------------------------------------------------------------------------------
-- 2) Pull in QBCore
--------------------------------------------------------------------------------
local QBCore = exports['qb-core']:GetCoreObject()

--------------------------------------------------------------------------------
-- RACE STATE (must come before ComputeDistanceAlongTrack!)
--------------------------------------------------------------------------------
local hasLobby             = false
local currentLobby         = nil
local currentTrack         = nil
local lobbyOwner           = nil
local currentProps         = {}
local racerCheckpointIndex = 0

-- in-race HUD
local inRace      = false
local myPosition  = 0
local totalRacers = 0

--------------------------------------------------------------------------------
-- Compute an approximate “distance along track”
--------------------------------------------------------------------------------
local function ComputeDistanceAlongTrack(pos)
    local track = currentTrack and Config.Checkpoints[currentTrack]
    if not track then return 0 end

    -- find nearest checkpoint
    local nearestDist, nearestIdx = math.huge, 1
    for i, cp in ipairs(track) do
        local cpVec = vector3(cp.x, cp.y, cp.z)
        local d     = #(pos - cpVec)
        if d < nearestDist then
            nearestDist, nearestIdx = d, i
        end
    end

    -- sum segments before that
    local total = 0
    for i = 1, nearestIdx - 1 do
        local a = track[i]
        local b = track[i+1]
        total = total + #(vector3(a.x,a.y,a.z) - vector3(b.x,b.y,b.z))
    end

    return total + nearestDist
end

--------------------------------------------------------------------------------
-- UNIVERSAL TOAST-STYLE NOTIFY
--------------------------------------------------------------------------------
local function SpeedwayNotify(title, description, ntype, duration)
    local provider = Config.NotificationProvider or "ox_lib"

    if provider == "okokNotify" then
        exports['okokNotify']:Alert(
            title        or "",
            description  or "",
            duration     or 5000,
            ntype        or "info",
            "topLeft"
        )

    elseif provider == "ox_lib" then
        lib.notify({
            title       = title        or "",
            description = description  or "",
            type        = ntype        or "inform",
            position    = "topLeft",
            duration    = duration     or 5000,
        })

    elseif provider == "rtx_notify" then
        exports['rtx_notify']:SendNotification({
            title    = title        or "",
            text     = description  or "",
            icon     = ntype        or "info",
            length   = duration     or 5000,
            position = "topLeft"
        })

    else
        print(("[Speedway][%s] %s: %s")
            :format(provider, title or "Notice", description or ""))
    end
end

--------------------------------------------------------------------------------
-- FULL-SCREEN ALERT
--------------------------------------------------------------------------------
local function SpeedwayAlert(header, content, duration)
    local provider = Config.NotificationProvider or "ox_lib"

    if provider == "okokNotify" or provider == "ox_lib" then
        lib.alertDialog({
            header   = header   or "",
            content  = content  or "",
            centered = true,
            duration = duration or 10000,
        })

    elseif provider == "rtx_notify" then
        exports['rtx_notify']:SendNotification({
            title  = header   or "",
            text   = content  or "",
            icon   = "info",
            length = duration or 10000,
        })

    else
        lib.notify({
            title       = header   or "",
            description = content  or "",
            type        = "error",
            position    = "topLeft",
            duration    = duration or 5000,
        })
    end
end

--------------------------------------------------------------------------------
-- Show big centered countdown text
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
-- RECEIVE LIVE POSITION UPDATES FROM SERVER
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:updatePosition", function(pos, total)
    myPosition  = pos
    totalRacers = total
end)

--------------------------------------------------------------------------------
-- CLEAN UP PROPS ON RESOURCE START
--------------------------------------------------------------------------------
AddEventHandler('onResourceStart', function(resName)
    if resName == GetCurrentResourceName() then
        TriggerEvent("speedway:client:destroyprops")
    end
end)

RegisterNetEvent('speedway:client:destroyprops', function()
    for _, obj in ipairs(currentProps) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    currentProps = {}
end)

--------------------------------------------------------------------------------
-- LOBBY PED & TARGET SETUP
--------------------------------------------------------------------------------
CreateThread(function()
    local cfg = Config.LobbyPed
    RequestModel(cfg.model)
    while not HasModelLoaded(cfg.model) do Wait(0) end

    local ped = CreatePed(0, cfg.model,
        cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0,
        cfg.coords.w, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            {
                event       = 'speedway:client:createLobby',
                icon        = 'fa-solid fa-flag-checkered',
                label       = loc("create_lobby"),
                canInteract = function() return not hasLobby end
            },
            {
                event       = 'speedway:client:joinLobby',
                icon        = 'fa-solid fa-user-plus',
                label       = loc("join_lobby"),
                canInteract = function() return hasLobby and not currentLobby end
            },
            {
                event       = 'speedway:client:startRace',
                icon        = 'fa-solid fa-flag-checkered',
                label       = loc("start_race"),
                canInteract = function() return currentLobby and lobbyOwner == GetPlayerServerId(PlayerId()) end
            },
            {
                event       = 'speedway:client:leaveLobby',
                icon        = 'fa-solid fa-sign-out-alt',
                label       = loc("leave_lobby"),
                canInteract = function() return currentLobby end
            },
        },
        distance = 2.5
    })

    local blip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
    SetBlipSprite(blip, 315)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Roxwood Speedway")
    EndTextCommandSetBlipName(blip)
end)

--------------------------------------------------------------------------------
-- PLAYER JOINED TOAST
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:client:playerJoined", function(playerName)
    SpeedwayNotify(
      loc("player_joined_title"),
      loc("player_joined", playerName),
      "inform",
      5000
    )
end)

--------------------------------------------------------------------------------
-- LOBBY STATE HANDLERS
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
    else
        hasLobby, currentLobby, lobbyOwner = false, nil, nil
    end
end)

--------------------------------------------------------------------------------
-- CREATE / JOIN / START / LEAVE (client-side)
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
    for _, e in ipairs(lobbies) do
        table.insert(opts, { value = e.value, text = e.label })
    end

    local dialog = exports['qb-input']:ShowInput({
        header     = loc("join_lobby"),
        submitText = loc("submit"),
        inputs     = {
            { text = loc("select_lobby"), name = "selectedLobby", type = "select", isRequired = true, options = opts }
        },
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
    local names = {}
    for _, sid in ipairs(players) do
        local idx   = GetPlayerFromServerId(sid)
        local pname = idx and GetPlayerName(idx) or ("ID"..sid)
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
-- VEHICLE SELECTION
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
-- RACE PREP, CHECKPOINTS & PROGRESS REPORTER
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:prepareStart", function(data)
    inRace       = true
    currentTrack = data.track

    -- spawn props
    for _, pd in ipairs(Config.TrackProps[data.track] or {}) do
        RequestModel(pd.prop); while not HasModelLoaded(pd.prop) do Wait(0) end
        for _, c in ipairs(pd.cords) do
            local obj = CreateObject(pd.prop, c.x, c.y, c.z - 1.0, false, false, false)
            PlaceObjectOnGroundProperly(obj)
            SetEntityHeading(obj, c.w); FreezeEntityPosition(obj, true)
            table.insert(currentProps, obj)
        end
    end

    -- checkpoint spheres
    racerCheckpointIndex = 0
    for idx, coord in ipairs(Config.Checkpoints[data.track] or {}) do
        lib.zones.sphere({
            coords = coord,
            radius = 15.0,
            debug  = Config.debug,
            onEnter = function()
                if idx == racerCheckpointIndex + 1 then
                    racerCheckpointIndex = idx
                    TriggerServerEvent("speedway:checkpointPassed", currentLobby, idx)
                end
            end
        })
    end

    -- finish line as configurable sphere
    lib.zones.sphere({
        name   = "finish_line",
        coords = Config.FinishLine.coords,
        radius = Config.FinishLine.radius,
        debug  = Config.debug,
        onEnter = function()
            if racerCheckpointIndex == #Config.Checkpoints[data.track] then
                racerCheckpointIndex = 0
                TriggerServerEvent("speedway:lapPassed", currentLobby, GetPlayerServerId(PlayerId()))
            end
        end
    })

    -- countdown → warp → live progress loop
    CreateThread(function()
        Wait(200)
        while not NetworkDoesNetworkIdExist(data.netId) do Wait(0) end
        local veh = NetworkGetEntityFromNetworkId(data.netId)
        while not DoesEntityExist(veh) do Wait(0); veh = NetworkGetEntityFromNetworkId(data.netId) end

        -- **IMMEDIATE FUEL RESET**
        SetVehicleFuelLevel(veh, 100.0)
        if GetResourceState("LegacyFuel")    == "started" then exports["LegacyFuel"]:SetFuel(veh,100) end
        if GetResourceState("cdn-fuel")      == "started" then exports["cdn-fuel"]:SetFuel(veh,100) end
        if GetResourceState("okokGasStation")== "started" then exports["okokGasStation"]:SetFuel(veh,100) end
        if GetResourceState("ox_fuel")       == "started" then Entity(veh).state.fuel = 100.0 end

        SetEntityAsMissionEntity(veh, true, true)
        FreezeEntityPosition(veh, true)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        repeat Wait(0) until IsPedInAnyVehicle(PlayerPedId(), false)

        for i = 3, 1, -1 do ShowCountdownText(tostring(i), 1000) end
        ShowCountdownText("GO", 1000)
        FreezeEntityPosition(veh, false)

        -- repeatedly slam the tank back to 100% for the first 5 seconds
        CreateThread(function()
            local tries = 0
            while tries < 5 do
                if DoesEntityExist(veh) then
                    SetVehicleFuelLevel(veh, 100.0)
                    if GetResourceState("LegacyFuel")    == "started" then exports["LegacyFuel"]:SetFuel(veh,100) end
                    if GetResourceState("cdn-fuel")      == "started" then exports["cdn-fuel"]:SetFuel(veh,100) end
                    if GetResourceState("okokGasStation")== "started" then exports["okokGasStation"]:SetFuel(veh,100) end
                    if GetResourceState("ox_fuel")       == "started" then Entity(veh).state.fuel = 100.0 end
                end
                tries = tries + 1
                Wait(1000)
            end
        end)

        CreateThread(function()
            while inRace do
                local v = GetVehiclePedIsIn(PlayerPedId(), false)
                if v and v ~= 0 then
                    local dist = ComputeDistanceAlongTrack(GetEntityCoords(v))
                    TriggerServerEvent("speedway:updateProgress", currentLobby, dist)
                end
                Wait(200)
            end
        end)
    end)
end)

--------------------------------------------------------------------------------
-- LAP & FINISH NOTIFICATIONS
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:updateLap", function(cur, tot)
    SpeedwayNotify("🏁 Speedway", ("Lap %s/%s"):format(cur, tot), "inform", 3000)
end)
RegisterNetEvent("speedway:youFinished", function()
    SpeedwayNotify("🏁 Speedway", loc("you_finished"), "success", 5000)
end)

--------------------------------------------------------------------------------
-- FINAL RANKING
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:finalRanking", function(data)
    local results = data.allResults or {}
    if not data.position then
        local lines = { loc("podium_header") }
        for i, e in ipairs(results) do
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
        for i, t in ipairs(data.lapTimes) do
            lapLines[#lapLines+1] = loc("lap_time", i, math.floor(t/1000))
        end
        lapLines[#lapLines+1] = loc("best_lap", math.floor((data.bestLap or 0)/1000))
        SpeedwayNotify(loc("lap_summary"), table.concat(lapLines, "\n"), "info", 10000)
    end
end)

--------------------------------------------------------------------------------
-- FINISH TELEPORT (fade → delete → teleport → fade)
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:client:finishTeleport", function(coords)
    inRace = false
    CreateThread(function()
        DoScreenFadeOut(1000)
        while not IsScreenFadedOut() do Wait(0) end

        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local v = GetVehiclePedIsIn(ped, false)
            TaskLeaveVehicle(ped, v, 0)
            Wait(500)
            if DoesEntityExist(v) then DeleteVehicle(v) end
        end

        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
        SetEntityHeading(ped, coords.w)

        Wait(500)
        DoScreenFadeIn(1000)
    end)
end)

--------------------------------------------------------------------------------
-- FUEL AUTO-DETECT
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:client:fillFuel", function(netId)
    CreateThread(function()
        Wait(200)
        local v = NetworkGetEntityFromNetworkId(netId)
        if not DoesEntityExist(v) then return end
        SetVehicleFuelLevel(v, 100.0)
        if GetResourceState("LegacyFuel")    == "started" then exports["LegacyFuel"]:SetFuel(v,100) end
        if GetResourceState("cdn-fuel")      == "started" then exports["cdn-fuel"]:SetFuel(v,100) end
        if GetResourceState("okokGasStation")== "started" then exports["okokGasStation"]:SetFuel(v,100) end
        if GetResourceState("ox_fuel")       == "started" then Entity(v).state.fuel = 100.0 end
    end)
end)

--------------------------------------------------------------------------------
-- DRAW “Pos X/Y” HUD
--------------------------------------------------------------------------------
--[[
CreateThread(function()
    while true do
        Wait(0)
        if inRace then
            SetTextFont(4); SetTextScale(0.5,0.5); SetTextCentre(true)
            SetTextColour(255,255,255,255); SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString( ("%d/%d"):format(myPosition, totalRacers) )
            DrawText(0.5, 0.95)
        end
    end
end)
]]--