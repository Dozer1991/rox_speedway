local QBCore = exports['qb-core']:GetCoreObject()
lib.locale()
local config = require "config.shared"

local notifyProvider = config.NotificationProvider or "ox_lib"

--- Universal notify(title,desc,type,duration)
local function SpeedwayNotify(title, description, ntype, duration)
    if notifyProvider == "okokNotify" then
        -- okokNotify: Alert(header, text, duration, type, position)
        exports['okokNotify']:Alert(
            title or "",
            description or "",
            duration or 5000,
            ntype   or "info",
            "bottomRight"
        )
    else
        -- ox_lib: notify with {title,description,type}
        lib.notify({
            title       = title or "",
            description = description or "",
            type        = ntype   or "inform"
        })
    end
end

--- Universal alertPopup(header,content,duration)
local function SpeedwayAlert(header, content, duration)
    if notifyProvider == "okokNotify" then
        exports['okokNotify']:Alert(
            header    or "",
            content   or "",
            duration  or 10000,
            "info",
            "bottomRight"
        )
    else
        lib.alertDialog({
            header   = header    or "",
            content  = content   or "",
            centered = true
        })
    end
end

-- helper to show big centered text for a given duration (in ms)
function ShowCountdownText(text, duration)
    local endTime = GetGameTimer() + duration
    while GetGameTimer() < endTime do
        SetTextFont(4)
        SetTextScale(1.5, 1.5)
        SetTextCentre(true)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(0.5, 0.4)  -- centered near top/middle
        Wait(0)
    end
end


-- track whether we’re in a lobby, what its name is, and who the host is
local hasLobby     = false
local currentLobby = nil
local lobbyOwner   = nil
local currentProps = {}
local hasPassed    = false

-- clean up spawned props on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        TriggerEvent("speedway:client:destroyprops")
    end
end)

RegisterNetEvent('speedway:client:destroyprops', function()
    for _, obj in ipairs(currentProps) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    currentProps = {}
end)

--------------------------------------------------------------------------------
-- LOBBY STATE HANDLERS
--------------------------------------------------------------------------------
RegisterNetEvent('speedway:setLobbyState', function(state)
    hasLobby = state
    if not state then
        currentLobby = nil
        lobbyOwner   = nil
    end
end)

RegisterNetEvent('speedway:updateLobbyInfo', function(info)
    if info and info.name then
        hasLobby     = true
        currentLobby = info.name
        lobbyOwner   = info.owner
    else
        hasLobby     = false
        currentLobby = nil
        lobbyOwner   = nil
    end
end)

--------------------------------------------------------------------------------
-- LOBBY PED & TARGET SETUP
--------------------------------------------------------------------------------
CreateThread(function()
    local cfg = config.LobbyPed
    RequestModel(cfg.model)
    while not HasModelLoaded(cfg.model) do Wait(0) end

    local ped = CreatePed(0, cfg.model, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.coords.w, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            { event = 'speedway:client:createLobby', icon = 'fa-solid fa-flag-checkered', label = locale('create_lobby') },
            { event = 'speedway:client:joinLobby',   icon = 'fa-solid fa-user-plus',      label = locale('join_lobby') },
            { event = 'speedway:client:startRace',   icon = 'fa-solid fa-flag-checkered', label = locale('start_race') },
            { event = 'speedway:client:leaveLobby',  icon = 'fa-solid fa-sign-out-alt',   label = locale('leave_lobby') },
        },
        distance = 2.5
    })
end)

