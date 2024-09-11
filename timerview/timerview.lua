local kkAddon = {}

kkAddon["name"] = "timerview"
kkAddon["version"] = "0.0.2"
kkAddon["author"] = "Uwu/Darkdoom"
kkAddon["command"] = "tv"

require("Tables")

local TimerView = {
    ["MainWinOpen"] = true,

    ["InitialAbilityDuration"] = {},
    ["InitialSpellDuration"] = {},

    ["LastManeuver"] = 0,
    ["Settings"] = T{
        --TODO: settings
    }
}

local StratagemAbilities = T{
    --light arts
    "Penury",
    "Celerity",
    "Rapture",
    "Accession",
    "Addendum: White",
    "Perpetuance",

    --dark arts
    "Parsimony",
    "Alacrity",
    "Ebullience",
    "Manifestation",
    "Addendum: Black"
}

local ManeuverIds = T{
    141,
    142,
    143,
    144,
    145,
    146,
    147,
    148
}

--TODO: dice condensing
--TODO: rune condensing

local PetAbilities = T{}

kkAddon["load"] = function()
    local petAbilityMin = 1024 --TODO: change to CommandTableRanges:: constants once exposed
    local petAbilityMax = 1535

    local resourceManager = GameManager:GetResourceManager()
    for i = petAbilityMin, petAbilityMax, 1 do
        local petAbilityName = resourceManager:JobAbilityIdToName(i)
        if(petAbilityName)then
            PetAbilities:Insert(petAbilityName)
        end
    end
end

kkAddon["incoming packet"] = function(packet)
    if(packet["headerId"] == 0x28)then
        local actionPacket = CXiSchStatus.new(packet["dataVector"])
        if(actionPacket.MainToCalc.CmdNo == IncomingActionType.JobAbility)then
            local player = GameManager:GetLocalPlayer()
            if(player.Id == actionPacket.MainToCalc.ActorId)then
                if(ManeuverIds:Contains(actionPacket.MainToCalc:GetCmdArg()))then
                    TimerView["LastManeuver"] = actionPacket.MainToCalc:GetCmdArg() + 512
                end
            end
        end
    end
end

local function GetTimeStr(recastTime)
    local min = math.floor(recastTime / 60)
    local sec = recastTime % 60
    return string.format("%d:%02d", min, sec)
end

local function DrawJobAbilityRecastTime(abilityName, abilityId, timeStr, percent, charges)
    local cursorPos = CImGui.GetCursorPos()
    Utils.GameIconDrawing.DrawAbilityIconWindowList(abilityId, 24, 24)
    CImGui.SetCursorPosX(cursorPos.x + 26)
    if(charges == -1)then --ja with no charges
        CImGui.ProgressBar(string.format("%s: [%s]", abilityName, timeStr), percent, ImVec2.new(185, 15))
    else
        CImGui.ProgressBar(string.format("%s: [%s] [%d]", abilityName, timeStr, charges), percent, ImVec2.new(185, 15))
    end
    CImGui.SetCursorPosY(cursorPos.y + 24)
end

local function DrawSpellRecastTime(spellName, spellId, timeStr, percent)
    local cursorPos = CImGui.GetCursorPos()
    Utils.GameIconDrawing.DrawSpellIconWindowList(spellId, 24, 24)
    CImGui.SetCursorPosX(cursorPos.x + 26)
    CImGui.ProgressBar(string.format("%s: [%s]", spellName, timeStr), percent, ImVec2.new(185, 15))
    CImGui.SetCursorPosY(cursorPos.y + 24)
end

function TimerView:ClearAbilityDuration(abilityId)
    if(self["InitialAbilityDuration"][abilityId] ~= 0)then
        self["InitialAbilityDuration"][abilityId] = nil
    end
end

function TimerView:ClearSpellDuration(spellId)
    if(self["InitialSpellDuration"][spellId] ~= 0)then
        self["InitialSpellDuration"][spellId] = nil
    end
end

