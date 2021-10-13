--[[
    Omnified messaging library.
    Written By: Matt Weber (https://badecho.com) (https://twitch.tv/omni)
    Copyright 2021 Bad Echo LLC
    
    Bad Echo Technologies are licensed under a
    Creative Commons Attribution-NonCommercial 4.0 International License.
    
    See accompanying file LICENSE.md or a copy at:
    http://creativecommons.org/licenses/by-nc/4.0/
--]]

require("omnified")
require("statisticMessages")

-- Reads the current death counter from a local death counter file.
local function readDeathCounter()
    local deathCounterFile = assert(io.open("deathCounter.txt", "r"))

    local deathCounterFromFile = deathCounterFile:read("*n")

    if deathCounterFromFile == nil then
        deathCounterFromFile = 0
    end

    deathCounterFile:close()

    return deathCounterFromFile
end

local function writeDeathCounter(deathCounter)
    local deathCounterFile = assert(io.open("deathCounter.txt", "w"))
    deathCounterFile:write(deathCounter)
    deathCounterFile:close()
end

-- Creates a JSON-encoded dump of hacked game statistics.
local function dumpStatistics()
    local playerHealth = not healthIsInteger
                            and toInt(readFloat(playerHealthAddress))
                            or toInt(readInteger(playerHealthAddress))

    local playerMaxHealth = not healthIsInteger
                                and toInt(readFloat(playerMaxHealthAddress))
                                or toInt(readInteger(playerMaxHealthAddress))

    local playerStamina = not staminaIsInteger
                            and toInt(readFloat(playerStaminaAddress))
                            or toInt(readInteger(playerStaminaAddress))

    local playerMaxStamina = not staminaIsInteger
                                and toInt(readFloat(playerMaxStaminaAddress))
                                or toInt(readInteger(playerMaxStaminaAddress))

    -- Last damaged enemy health always floating point, as it is maintained by the Apocalypse system.
    local enemyHealth = toInt(readFloat("lastEnemyHealthValue"))
    
    local newEnemyDamageEventNotProcessed = readInteger("newEnemyDamageEventNotProcessed")

    if newEnemyDamageEventNotProcessed ~= nil and newEnemyDamageEventNotProcessed == 1 then
        local newEnemyDamageEvent = readFloat("newEnemyDamageEvent")

        if newEnemyDamageEvent ~= nil and newEnemyDamageEvent > 0 then
            writeFloat("lastEnemyDamageEvent", newEnemyDamageEvent)
        end

        writeInteger("newEnemyDamageEventNotProcessed",0)
        -- Other new enemy damage event related symbols, such as those pertaining to bonus damage, are cleared by
        -- the entities responsible for reporting on them.
    end

    local lastDamageToPlayer = toInt(readFloat("lastDamageToPlayer"))
    local maxDamageToPlayer = toInt(readFloat("maxDamageToPlayer"))
    local totalDamageToPlayer = toInt(readFloat("totalDamageToPlayer"))
    local lastEnemyDamageEvent = toInt(readFloat("lastEnemyDamageEvent"))
    local maxEnemyDamageEvent = toInt(readFloat("maxEnemyDamageEvent"))
    local totalEnemyDamage = toInt(readFloat("totalEnemyDamage"))
    local enemyDamagePulses = readInteger("enemyDamagePulses")

    local playerCoordinates = readPlayerCoordinates()
        
    local playerDamageX = toInt(readFloat("playerDamageX") * 100)
    local playerSpeedX = toInt(readFloat("playerSpeedX") * 100)

    local deathCounterFromFile = readDeathCounter()
    local deathCounter = toInt(readInteger("deathCounter"))

    if deathCounterFromFile ~= 0 and deathCounter == 0 then
        deathCounter = deathCounterFromFile
        writeInteger("deathCounter", deathCounter)
    end

    writeDeathCounter(deathCounter)

    local statistics = {
        FractionalStatistic("Health", playerHealth, playerMaxHealth, "#AA43BC50", "#AA27D88D"),
        FractionalStatistic("Stamina", playerStamina, playerMaxStamina, "#AA7515D9", "#AAB22DE5"),
        WholeStatistic("Enemy Health", enemyHealth),
        StatisticGroup("Damage Taken", { 
            WholeStatistic("Last", lastDamageToPlayer), 
            WholeStatistic("Max", maxDamageToPlayer, true),
            WholeStatistic("Total", totalDamageToPlayer)
        }),
        StatisticGroup("Damage Inflicted", {
            WholeStatistic("Hits", enemyDamagePulses),
            WholeStatistic("Last", lastEnemyDamageEvent),
            WholeStatistic("Max", maxEnemyDamageEvent, true),
            WholeStatistic("Total", totalEnemyDamage)
        }),
        CoordinateStatistic("Coordinates", playerCoordinates.X, playerCoordinates.Y, playerCoordinates.Z),
        WholeStatistic("Player Damage", playerDamageX, false, "{0}%"),
        WholeStatistic("Player Speed", playerSpeedX, false, "{0}%"),
        WholeStatistic("Deaths", deathCounter)
    }

    local additionalIndex = 2

    for _, v in pairs(AdditionalStatistics ~= nil and AdditionalStatistics() or {}) do
        additionalIndex = additionalIndex + 1
        table.insert(statistics, additionalIndex, v)
    end

    return jsonEncode(statistics)
end

-- Enables the publishing of Omnified game statistic messages.
function startStatisticsPublisher()
    if statisticsTimer == nil then
        statisticsTimer = createTimer(getMainForm())        
    end

    statisticsTimer.Interval = 50
    statisticsTimer.OnTimer = function()
        local statistics = dumpStatistics()
        local statisticsFile = assert(io.open("statistics.json","w"))

        statisticsFile:write(statistics)
        statisticsFile:close()
    end
end

-- Disable the publishing of Omnified game statistic messages.
function stopStatisticsPublisher()
    if statisticsTimer == nil then return end
    
    statisticsTimer.Enabled = false
    statisticsTimer.Destroy()
    statisticsTimer = nil
end