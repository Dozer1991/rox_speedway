-- server/s_leaderboard.lua

--------------------------------------------------------------------------------
-- 1) IN-MEMORY STORAGE
--------------------------------------------------------------------------------
local lobbyProgress         = {}  -- [lobbyName][playerId] = { dist, cpIndex, planar }
local lobbyGridOrder        = {}  -- [lobbyName] = { pid1, pid2, ... }
local lobbyInitialPlanar    = {}  -- [lobbyName][playerId] = planarDist at start

--------------------------------------------------------------------------------
-- 2) SET GRID ORDER (once at race start)
--------------------------------------------------------------------------------
RegisterNetEvent('speedway-leaderboard:server:setGridOrder', function(lobbyName, gridOrder)
    lobbyGridOrder[lobbyName]     = gridOrder
    lobbyProgress[lobbyName]      = {}
    lobbyInitialPlanar[lobbyName] = {}
end)

--------------------------------------------------------------------------------
-- 3) UPDATE PROGRESS (every 200 ms)
--    args: (lobbyName, rawDist, cpIndex, planarDist)
--------------------------------------------------------------------------------
RegisterNetEvent('speedway-leaderboard:server:updateProgress', function(lobbyName, rawDist, cpIndex, planarDist)
    local src = source

    rawDist    = tonumber(rawDist)    or 0
    cpIndex    = tonumber(cpIndex)    or 0
    planarDist = tonumber(planarDist) or 0

    -- init tables
    lobbyProgress[lobbyName]      = lobbyProgress[lobbyName]      or {}
    lobbyInitialPlanar[lobbyName] = lobbyInitialPlanar[lobbyName] or {}

    -- record initial planar on first tick
    if lobbyInitialPlanar[lobbyName][src] == nil then
        lobbyInitialPlanar[lobbyName][src] = planarDist
    end

    -- store this tick’s data
    lobbyProgress[lobbyName][src] = {
      dist   = rawDist,
      cpIndex= cpIndex,
      planar = planarDist
    }

    -- build board in grid-spawn order
    local grid  = lobbyGridOrder[lobbyName] or {}
    local board = {}
    for idx, pid in ipairs(grid) do
        local rec = lobbyProgress[lobbyName][pid] or { dist=0, cpIndex=0, planar=0 }
        local initP = lobbyInitialPlanar[lobbyName][pid] or rec.planar
        board[#board+1] = {
          id          = pid,
          dist        = rec.dist,
          cpIndex     = rec.cpIndex,
          planar      = rec.planar,
          initialPlan = initP,
          gridPos     = idx
        }
    end

    -- sort:
    -- 1) by cpIndex
    -- 2) if cpIndex==0, by (planar - initialPlan) >0.01, else gridPos
    -- 3) if cpIndex>0, by dist >0.001, else gridPos
    table.sort(board, function(a,b)
        if a.cpIndex ~= b.cpIndex then
            return a.cpIndex > b.cpIndex
        end
        if a.cpIndex == 0 then
            local moveA = a.planar - a.initialPlan
            local moveB = b.planar - b.initialPlan
            local delta = moveA - moveB
            if math.abs(delta) > 0.01 then
                return delta > 0
            else
                return a.gridPos < b.gridPos
            end
        else
            local delta = a.dist - b.dist
            if math.abs(delta) > 0.001 then
                return delta > 0
            else
                return a.gridPos < b.gridPos
            end
        end
    end)

    -- broadcast ranks
    local total = #board
    for rank, e in ipairs(board) do
        TriggerClientEvent('speedway-leaderboard:client:updateRank', e.id, rank, total)
    end
end)

--------------------------------------------------------------------------------
-- 4) OPTIONAL CLEANUP
--------------------------------------------------------------------------------
RegisterNetEvent('speedway:lapPassed', function(lobbyName, _)
    -- if you want to wipe data at race end:
    -- lobbyProgress[lobbyName]      = nil
    -- lobbyGridOrder[lobbyName]     = nil
    -- lobbyInitialPlanar[lobbyName] = nil
end)
