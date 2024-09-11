local kkAddon = {}
local TreasureView = {}

kkAddon["name"] = "treasureview"
kkAddon["version"] = "1.0"
kkAddon["author"] = "Uwu/Darkdoom"
kkAddon["command"] = "treasureview"

require("Tables")
local ImGui = require("imgui")
local Packets = require("packets.Packets")

TreasureView["DropPool"] = T{}

--TODO: figure out timestamp issues/test on retail again
--TODO: sort list by time left
--TODO: legacy imgui api -> new one

kkAddon["incoming packet"] = function(packet)
    if(packet["headerId"] == 0xD2)then
        local itemDropPacket = Packets:Unpack('incoming', 0xD2, packet["data"])
        if(itemDropPacket)then
            if(not TreasureView["DropPool"]:Contains(itemDropPacket["Timestamp"]))then
                TreasureView["DropPool"][itemDropPacket["Timestamp"]] = {}
                TreasureView["DropPool"][itemDropPacket["Timestamp"]]["PoolTimeEnd"] = os.time() + 300
            end
        end
    end
end

kkAddon["present"] = function()
    if(GameManager:IsLoggedIn())then
        ImGui:SetNextWindowBgAlpha(0.30)
        if(ImGui:Begin("TreasureView"))then
            local trophyManager = GameManager:GetTrophyManager()
            local resourceManager = GameManager:GetResourceManager()
            for i = 0, 9 do
                local trophyItem = trophyManager:GetTrophyByIndex(i)
                if(trophyItem)then
                   local itemResource = resourceManager:GetItemResource(trophyItem.ItemData.ItemHeader.ItemId)
                   if(itemResource)then
                        if(TreasureView["DropPool"][trophyItem.DropTime])then
                            local timeDiff = os.difftime(TreasureView["DropPool"][trophyItem.DropTime]["PoolTimeEnd"], os.time())
                            local time = os.date("!%M:%S", timeDiff)
                            local textColor = timeDiff > 120 and {0, 1, 0} or timeDiff > 60 and {1, 1, 0} or {1, 0, 0}

                            if(trophyItem.WinningLot > 0)then
                                ImGui:TextColored(textColor, string.format("%d: %s, %s ---> ", i, itemResource.FullName, time))
                                ImGui:SameLine()
                                ImGui:TextColored({0, 0.85, 1}, string.format("[%s : %d]", trophyItem.WinningActorName, trophyItem.WinningLot))
                            else
                                ImGui:TextColored(textColor, string.format("%d: %s, %s", i, itemResource.FullName, time))
                            end

                            if(timeDiff < 0)then
                                TreasureView["DropPool"][trophyItem.DropTime] = nil
                            end
                        end
                   end
                end
            end
        end
        ImGui:End();
    end
end

return kkAddon