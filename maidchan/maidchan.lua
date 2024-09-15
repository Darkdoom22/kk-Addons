local kkAddon = {}

kkAddon["name"] = "maidchan"
kkAddon["version"] = "0.0.1"
kkAddon["author"] = "Uwu/Darkdoom"
kkAddon["command"] = "mc"

require("Tables")

local Packets = require("packets.Packets")
local Settings = require("Settings")

local MaidChan = T{
    ["FrameCount"] = 0,
    ["EditorWinOpen"] = false,
    ["CurrentDropConfirmationItem"] = nil,
    ["LastItemIdCached"] = 0,
    ["ItemNameToIdCache"] = T{},
    ["DropList"] = T{

    },

    ["Settings"] = T{
        ["AskBeforeDelete"] = true,
        ["DropIntervalFramesMin"] = 30,
        ["DropIntervalFramesMax"] = 90,
    }
}

math.randomseed(os.time())

local function Log(message)
    GameFunctionManager.Global.LogPrint(string.format("\x1F\x06[MaidChan] %s", message))
end

kkAddon["load"] = function()
    Settings:TryCreateAddonSettingsDirectory("maidchan")

    local player = GameManager:GetLocalPlayer()
    if(player)then
        local settingsFileName = string.format("%s_%s_settings", player.Name, GameManager:GetWorldName())
        local dropListFileName = string.format("%s_%s_drop_list", player.Name, GameManager:GetWorldName())

        if(not Settings:DoesAddonSettingsFileExist("maidchan", settingsFileName))then
            Settings:CreateAddonSettingsFile("maidchan", settingsFileName, MaidChan["Settings"])
        else
            MaidChan["Settings"] = Settings:GetAddonSettingsTable("maidchan", settingsFileName)
            Log(string.format("Loaded addon settings for %s!", player.Name))
        end

        if(not Settings:DoesAddonSettingsFileExist("maidchan", dropListFileName))then
            Settings:CreateAddonSettingsFile("maidchan", dropListFileName, MaidChan["DropList"])
        else
            MaidChan["DropList"] = Settings:GetAddonSettingsTable("maidchan", dropListFileName)
            Log(string.format("Loaded drop list for %s!", player.Name))
        end
    end
end

kkAddon["addon command"] = function(args)
    if(args[2]:lower() == "settings")then
        MaidChan["EditorWinOpen"] = not MaidChan["EditorWinOpen"]
    end
end

--TODO: should allow for partial matches
--super slow if you have to search the whole range on the first call, so try not to mispell item names
function MaidChan:ValidateIsItem(itemName)
    if(self["ItemNameToIdCache"][itemName])then
        return true
    end

    local resourceManager = GameManager:GetResourceManager()
    for i = self["LastItemIdCached"], 29695, 1 do
        local itemResource = resourceManager:GetItemResource(i)
        if(itemResource)then
            if(self["ItemNameToIdCache"][itemResource.Name:lower()] == nil)then
                self["ItemNameToIdCache"][itemResource.Name:lower()] = itemResource.ItemNo
                self["LastItemIdCached"] = itemResource.ItemNo
            end
            if(itemResource.Name:lower() == itemName)then
                return true
            end
        end
    end

    return false
end

function MaidChan:SaveDropList()
    local player = GameManager:GetLocalPlayer()
    if(player)then
        local dropListFileName = string.format("%s_%s_drop_list", player.Name, GameManager:GetWorldName())
        table.sort(self["DropList"], function(a, b) return a < b end)
        Settings:SaveAddonSettingsFile("maidchan", dropListFileName, self["DropList"]:Serialize())
    end
end

function MaidChan:DrawRemovalConfirmationPopup()
    CImGui.Text("Are you sure you want to delete this item: ")
    CImGui.SameLine()
    CImGui.TextColored(ImVec4.new(0, 1, 0, 1), self["CurrentDropConfirmationItem"])
    CImGui.SameLine()
    CImGui.Text("?")

    CImGui.Separator()

    local windowWidth = CImGui.GetWindowSize().x
    local buttonWidth = 60
    local totalButtonWidth = (buttonWidth * 2)
    local buttonStartPos = (windowWidth - totalButtonWidth) * 0.5

    CImGui.SetCursorPosX(buttonStartPos)

    if(CImGui.Button("Yes", ImVec2.new(buttonWidth, 0)))then
        MaidChan["DropList"]:Remove(self["CurrentDropConfirmationItem"])
        MaidChan:SaveDropList()
        CImGui.CloseCurrentPopup()
    else
        CImGui.SameLine()
        if(CImGui.Button("No", ImVec2.new(buttonWidth, 0)))then
            CImGui.CloseCurrentPopup()
        end
    end
end

