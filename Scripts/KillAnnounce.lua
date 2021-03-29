-- +=========+
-- | GLOBALS |
-- +=========+

-- Widgets
local AnnounceText
local DragPanel
local MainPanel
local AnnounceDesc

-- Variables
local AddonName = common.GetAddonName()
local Version = "2.4.0"
local VDate = "(17.03.2021)"
local AddonDescription = "Shows a notification when you or a nearby player is killed"
local configSectionName = 'KillAnnounce'
local Config = {}
local CompatibleWithVersions = {}
local ColorList = {
	killedByPlayer = 0,
	playerKilled = 0,
	killedByFriend = 0,
	friendKilled = 0
}
local OnEvent = {}
local OnReaction = {}
local OriginalPos
local FirstPos = {}
local PlayersTracked = {}
local OnUnitDamageReceivedFunctions = {}
local AnnounceList = {}
local ANNOUNCE_FADE_IN_TIME = 300
local ANNOUNCE_FADE_OUT_TIME = 900
local AnnouncePadding = 0
local PanelIsMoving = false


-- +===========+
-- | Functions |
-- +===========+

function AddAnnouncement(content,killType)
    if Config.announceOnScreen then
		--Create and format the announcement
		local announcement = mainForm:CreateWidgetByDesc(AnnounceDesc)
		local form = string.format('<header color="0x%s" alignx="center" fontsize="%s" outline="1" shadow="1"><rs class="class"><r name="value"/></rs></header>', ColorList[killType], tostring(Config.fontSize))
		local placement = nil

		announcement:SetFormat(ToWS(form))
		announcement:SetVal('value', ToWS(content))

		table.insert(AnnounceList, announcement)

		--Check where to put the announcememt
		if #AnnounceList > 1 then
			placement = AnnounceList[#AnnounceList-1]:GetPlacementPlain()
			placement.posY = placement.posY - AnnouncePadding
		else
			placement = FirstPos
		end
		--Show the announcement
		MainPanel:Show(true)
		announcement:SetPlacementPlain(placement)
		announcement:Show(true)
		announcement:PlayFadeEffect( 0.0, .999, ANNOUNCE_FADE_IN_TIME, EA_MONOTONOUS_INCREASE)

		--Remove the bottom announcement
		if #AnnounceList > Config.maxAnnouncements then
			if not PanelIsMoving then
				AnnounceList[1]:PlayFadeEffect(1.0, 0.0, ANNOUNCE_FADE_OUT_TIME, EA_MONOTONOUS_INCREASE)
			end
		end
		if #AnnounceList == 0 then MainPanel:Show(false) end
	end
    if Config.postInChat then
        PushToChat(content,Config.fontSize,ColorList[killType])
    end
end

function OnUnitDamageReceived(damage,v)
    if damage.lethal then
		if damage.target
		 and object.IsExist(damage.target)
		 and object.IsUnit(damage.target)
		 and unit.IsPlayer(damage.target)
		then
			local abilityName = nil
			if damage.ability then abilityName = FromWS(damage.ability) end
			if damage.target == avatar.GetId() then
				PlayerKilled(damage.source, FromWS(damage.sourceName), abilityName,damage.amount)
			else
				-- PushToChatSimple(FromWS(damage.sourceName).." killed someone")
				UnitKilled(damage.source, damage.target, object.IsFriend(damage.target), FromWS(damage.sourceName), abilityName,damage.amount)
			end
		end
	end
end

function PlayerKilled (killerID,sourceName,ability,damage)
	if killerID and object.IsExist(killerID) and object.IsUnit(killerID) then
        --local killer = object.GetName(killerID)
		local killer = sourceName
		local abilityName = ""
		if ability ~= nil then 
			abilityName = " ("..ability..")"
		end
		if damage > 1000000 then
			damage = Round(damage / 1000000,2)
			damage = damage .. "M"
		elseif damage > 1000 then
			damage = Round(damage / 1000,2)
			damage = damage .. "K"
		end
		local damageAmount = " ("..damage..")"
		if not Config.showDamageAmount then damageAmount = "" end
		--To prevent the pet name from showing up instead of the owner in the announcement
		if unit.IsPet(killerID) then
			local ownerId = unit.GetPetOwner(killerID)
			if unit.IsPlayer(ownerId) then
				killer = FromWS(object.GetName(ownerId))
			else
				killer = sourceName
			end
			abilityName = " (Pet)"
		end
		if not Config.showAbilityName then abilityName = "" end
		local announceContent = string.format(GTL("You were killed by")..abilityName..damageAmount, killer)
		AddAnnouncement(announceContent,'playerKilled')
	end
end

function UnitKilled (killerID, victimID, isFriendly, sourceName, ability, damage)
	--if killerID == nil then return end
	if victimID and unit.IsPet(victimID) then return end
	if killerID
        and object.IsExist(killerID)
        and object.IsExist(victimID)
        and object.IsUnit(killerID)
        and object.IsUnit(victimID)
        then
        local announceContent
		--local killer = userMods.FromWString(object.GetName(killerID))
		local killer = sourceName
		local victim = FromWS(object.GetName(victimID))
		-- PushToChatSimple(killer.." killed "..victim)
		--AddAnnouncement(killer.." killed "..victim,'killedByFriend',)
		local abilityName = " ("..ability..")"
		if damage > 1000000 then
			damage = Round(damage / 1000000,2)
			damage = damage .. "M"
		elseif damage > 1000 then
			damage = Round(damage / 1000,2)
			damage = damage .. "K"
		end
		local damageAmount = " ("..damage..")"
		if not Config.showDamageAmount then damageAmount = "" end
		if unit.IsPet(killerID) then
			killerID = unit.GetPetOwner(killerID)
			killer = FromWS(object.GetName(killerID))
			abilityName = " (Pet)"
		end
		if not Config.showAbilityName then abilityName = "" end
		if killerID == avatar.GetId() and Config.killedByPlayer then --The unit was killed by the player
			announceContent = string.format(GTL("You killed")..abilityName..damageAmount, victim)
			AddAnnouncement(announceContent,'killedByPlayer')
			return
		end
		announceContent = string.format(GTL("killed")..abilityName..damageAmount, killer, victim)
		if isFriendly then --A friendly unit was killed
			if Config.friendKilled then
				AddAnnouncement(announceContent,'friendKilled')
				--return
			end
		elseif Config.killedByFriend then --An enemy was killed by a friendly
			AddAnnouncement(announceContent,'killedByFriend')
		end
	end
end

function MoveAnnouncements()
	PanelIsMoving = true
	for _, a in pairs(AnnounceList) do
		local startPos = a:GetPlacementPlain()
		local endPos = startPos
		endPos.posY = endPos.posY + AnnouncePadding
		a:PlayMoveEffect( startPos, endPos, 300, EA_MONOTONOUS_INCREASE )
	end
	PanelIsMoving = false
end

function GetUnitListOld()
    local units = avatar.GetUnitList()
    local newUnits = {}
    for _,v in pairs(units) do
        --Check if it's player
        if object.IsExist(v)
            and object.IsUnit(v)
            and unit.IsPlayer(v)
            then

            local index = FindInTable(v,PlayersTracked)
            if index ~= nil then
                --Player already tracked, just remove from table
                table.insert(newUnits,v)
                table.remove(PlayersTracked,index)
            else
                --New player, must register event
                OnUnitDamageReceivedFunctions[v] = function(p)
                    OnUnitDamageReceived(p,v)
                end
                RegisterEventHandler('EVENT_UNIT_DAMAGE_RECEIVED',OnUnitDamageReceivedFunctions[v],{ target = v, lethal = true })
                table.insert(newUnits,v)
            end
        end
    end
    -- Now we remove the handlers from players not near us
    for _,v in pairs(PlayersTracked) do
        UnregisterEvent('EVENT_UNIT_DAMAGE_RECEIVED',OnUnitDamageReceivedFunctions[v])
    end
    -- And update the PlayersTracked table
    PlayersTracked = newUnits
end

function GetUnitList(first)
    local units = avatar.GetUnitList()
    -- unregister previous events
	if #PlayersTracked > 0 then
		UnregisterEvent('EVENT_UNIT_DAMAGE_RECEIVED')
	end
    -- Empty Players Tracked table
    PlayersTracked = {}
    --Register event for avatar  if it exists
    if avatar.IsExist() then
        RegisterEventHandler('EVENT_UNIT_DAMAGE_RECEIVED',function(p) OnUnitDamageReceived(p,avatar.GetId()) end, { target = avatar.GetId(), lethal = true })
        table.insert(PlayersTracked,avatar.GetId())
    end
    for _,v in pairs(units) do
        --Check if it's player
        if object.IsExist(v)
            and object.IsUnit(v)
            and unit.IsPlayer(v)
        then
            --Add player id to PlayersTracked table
            table.insert(PlayersTracked,v)
            --Register the event
            RegisterEventHandler('EVENT_UNIT_DAMAGE_RECEIVED',function(p) OnUnitDamageReceived(p,v) end, { target = v, lethal = true })
        end
    end
end

-- +================+
-- | Event Handlers |
-- +================+

--EVENT_AVATAR_CREATED
function OnAvatarCreated()
    --Register on damage taken for avatar
    -- RegisterEventHandler('EVENT_UNIT_DAMAGE_RECEIVED',function(p)OnUnitDamageReceived(p)end,{ target = avatar.GetId(), lethal = true })
	-- avatarID = avatar.GetId()
	--Register avatar-related handlers
	--common.RegisterEventHandler(OnUnitDamageReceived, 'EVENT_UNIT_DAMAGE_RECEIVED')
end

function OnUnitDeadChanged(p)
    local unitId = p.unitId
    if FindInTable(unitId,PlayersTracked) then return false end
    if object.IsExist(unitId)
		 and object.IsUnit(unitId)
		 and unit.IsPlayer(unitId)
		 and object.IsDead(unitId) then
            local announceContent = string.format(GTL("died"), FromWS(object.GetName(unitId)))
            local announceType = "killedByFriend"
            if object.IsFriend(unitId) then
				announceType = "friendKilled"
			end
            AddAnnouncement(announceContent,announceType)
    end
end

function GetColors()
	for k,_ in pairs(ColorList) do
		ColorList[k] = ToHexConc(Config[k..'Color'])
	end
	ColorList.blue = 'FF3069F0'
	ColorList.red = 'FFFF401D'
	ColorList.info = 'FFFFFFFF'
end

function Defaults()
    Config.killedByPlayer = false
	Config.playerKilled = true
	Config.killedByFriend = true
	Config.friendKilled = true
	Config.maxAnnouncements = 4
	Config.fontSize = 18
	Config.announcementDistance = 4
	Config.visibleTime = 4500
	Config.killedByPlayerColor = {r = 0; g = 1; b = 0; a = 1}
	Config.playerKilledColor = {r = 1; g = 0; b = 0; a = 1}
	Config.killedByFriendColor = {r = 0; g = 0; b = 1; a = 1}
	Config.friendKilledColor = {r = 1; g = 0.67; b = 0; a = 1 }
	Config.postInChat = true
	Config.announceOnScreen = true
	Config.pos = OriginalPos
	Config.showAbilityName = true
	Config.showDamageAmount = true
	Config.version = Version
	MainPanel:SetPlacementPlain(OriginalPos)
    SaveSettings()
	GetColors()
end

function ToggleDnD()
	MainPanel:SetTransparentInput(DragPanel:IsVisible())
	DragPanel:Show(not DragPanel:IsVisible())
	FirstPos = MainPanel:GetPlacementPlain()
	Config.pos = FirstPos
    SaveSettings()
end

function SaveSettings()
    SetSettings(configSectionName,Config)
end

-- AddonManager Events
function ScriptAddonInfoRequest ( params )
    PrintTable(params)
	if params.target == common.GetAddonName() then
		SendUserEvent("SCRIPT_ADDON_INFO_RESPONSE", { sender = params.target, desc = AddonDescription })
	end
end

function MemRequest ( params )
    PrintTable(params)
	SendUserEvent("U_EVENT_ADDON_MEM_USAGE_RESPONSE", { sender = common.GetAddonName(), memUsage = gcinfo() })
end


-- ConfigWindow events
function ConfigInitEvent ()
	SendUserEvent("CONFIG_INIT_EVENT_RESPONSE", { sender = common.GetAddonName() })
end

function ConfigEvent ()
	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 0, name = 'killedByPlayer', btnType = "T/F", state = Config.killedByPlayer})
	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 1, name = 'playerKilled', btnType = "T/F", state = Config.playerKilled})
	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 2, name = 'killedByFriend', btnType = "T/F", state = Config.killedByFriend})
	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 3, name = 'friendKilled', btnType = "T/F", state = Config.friendKilled})

	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 4, name = 'maxAnnouncements', btnType = "EditLine", value = Config.maxAnnouncements})
	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 5, name = 'fontSize', btnType = "EditLine", value = Config.fontSize})
	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 6, name = 'announcementDistance', btnType = "EditLine", value = Config.announcementDistance})
	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 7, name = 'visibleTime', btnType = "EditLine", value = Config.visibleTime/1000})

	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 8, name = 'killedByPlayerColor', btnType = "Color", color = Config.killedByPlayerColor})
	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 9, name = 'playerKilledColor', btnType = "Color", color = Config.playerKilledColor})
	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 10, name = 'friendKilledColor', btnType = "Color", color = Config.friendKilledColor})
	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 11, name = 'killedByFriendColor', btnType = "Color", color = Config.killedByFriendColor})

	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 12, name = "DnD", btnType = "Simple",})
	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 13, name = 'postInChat', btnType = "T/F", state = Config.postInChat})
	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 14, name = 'announceOnScreen', btnType = "T/F", state = Config.announceOnScreen})
	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 15, name = 'showAbilityName', btnType = "T/F", state = Config.showAbilityName})
	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 16, name = 'showDamageAmount', btnType = "T/F", state = Config.showDamageAmount})

	SendUserEvent("CONFIG_EVENT_RESPONSE", {NoB = 18, name = 'Defaults', btnType = 'Simple'})

