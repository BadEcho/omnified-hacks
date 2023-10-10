--[[
    Exported configuration settings for Omnified Starfield.
    Written By: Matt Weber (https://badecho.com) (https://twitch.tv/omni)
    Copyright 2023 Bad Echo LLC
    
    Bad Echo Technologies are licensed under the
    GNU Affero General Public License v3.0.
    
    See accompanying file LICENSE.md or a copy at:
    https://www.gnu.org/licenses/agpl-3.0.html
--]]

require("statisticMessages")

function registerExports()
    additionalStatistics = function()
        local magazine = toInt(readInteger("[playerMagazine]+0x18"))
        local totalAmmo = toInt(readInteger("playerAmmo"))

        local equipLoad = toInt(readFloat("playerEquipLoad"))
        local maxEquipLoad = toInt(readFloat("[playerMaxEquipLoad]+0x68"))

        local additionalStatisticsTable = {
            FractionalStatistic("Ammo", magazine, totalAmmo, "#00000000", "#00000000"),
            FractionalStatistic("Equip Load", equipLoad, maxEquipLoad, "#AAb589ef", "#AAabf2fb")
        }

        local playerInShip = readInteger("playerInShip")

        if playerInShip == 1 then
            local shipShield = toInt(readFloat("playerShipShield"))
            local shipMaxShield = toInt(readFloat("playerShipMaxShield"))
            local shipHull = toInt(readFloat("playerShipHull"))
            local shipMaxHull = toInt(readFloat("playerShipMaxHull"))

            table.insert(additionalStatisticsTable, FractionalStatistic("Ship Shield", shipShield, shipMaxShield, "#AA50717b", "#AA8ECCCC"))
            table.insert(additionalStatisticsTable, FractionalStatistic("Ship Hull", shipHull, shipMaxHull, "#AAD6D0B8", "#AAF1F4C6"))

            local shipX = readFloat("[playerShipLocation]+0x80")
            local shipY = readFloat("[playerShipLocation]+0x84")
            local shipZ = readFloat("[playerShipLocation]+0x88")

            table.insert(additionalStatisticsTable, CoordinateStatistic("Ship", shipX, shipY, shipZ))
        end

        return additionalStatisticsTable
    end
end

function unregisterExports()

end