--------------------------------------------------------------------------------
-- CREATE LOBBY
--------------------------------------------------------------------------------
RegisterNetEvent('speedway:client:createLobby', function()
    local dialog = exports['qb-input']:ShowInput({
        header     = locale("create_lobby"),
        submitText = locale("submit"),
        inputs     = {
            {
                text       = locale("number_of_laps"),
                name       = "lapCount",
                type       = "number",
                isRequired = true,
                min        = 1,
                max        = 10,
                default    = 3,
            },
            {
                text       = locale("select_track"),
                name       = "trackType",
                type       = "select",
                isRequired = true,
                default    = "Short_Track",
                options    = {
                    { value = "Short_Track", text = locale("Short_Track") },
                    { value = "Drift_Track",  text = locale("Drift_Track")  },
                    { value = "Speed_Track",  text = locale("Speed_Track")  },
                    { value = "Long_Track",   text = locale("Long_Track")   },
                },
            },
        },
    })
    if not dialog then return end

    local lapCount   = tonumber(dialog.lapCount) or 1
    local trackType  = dialog.trackType
    local playerName = GetPlayerName(PlayerId())
    local lobbyName  = playerName .. "_" .. math.random(1000,9999)

    TriggerServerEvent("speedway:createLobby", lobbyName, trackType, lapCount)
end)

--------------------------------------------------------------------------------
-- JOIN LOBBY
--------------------------------------------------------------------------------
RegisterNetEvent('speedway:client:joinLobby', function()
    print("[speedway] -> client:joinLobby event fired")

    local lobbies = lib.callback.await("speedway:getLobbies", true)
    print(("[speedway] -> got %d lobbies"):format(lobbies and #lobbies or 0))

    if not lobbies or #lobbies == 0 then
        SpeedwayNotify(locale("no_lobbies"), "", "error")
        return
    end

    local options = {}
    for _, entry in ipairs(lobbies) do
        table.insert(options, { value = entry.value, text = entry.label })
    end

    local dialog = exports['qb-input']:ShowInput({
        header     = locale("join_lobby"),
        submitText = locale("submit"),
        inputs     = {
            {
                text       = locale("select_lobby"),
                name       = "selectedLobby",
                type       = "select",
                isRequired = true,
                options    = options,
            }
        },
    })

    if dialog and dialog.selectedLobby then
        print("[speedway] -> requesting join:", dialog.selectedLobby)
        TriggerServerEvent("speedway:joinLobby", dialog.selectedLobby)
    end
end)

--------------------------------------------------------------------------------
-- START RACE
--------------------------------------------------------------------------------
RegisterNetEvent('speedway:client:startRace', function()
    if lobbyOwner ~= GetPlayerServerId(PlayerId()) then
        SpeedwayNotify("", locale("not_authorized_to_start_race"), "error")
        return
    end
    TriggerServerEvent("speedway:startRace", currentLobby)
end)

--------------------------------------------------------------------------------
-- LEAVE LOBBY
--------------------------------------------------------------------------------
RegisterNetEvent('speedway:client:leaveLobby', function()
    if not hasLobby or not currentLobby then
        SpeedwayNotify(locale("no_lobby_joined"), locale("no_lobby_joined_desc"), "error")
        return
    end
    TriggerServerEvent("speedway:leaveLobby", currentLobby)
end)

--------------------------------------------------------------------------------
-- VEHICLE CHOICE CALLBACK (using qb-input)
--------------------------------------------------------------------------------
lib.callback.register("speedway:getVehicleChoice", function(_, cb)
    local opts = {}
    for _, v in ipairs(config.RaceVehicles) do
        table.insert(opts, { value = v.model, text = v.label })
    end

    local dialog = exports['qb-input']:ShowInput({
        header     = locale("choose_vehicle_title"),
        submitText = locale("submit"),
        inputs     = {
            {
                text       = locale("choose_vehicle_label"),
                name       = "selectedModel",
                type       = "select",
                isRequired = true,
                options    = opts,
                default    = opts[1].value,
            }
        },
    })

    if dialog and dialog.selectedModel then
        print("[speedway] CLIENT got vehicle choice:", dialog.selectedModel)
        return dialog.selectedModel
    end
    return nil
end)

--------------------------------------------------------------------------------
-- RACE PREPARATION & EVENTS
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:prepareStart", function(data)
    -- spawn track props
    local props = config.TrackProps[data.track]
    if props then
        for _, propData in ipairs(props) do
            for _, coord in ipairs(propData.cords) do
                local obj = CreateObject(propData.prop, coord.x, coord.y, coord.z - 1.0, false, false, false)
                PlaceObjectOnGroundProperly(obj)
                SetEntityHeading(obj, coord.w)
                FreezeEntityPosition(obj, true)
                table.insert(currentProps, obj)
            end
        end
    end

    -- get your vehicle by network ID and set it up
    local veh = NetworkGetEntityFromNetworkId(data.netId)
    while not DoesEntityExist(veh) do Wait(0) end
    SetEntityAsMissionEntity(veh, true, true)
    FreezeEntityPosition(veh, true)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)

    -- 3–2–1–GO countdown
    for i = 3, 1, -1 do
        PlaySoundFrontend(-1, "3_2_1", "HUD_MINI_GAME_SOUNDSET", true)
        ShowCountdownText(tostring(i), 1000)
    end
    PlaySoundFrontend(-1, "GO", "HUD_MINI_GAME_SOUNDSET", true)
    ShowCountdownText("GO", 1000)

    -- finally, release the vehicle
    FreezeEntityPosition(veh, false)
end)

