-- Initialize the addon using Ace3
WhisperUnfriendly = LibStub("AceAddon-3.0"):NewAddon("WhisperUnfriendly", "AceHook-3.0")
local WhisperUnfriendly = WhisperUnfriendly

-- Map es_MX to es_ES for localization
local clientLocale = GetLocale()
if clientLocale == "es_MX" then
    clientLocale = "es_ES"
end

-- Load AceLocale for localization
local L = LibStub("AceLocale-3.0"):GetLocale("WhisperUnfriendly", clientLocale)

-- Define buttons and their properties
local WhisperUnfriendlyButtons = {}
local WhisperUnfriendlyMenu = {}
local Buttons = {"Whisper", "Invite", "Add_Friend", "Add_Guild"}
local redColor, greenColor = "|cffff2020", "|cff20ff20"
local Colors = {greenColor, greenColor, greenColor, greenColor} -- All buttons can be green for simplicity

-- WoW API functions
local gsub, GetLocale = gsub, GetLocale
local UnitRace, UnitGUID, UnitName, UnitExists, UnitInParty, UnitInRaid = UnitRace, UnitGUID, UnitName, UnitExists, UnitInParty, UnitInRaid
local IsInGuild, CanGuildInvite = IsInGuild, CanGuildInvite
local SendChatMessage, InviteUnit, AddFriend, GuildInvite, ChatFrame_OpenChat = SendChatMessage, InviteUnit, AddFriend, GuildInvite, ChatFrame_OpenChat
local UIDropDownMenu_CreateInfo, UIDropDownMenu_AddButton = UIDropDownMenu_CreateInfo, UIDropDownMenu_AddButton

-- Frame types to allow interaction
local frameTypes = {["FRIEND"]=1, ["PLAYER"]=1, ["PARTY"]=1, ["RAID_PLAYER"]=1, ["RAID"]=1, ["PET"]=false, ["SELF"]=false}

-- Race-to-faction mapping for WoW 3.3.5a (using non-localized race IDs)
local raceToFaction = {
    -- Alliance races
    ["Human"] = "Alliance",
    ["Dwarf"] = "Alliance",
    ["NightElf"] = "Alliance", -- Note: Non-localized ID uses "NightElf" (no space)
    ["Gnome"] = "Alliance",
    ["Draenei"] = "Alliance",
    -- Horde races
    ["Orc"] = "Horde",
    ["Undead"] = "Horde",
    ["Tauren"] = "Horde",
    ["Troll"] = "Horde",
    ["BloodElf"] = "Horde", -- Note: Non-localized ID uses "BloodElf" (no space)
}

-- Called when the addon is enabled
function WhisperUnfriendly:OnEnable()
    -- Populate button properties using localized strings
    for i, v in ipairs(Buttons) do
        WhisperUnfriendlyButtons[v] = {
            text = L[v:upper()], -- Use localized text
            dist = 0,
            color = Colors[i],
            tooltipText = L[v:upper() .. "_TOOLTIP"] -- Use localized tooltip
        }
        WhisperUnfriendlyMenu[i] = v
    end
    -- Hook into the UnitPopup_ShowMenu function
    self:SecureHook("UnitPopup_ShowMenu")
end

-- Button click handler
local function WhisperUnfriendly_Button_Onclick(self, info)
    assert(info)
    local button = info.button
    local name = info.name or UnitName(info.unit)
    assert(name)

    if button == "Whisper" then
        ChatFrame_OpenChat("/w " .. name .. " ") -- Opens the whisper window with the target's name
    elseif button == "Invite" then
        InviteUnit(name)
    elseif button == "Add_Friend" then
        AddFriend(name)
    elseif button == "Add_Guild" then
        GuildInvite(name)
    end
end

-- Check if the target is from the opposite faction using race
local function isOppositeFaction(unit, name, which)
    -- If unit is nil and which is "FRIEND", we can't determine the race/faction
    if not unit and which == "FRIEND" then
        return false
    end

    -- Ensure unit is valid before calling UnitRace
    if not unit or type(unit) ~= "string" or not UnitExists(unit) then
        return false
    end

    -- Get the player's race and infer their faction
    local _, playerRaceID = UnitRace("player") -- Use the non-localized race ID
    local playerFaction = raceToFaction[playerRaceID]

    -- Get the target's race and infer their faction
    local _, targetRaceID = UnitRace(unit) -- Use the non-localized race ID
    local targetFaction = raceToFaction[targetRaceID]

    -- If either faction couldn't be determined, return false (don't show buttons)
    if not playerFaction or not targetFaction then
        return false
    end

    -- Return true if the factions are different
    return playerFaction ~= targetFaction
end

-- Hook into the dropdown menu
function WhisperUnfriendly:UnitPopup_ShowMenu(dropdownMenu, which, unit, name, userData)
    local thisName = name or UnitName(unit)
    which = gsub(which, "PB4_", "") -- Remove any prefix (if any)

    -- Skip if the frame type isn't supported
    if not frameTypes[which] then return end

    -- Skip the friends list context entirely (let AFriend handle it)
    if which == "FRIEND" then return end

    -- Skip if the target is the player themselves
    if UnitGUID(unit) == UnitGUID("player") then return end

    -- Skip if the target is the player (in FRIEND context)
    if which == "FRIEND" and thisName == UnitName("player") then return end

    -- Skip if this is a submenu (we only add to the main menu)
    if UIDROPDOWNMENU_MENU_LEVEL > 1 then return end

    -- Only proceed if the target is from the opposite faction
    if not isOppositeFaction(unit, name, which) then return end

    -- Skip if the unit is in your party or raid
    if UnitInParty(unit) or UnitInRaid(unit) then return end

    -- Add buttons to the dropdown menu
    local info = UIDropDownMenu_CreateInfo()
    for _, v in ipairs(WhisperUnfriendlyMenu) do
        info.text = WhisperUnfriendlyButtons[v].text
        info.value = v
        info.owner = which
        info.func = WhisperUnfriendly_Button_Onclick
        info.notCheckable = 1
        info.colorCode = WhisperUnfriendlyButtons[v].color or nil
        info.arg1 = {["button"]=v, ["unit"]=unit, ["name"]=name}
        info.tooltipTitle = WhisperUnfriendlyButtons[v].text
        info.tooltipText = WhisperUnfriendlyButtons[v].tooltipText

        -- Add the button based on conditions
        if v == "Add_Guild" then
            -- Only show "Invite to Guild" if the player is in a guild and can invite
            if IsInGuild() and CanGuildInvite() then
                UIDropDownMenu_AddButton(info)
            end
        else
            -- Whisper, Invite, and Add Friend are always shown for opposite-faction players
            UIDropDownMenu_AddButton(info)
        end
    end
end