function TimerView:GetAbilityDurationPercent(abilityId, recastTime)
    local percent = 0

    if(self["InitialAbilityDuration"][abilityId] ~= nil and self["InitialAbilityDuration"][abilityId] ~= 0)then
        percent = recastTime / self["InitialAbilityDuration"][abilityId]
        percent = math.min(1, math.max(0, 1 - percent))
    end

    return percent
end

function TimerView:GetSpellDurationPercent(spellId, recastTime)
    local percent = 0

    if(self["InitialSpellDuration"][spellId] ~= nil and self["InitialSpellDuration"][spellId] ~= 0)then
        percent = recastTime / self["InitialSpellDuration"][i]
        percent = math.min(1, math.max(0, 1 - percent))
    end

    return percent
end

function TimerView:DrawJobAbilityTimers()
    CImGui.BeginGroup()
    if(CImGui.BeginChild("##AbilityTimerViewChild", ImVec2.new(235, 0), true))then
        local jobAbilities = GameManager:GetCombatManager():GetJobAbilities()
        local resourceManager = GameManager:GetResourceManager()
        local recastManager = GameManager:GetRecastManager()

        local alreadyCondensedManeuvers = false
        for i = 1, jobAbilities:size(), 1 do
            local abilityName = resourceManager:JobAbilityIdToName(jobAbilities[i].No)
            local recastTime, currentCharges = recastManager:GetAbilityRecastTime(jobAbilities[i].No)

            local timeStr = GetTimeStr(recastTime)

            if(self["InitialAbilityDuration"][jobAbilities[i].No] == nil and recastTime ~= 0)then
                self["InitialAbilityDuration"][jobAbilities[i].No] = recastTime
            end

            local percent = self:GetAbilityDurationPercent(jobAbilities[i].No, recastTime)

            if(not StratagemAbilities:Contains(abilityName) and not PetAbilities:Contains(abilityName))then
                if(not alreadyCondensedManeuvers and self["LastManeuver"] == jobAbilities[i].No)then
                    alreadyCondensedManeuvers = true
                    if(recastTime == 0)then
                        self:ClearAbilityDuration(jobAbilities[i].No)
                    else
                        DrawJobAbilityRecastTime(abilityName, jobAbilities[i].No, timeStr, percent, currentCharges, recastTime)
                    end
                else
                    if(not ManeuverIds:Contains(jobAbilities[i].No - 512))then
                        if(recastTime == 0)then
                           self:ClearAbilityDuration(jobAbilities[i].No)
                        else
                            DrawJobAbilityRecastTime(abilityName, jobAbilities[i].No, timeStr, percent, currentCharges, recastTime)
                        end
                    end
                end
            end
        end
        CImGui.EndChild()
    end
    CImGui.EndGroup()
end

function TimerView:DrawSpellTimers()
    CImGui.BeginGroup()
    if(CImGui.BeginChild("##SpellTimerViewChild", ImVec2.new(235, 0), true))then
        local resourceManager = GameManager:GetResourceManager()
        local recastManager = GameManager:GetRecastManager()

        for i = 1, 1024, 1 do
            local recast = recastManager:GetSpellRecastTime(i)
            local spellName = resourceManager:SpellIdToName(i)

            if(self["InitialSpellDuration"][i] == nil and recast ~= 0)then
                self["InitialSpellDuration"][i] = recast
            end

            local timeStr = GetTimeStr(recast)

            local percent = self:GetSpellDurationPercent(i, recast)

            if(recast == 0)then
                self:ClearSpellDuration(i)
            else
                DrawSpellRecastTime(spellName, i, timeStr, percent)
            end
        end
        CImGui.EndChild()
    end
    CImGui.EndGroup()
end

kkAddon["present"] = function()
    CImGui.SetNextWindowPos(ImVec2.new(25, 300))
    CImGui.SetNextWindowBgAlpha(0.5)
    if(CImGui.Begin("##TimerView"))then --TODO: no title bar
        TimerView:DrawJobAbilityTimers()
        CImGui.SameLine()
        TimerView:DrawSpellTimers()
        CImGui.End()
    end

    --TODO: settings editor window
end

return kkAddon