function MaidChan:DrawAddItemConfirmationPopup(itemName)
    CImGui.Text("Are you sure you want to add this item: ")
    CImGui.SameLine()
    CImGui.TextColored(ImVec4.new(0, 1, 0, 1), itemName)
    CImGui.SameLine()
    CImGui.Text("?")
    CImGui.TextColored(ImVec4.new(1, 0, 0, 1), "Warning: This item will automatically be dropped!")

    CImGui.Separator()

    local windowWidth = CImGui.GetWindowSize().x
    local buttonWidth = 60
    local totalButtonWidth = (buttonWidth * 2)
    local buttonStartPos = (windowWidth - totalButtonWidth) * 0.5

    CImGui.SetCursorPosX(buttonStartPos)

    if(CImGui.Button("Yes", ImVec2.new(buttonWidth, 0)))then
        MaidChan["DropList"]:Insert(itemName:lower())
        MaidChan:SaveDropList()
        CImGui.CloseCurrentPopup()
    else
        CImGui.SameLine()
        if(CImGui.Button("No", ImVec2.new(buttonWidth, 0)))then
            CImGui.CloseCurrentPopup()
        end
    end
end

function MaidChan:DrawDeleteButton(item)
    if(CImGui.Button(string.format("Delete##%s", item)))then
        self["CurrentDropConfirmationItem"] = item
        CImGui.OpenPopup("Remove Item Confirmation")
    end
end

function MaidChan:DrawDropListTabItem()
    CImGui.Text("Items to drop")
    local result, filterText = CImGui.InputText("Drop List Filter")
    if(CImGui.BeginChild("DropListChild", ImVec2.new(0, 250), true))then
        for _,v in pairs(self["DropList"]) do
            if(filterText ~= "")then
                if(v:find(filterText))then
                    CImGui.Text(v)
                    CImGui.SameLine()
                    self:DrawDeleteButton(v)
                end
            else
                CImGui.Text(v)
                CImGui.SameLine()
                self:DrawDeleteButton(v)
            end
        end

        if(CImGui.BeginPopup("Remove Item Confirmation"))then
            self:DrawRemovalConfirmationPopup()
            CImGui.EndPopup()
        end
        CImGui.EndChild()
    end

    CImGui.Separator()

    local entered, text = CImGui.InputText("Add Item", ImGuiInputTextFlags.EnterReturnsTrue)
    if(entered)then
        if(not self["DropList"]:Contains(text:lower()))then
            if(self:ValidateIsItem(text:lower()))then
                CImGui.OpenPopup("Add Item Confirmation")
            else
                Log(string.format("Item %s does not exist or is not a valid item!", text))
            end
        else
            Log(string.format("Item %s already in drop list!", text))
        end
    end

    if(CImGui.BeginPopup("Add Item Confirmation"))then
        self:DrawAddItemConfirmationPopup(text)
        CImGui.EndPopup()
    end
end

function MaidChan:DrawEditorWindow()
    if(CImGui.BeginTabBar("MaidChanEditorTabBar"))then
        if(CImGui.BeginTabItem("Addon Settings"))then
            --TODO: add settings
            CImGui.EndTabItem()
        end

        if(CImGui.BeginTabItem("Drop List"))then
            self:DrawDropListTabItem()
            CImGui.EndTabItem()
        end
        CImGui.EndTabBar()
    end
end

local function DropItem(itemIndex, itemCount)
    local dropPacket = Packets:RequestBuffer('outgoing', 0x28)
    dropPacket["Count"] = itemCount
    dropPacket["Bag"] = 0
    dropPacket["BagIndex"] = itemIndex
    Packets:QueueOutgoing(0x28, dropPacket)
end

function MaidChan:CheckForItemsToDrop()
    local inventoryManager = GameManager:GetInventoryManager()
    local resourceManager = GameManager:GetResourceManager()
    for i = 0, 81, 1 do
        local bagItem = inventoryManager:GetBagItem(0, i) --bag 0 = inventory
        if(bagItem)then
            local itemResource = resourceManager:GetItemResource(bagItem.Id)
            if(self["DropList"]:Contains(itemResource.Name:lower()))then
                DropItem(bagItem.Index, bagItem.Count)
                --Log(string.format("Dropping [%d] of %s.", bagItem.Count, itemResource.Name))
                return --TODO: until I implement scheduling just drop one item per call
            end
        end
    end
end

--TODO: use imgui frame count
kkAddon["present"] = function()
    if(CImGui.Begin("MaidChan Settings", MaidChan["EditorWinOpen"]))then
        MaidChan:DrawEditorWindow()
        CImGui.End()
    end

    if(MaidChan["FrameCount"] % math.random(30, 60) == 0)then
        MaidChan:CheckForItemsToDrop()
        MaidChan["FrameCount"] = 0
    end

    MaidChan["FrameCount"] = MaidChan["FrameCount"] + 1
end

return kkAddon