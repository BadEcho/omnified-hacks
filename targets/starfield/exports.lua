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

        local additionalStatisticsTable = {
            FractionalStatistic("Ammo", magazine, totalAmmo, "#00000000", "#00000000")
        }

        local playerInShip = readInteger("playerInShip")

        if playerInShip == 1 then
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