--[[
    Exported configuration settings for Omnified Starfield.
    Written By: Matt Weber (https://badecho.com) (https://twitch.tv/omni)
    Copyright 2024 Bad Echo LLC
    
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
        local maxEquipLoad = toInt(readFloat("playerTotalMaxEquipLoad"))
        local shipShield = toInt(readFloat("playerShipShield"))
        local shipMaxShield = toInt(readFloat("playerShipMaxShield"))
        local shipHull = toInt(readFloat("playerShipHull"))
        local shipMaxHull = toInt(readFloat("playerShipMaxHull"))
        
        local shipX = readFloat("[playerShipLocation]+0x80")
        local shipY = readFloat("[playerShipLocation]+0x84")
        local shipZ = readFloat("[playerShipLocation]+0x88")

        if shipX ~= nil and shipX > 100000 then shipX = 0 end
        if shipY ~= nil and shipY > 100000 then shipY = 0 end
        if shipZ ~= nil and shipZ > 100000 then  shipZ = 0 end        

        local playerInShip = readInteger("playerInShip")
        local shipStatsHidden = playerInShip ~= 1        

        local additionalStatisticsTable = {
            FractionalStatistic("Ship Shield", shipShield, shipMaxShield, "#AA50717b", "#AA8ECCCC", shipStatsHidden),
            FractionalStatistic("Ship Hull", shipHull, shipMaxHull, "#AAD6D0B8", "#AAF1F4C6", shipStatsHidden),
            CoordinateStatistic("Ship", shipX, shipY, shipZ, shipStatsHidden),
            FractionalStatistic("Ammo", magazine, totalAmmo, "#00000000", "#00000000"),
            FractionalStatistic("Equip Load", equipLoad, maxEquipLoad, "#AAb589ef", "#AAabf2fb")
        }

        return additionalStatisticsTable
    end
end

function unregisterExports()

end