end

function ConfigColor(p)
	Config[p.name] = p.color
    SaveSettings()
	GetColors()
end


function ConfigEditLine(p)
    if p.name == "visibleTime" then
        Config[p.name] = tonumber(p.text)*1000
    else
	    Config[p.name] = tonumber(p.text)
    end
    SaveSettings()
    SendUserEvent('CONFIG_OPEN_EVENT_RESPONSE', {sender = common.GetAddonName()})
end

function ConfigButton(p)
	Config[p.name] = p.state
    SaveSettings()
end


function ConfigSimple(p)
	if  p.name == 'Defaults' then
		Defaults()
        SendUserEvent('CONFIG_OPEN_EVENT_RESPONSE', {sender = common.GetAddonName()})
    elseif p.name == 'DnD' then
		ToggleDnD()
	else
        Config[p.name] = p.state
    end
end

function OnSecondTimer()
    -- Get Player list
    GetUnitList()
end

function OnEffectFinished ( event )
	if event.effectType == ET_FADE then
		local fadeStatus = event.wtOwner:GetFade()

		--An announcement was removed
		if fadeStatus < 0.9 then
			--Destroy the widget and remove the nil reference from the list to prevent memory leaks
			event.wtOwner:Show(false)
			event.wtOwner:DestroyWidget()
			--Move all announcements down 1 place
			MoveAnnouncements()
			table.remove(AnnounceList, 1)
		end

		--Pretty clever, huh?
		if fadeStatus > 0.9 and fadeStatus < 1.0 then
			event.wtOwner:PlayFadeEffect( 1.0, 1.0, tonumber(Config.visibleTime), EA_MONOTONOUS_INCREASE )
		end

		if fadeStatus == 1.0 then
			event.wtOwner:PlayFadeEffect(1.0, 0.0, ANNOUNCE_FADE_OUT_TIME, EA_MONOTONOUS_INCREASE)
		end
	end