RegisterNetEvent("speedway:updateLap", function(current, total)
    SpeedwayNotify("🏁 Speedway", ("Tour %s/%s"):format(current, total), "inform", 3000)
end)

RegisterNetEvent("speedway:youFinished", function()
    SpeedwayNotify("🏁 Speedway", "Tu as terminé la course !", "success", 5000)
end)

--------------------------------------------------------------------------------
-- FINAL RANKING (auto-closing notify)
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:finalRanking", function(data)
    local results = data.allResults or {}

    -- GLOBAL PODIUM BROADCAST
    if data.position == nil then
        -- build the podium lines
        local lines = { "🏆 Speedway Podium :" }
        for i, entry in ipairs(results) do
            local name = GetPlayerName(GetPlayerFromServerId(entry.id)) or ("ID "..entry.id)
            local secs = math.floor((entry.time or 0) / 1000)
            lines[#lines+1] = ("%d. %s — %ds"):format(i, name, secs)
        end

        -- show as a single, auto-closing notification for 10s
        SpeedwayNotify("", table.concat(lines, "\n"), "inform", 10000)
        return
    end

    -- PERSONAL NOTIFICATION
    local totalS = math.floor((data.totalTime or 0) / 1000)
    if data.position == 1 then
        SpeedwayNotify("🏆 Speedway", ("You won! Time: %ds"):format(totalS), "success", 5000)
    else
        SpeedwayNotify(
            "🏁 Speedway",
            ("You placed %d/%d – %ds"):format(data.position, #data.allResults, totalS),
            "inform",
            5000
        )
    end

    -- now show your lap times and best lap:
    if data.lapTimes then
        local lapLines = { "🏁 Your Lap Times:" }
        for i, t in ipairs(data.lapTimes) do
            lapLines[#lapLines+1] = ("Lap %d: %ds"):format(i, math.floor(t/1000))
        end
        lapLines[#lapLines+1] = ("Best Lap: %ds"):format(math.floor((data.bestLap or 0)/1000))

        -- display as a 10s notification
        SpeedwayNotify(
          "🏁 Lap Summary",
          table.concat(lapLines, "\n"),
          "info",
          10000
        )
    end
end)

--------------------------------------------------------------------------------
-- LAP COUNTER ZONE
--------------------------------------------------------------------------------
if type(config.StartLinePoints) == "table" and #config.StartLinePoints > 0 then
    lib.zones.poly({
        name      = "start_line",
        points    = config.StartLinePoints,
        thickness = 3.0,
        debug     = config.debug,
        onExit = function()
            if currentLobby and not hasPassed then
                hasPassed = true
                TriggerServerEvent("speedway:lapPassed", currentLobby)
                CreateThread(function()
                    Wait(3000)
                    hasPassed = false
                end)
            end
        end
    })
else
    print("[speedway] Warning: StartLinePoints not configured—lap zone skipped.")
end