end

function OnSlashCommand(p)
    local m = FromWS(p.text)
	if m == "/getcur" then
		local ids = avatar.GetCurrencies()
		for i,v in pairs(ids) do
			local desc = avatar.GetCurrencyDescription( v )
			local value = avatar.GetCurrencyValue(v)
			local info = v:GetInfo()
			PrintTable(info)
			-- common.LogInfo("",desc .. ":" .. value)
		end
	end
	if m == "/katesttable" then
		local t1 = {
			number1 = 12,
			string1 = "string test",
			wstring = userMods.ToWString("Wstring value"),
			table = {
				number2 = 13
			}
		}
		PrintTable(t1)
		-- PushToChatSimple(printTable(t1))
	end
	if m == "/kadnd" then
		ToggleDnD()
	elseif m == "/kacw" then
		userMods.SendEvent("CONFIG_OPEN_EVENT_RESPONSE", {sender = common.GetAddonName()})
	elseif m == "/kaver" then
		PushToChatSimple("KillAnnounce: Version "..Version..VDate)
    elseif m == "/kaconfig" then
        PrintTable(Config)
    elseif m == "/katracked" then
        LogInfo(#PlayersTracked)
        PrintTable(PlayersTracked)
    end
end

function Init()
    -- Initialize widgets
    MainPanel = mainForm:GetChildChecked("MainPanel", false)
    MainPanel:Show(true)
    OriginalPos = MainPanel:GetPlacementPlain()
    AnnounceText = MainPanel:GetChildChecked( "Announce", false )
	AnnounceDesc = AnnounceText:GetWidgetDesc()
	AnnounceText:SetVal("value", userMods.ToWString("First Announcement"))
	AnnounceText:Show( false )

    Config = GetSettings(configSectionName)
    if (not Config) or (Config.version ~= Version and (not FindInTable(Config.version, CompatibleWithVersions))) then
		Config = {}
		Defaults()
	else
        GetColors()
    end

    if Config.pos then MainPanel:SetPlacementPlain(Config.pos) end
	DragPanel = MainPanel:GetChildChecked("DragPanel", false)
	DragPanel:SetBackgroundColor({r=0;b=0;g=0;a=.4})
	DragPanel:Show(false)

    

    DnD:Init( DragPanel, MainPanel, true, false)

    FirstPos = MainPanel:GetPlacementPlain()

    AnnouncePadding = Config.fontSize + Config.announcementDistance
    -- Events

    -- Avatar Created
    if avatar.IsExist() then
        OnAvatarCreated()
    else
        OnEvent['EVENT_AVATAR_CREATED'] = { func = OnAvatarCreated }
    end

    -- Addon Manager
    OnEvent['SCRIPT_ADDON_INFO_REQUEST'] = { func = ScriptAddonInfoRequest, params = { target = common.GetAddonName() } }
    OnEvent['U_EVENT_ADDON_MEM_USAGE_REQUEST'] = { func = MemRequest }

    -- Config Window
    OnEvent['CONFIG_INIT_EVENT'] = { func = ConfigInitEvent }
    OnEvent['CONFIG_EVENT_'..AddonName] = { func = ConfigEvent }
    OnEvent['CONFIG_COLOR_'..AddonName] = { func = ConfigColor }
    OnEvent['CONFIG_BUTTON_'..AddonName] = { func = ConfigButton }
    OnEvent['CONFIG_SIMPLE_'..AddonName] = { func = ConfigSimple }
    OnEvent['CONFIG_EDIT_LINE_'..AddonName] = { func = ConfigEditLine }

    -- Slash command
    OnEvent['EVENT_UNKNOWN_SLASH_COMMAND'] = { func = OnSlashCommand }

    -- Other Events
    OnEvent['EVENT_UNIT_DEAD_CHANGED'] = { func = OnUnitDeadChanged }
    OnEvent['EVENT_SECOND_TIMER'] = { func = OnSecondTimer }
    OnEvent['EVENT_EFFECT_FINISHED'] = { func = OnEffectFinished }
    

    RegisterEventHandlers(OnEvent)
    RegisterReactionHandlers(OnReaction)
    
end

Init()