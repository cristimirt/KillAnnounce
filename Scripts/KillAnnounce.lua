--------------------------------------------------------------------------------
-- GLOBALS
--------------------------------------------------------------------------------

--Widgets
local AnnounceText

--Variables

local config
local avatarID
local announceDesc
local announceList = {}
local announceContent = ''
local announceCount = 0
local moving = false
local avatarMarkId
local progressInfo
local DragPanel
local MainPanel
local originalPos
local version = "2.3.4"
local vdate = "(02.11.2016)"
local compatible = { }
local tracked = { }

local colorList = {
	killedByPlayer = 0,
	playerKilled = 0,
	killedByFriend = 0,
	friendKilled = 0
}

--Announce constants

local ANNOUNCE_FADE_IN_TIME = 300
local ANNOUNCE_FADE_OUT_TIME = 900
local firstPos = {}
local distance = 0

--------------------------------------------------------------------------------
-- EVENT HANDLERS
--------------------------------------------------------------------------------

--EVENT_AVATAR_CREATED
function OnAvatarCreated ()
	avatarID = avatar.GetId()
	--Register avatar-related handlers
	--common.RegisterEventHandler(OnUnitDamageReceived, 'EVENT_UNIT_DAMAGE_RECEIVED')
end


--EVENT_UNIT_DAMAGE_RECEIVED
function OnUnitDamageReceived(damage)
	if damage.lethal then
		if damage.target
		 and object.IsExist(damage.target)
		 and object.IsUnit(damage.target)
		 and unit.IsPlayer(damage.target)
		then
			if config['experimental'] then
				tracked[damage.target] = true
			end
			if damage.target == avatarID then
				playerKilled(damage.source, fromWS(damage.sourceName), fromWS(damage.ability),damage.amount)
			else
				unitKilled(damage.source, damage.target, object.IsFriend(damage.target), fromWS(damage.sourceName), fromWS(damage.ability),damage.amount)
			end
		end
	end
end

function OnUnitDeadChangedTimed(unitId)
	if tracked[unitId] ~= nil then
		tracked[unitId] = nil
	else
		if object.IsExist(unitId) then
			local announceContent = string.format(GTL("died"), fromWS(object.GetName(unitId)))
			local announceType = "killedByFriend"
			if object.IsFriend(unitId) then
				announceType = "friendKilled"
			end
			addAnnouncement(announceType,announceContent)
		end
	end
end

--EVENT_UNIT_DEAD_CHANGED
function OnUnitDeadChanged(event)
	if config['experimental'] then
		local unitId = event.unitId
		if object.IsExist(unitId)
		 and object.IsUnit(unitId)
		 and unit.IsPlayer(unitId)
		 and object.IsDead(unitId)
		then
			StartTimer(OnUnitDeadChangedTimed,1000,unitId)
		end
	end
end


--EVENT_EFFECT_FINISHED
function onEffectFinished ( event )
	if event.effectType == ET_FADE then
		local fadeStatus = event.wtOwner:GetFade()

		--An announcement was removed
		if fadeStatus < 0.9 then
			--Destroy the widget and remove the nil reference from the list to prevent memory leaks
			event.wtOwner:Show(false)
			event.wtOwner:DestroyWidget()
			--Move all announcements down 1 place
			moveAnnouncements()
			table.remove(announceList, 1)
			announceCount = table.getn(announceList)
		end

		--Pretty clever, huh?
		if fadeStatus > 0.9 and fadeStatus < 1.0 then
			event.wtOwner:PlayFadeEffect( 1.0, 1.0, tonumber(config['visibleTime']), EA_MONOTONOUS_INCREASE )
		end

		if fadeStatus == 1.0 then
			event.wtOwner:PlayFadeEffect(1.0, 0.0, ANNOUNCE_FADE_OUT_TIME, EA_MONOTONOUS_INCREASE)
		end
	end
end

--------------------------------------------------------------------------------
-- FUNCTIONS
--------------------------------------------------------------------------------

function playerKilled (killerID,sourceName,ability,damage)
	if killerID and object.IsExist(killerID) and object.IsUnit(killerID) then
		--local killer = object.GetName(killerID)
		local killer = sourceName
		local abilityName = " ("..ability..")"
		if damage > 1000000 then
			damage = round(damage / 1000000,2)
			damage = damage .. "M"
		elseif damage > 1000 then
			damage = round(damage / 1000,2)
			damage = damage .. "K"
		end
		local damageAmount = " ("..damage..")"
		if not config['showDamageAmount'] then damageAmount = "" end
		--To prevent the pet name from showing up instead of the owner in the announcement
		if unit.IsPet(killerID) then
			killerID = unit.GetPetOwner(killerID)
			killer = object.GetName(killerID)
			abilityName = " (Pet)"
		end
		if not config['showAbilityName'] then abilityName = "" end
		announceContent = string.format(GTL("You were killed by")..abilityName..damageAmount, killer)
		addAnnouncement('playerKilled',announceContent)
	end
end

function unitKilled (killerID, victimID, isFriendly, sourceName, ability, damage)
	--if killerID == nil then return end
	if victimID and unit.IsPet(victimID) then return end
	if killerID and object.IsExist(killerID) and object.IsExist(victimID) and object.IsUnit(killerID) and object.IsUnit(victimID) then
		--local killer = userMods.FromWString(object.GetName(killerID))
		local killer = sourceName
		local victim = fromWS(object.GetName(victimID))
		local abilityName = " ("..ability..")"
		if damage > 1000000 then
			damage = round(damage / 1000000,2)
			damage = damage .. "M"
		elseif damage > 1000 then
			damage = round(damage / 1000,2)
			damage = damage .. "K"
		end
		local damageAmount = " ("..damage..")"
		if not config['showDamageAmount'] then damageAmount = "" end
		if unit.IsPet(killerID) then
			killerID = unit.GetPetOwner(killerID)
			killer = fromWS(object.GetName(killerID))
			abilityName = " (Pet)"
		end
		if not config['showAbilityName'] then abilityName = "" end
		if killerID == avatarID and config['killedByPlayer'] then --The unit was killed by the player
			announceContent = string.format(GTL("You killed")..abilityName..damageAmount, victim)
			addAnnouncement('killedByPlayer',announceContent)
			return
		end
		announceContent = string.format(GTL("killed")..abilityName..damageAmount, killer, victim)
		if isFriendly then --A friendly unit was killed
			if config['friendKilled'] then
				addAnnouncement('friendKilled',announceContent)
				--return
			end
		elseif config['killedByFriend'] then --An enemy was killed by a friendly
			addAnnouncement('killedByFriend',announceContent)
		end
	end
end


function addAnnouncement (killType, content)
	if config['announceOnScreen'] then
		--Create and format the announcement
		local announcement = mainForm:CreateWidgetByDesc(announceDesc)
		local form = string.format('<header color="0x%s" alignx="center" fontsize="%s" outline="1" shadow="1"><rs class="class"><r name="value"/></rs></header>', colorList[killType], tostring(config['fontSize']))
		local placement = nil

		announcement:SetFormat(toWS(form))
		--announcement:SetVal('value', toWS(announceContent))
		announcement:SetVal('value', toWS(content))

		table.insert(announceList, announcement)
		announceCount = table.getn(announceList)

		--Check where to put the announcememt
		if announceCount > 1 then
			placement = announceList[announceCount-1]:GetPlacementPlain()
			placement.posY = placement.posY - distance
		else
			placement = firstPos
		end
		--Show the announcement
		MainPanel:Show(true)
		announcement:SetPlacementPlain(placement)
		announcement:Show(true)
		announcement:PlayFadeEffect( 0.0, .999, ANNOUNCE_FADE_IN_TIME, EA_MONOTONOUS_INCREASE)

		--Remove the bottom announcement
		if announceCount > config['maxAnnouncements'] then
			if not moving then
				announceList[1]:PlayFadeEffect(1.0, 0.0, ANNOUNCE_FADE_OUT_TIME, EA_MONOTONOUS_INCREASE)
			end
		end
		if announceCount == 0 then MainPanel:Show(false) end
	end
	if config['postInChat'] then
		PushToChat(content,18,colorList[killType])
	end
end


function moveAnnouncements ()
	moving = true
	for _, a in pairs(announceList) do
		local startPos = a:GetPlacementPlain()
		local endPos = startPos
		endPos.posY = endPos.posY + distance
		a:PlayMoveEffect( startPos, endPos, 300, EA_MONOTONOUS_INCREASE )
	end
	moving = false
end


function getColors ()
	for k,_ in pairs(colorList) do
		colorList[k] = toHexConc(config[k..'Color'])
	end

	colorList.blue = 'FF3069F0'
	colorList.red = 'FFFF401D'
	colorList.info = 'FFFFFFFF'
end


--Stuff taken from Ciuine's NCT, I'm far too lazy to rewrite all this from scratch
function toHexConc(N)
	if not N then
		N = {r = 0.86; g = 0.82; b = 0.078; a = 1}
	end
	local color = ""..toHex(N.a*255)..toHex(N.r*255)..toHex(N.g*255)..toHex(N.b*255)
	return color
end


function toHex(N) --Modified version of someone else's free source C code. CREATES HEX FROM RGBA
	if N==nil then
		return "00"
	elseif N==0 then
		return "00"
	else
		N=math.max(0,N)
		N=math.min(N,255)
		N=math.ceil(N)
		return string.sub("0123456789ABCDEF", 1 + (N- (N - math.floor(N/16)*16))/16, 1 + (N- (N - math.floor(N/16)*16))/16)..string.sub("0123456789ABCDEF", 1 + (N - math.floor(N/16)*16), 1 + (N - math.floor(N/16)*16))
	end
end


function defaults ()
	config['killedByPlayer'] = true
	config['playerKilled'] = true
	config['killedByFriend'] = true
	config['friendKilled'] = true
	config['maxAnnouncements'] = 4
	config['fontSize'] = 18
	config['announcementDistance'] = 4
	config['visibleTime'] = 4500
	config['killedByPlayerColor'] = {r = 0.86; g = 0.82; b = 0.078; a = 1}
	config['playerKilledColor'] = {r = 0.8; g = 0.06; b = 0.06; a = 1}
	config['killedByFriendColor'] = {r = 0.86; g = 0.82; b = 0.078; a = 1}
	config['friendKilledColor'] = {r = 0.8; g = 0.06; b = 0.06; a = 1 }
	config['postInChat'] = true
	config['announceOnScreen'] = true
	config['pos'] = originalPos
	config['showAbilityName'] = true
	config['showDamageAmount'] = true
	config['version'] = version
	config['experimental'] = true
	MainPanel:SetPlacementPlain(originalPos)
	userMods.SetAvatarConfigSection('KillAnnounce', config)
	getColors()
end


--------------------------------------------------------------------------------
-- ADDON MANAGER
--------------------------------------------------------------------------------

function SCRIPT_ADDON_INFO_REQUEST ( params )
	if params.target == common.GetAddonName() then
		userMods.SendEvent( "SCRIPT_ADDON_INFO_RESPONSE",
			{
				sender = params.target,
				desc = "Shows a notification when you or someone near you kills a player"
			} )
	end
end

function MemRequest ( params )
	userMods.SendEvent( "U_EVENT_ADDON_MEM_USAGE_RESPONSE", { sender = common.GetAddonName(), memUsage = gcinfo() } )
end


--------------------------------------------------------------------------------
-- CONFIG WINDOW
--------------------------------------------------------------------------------

function ConfigInitEvent ()
	userMods.SendEvent("CONFIG_INIT_EVENT_RESPONSE", { sender = common.GetAddonName() })
end


function ConfigEvent ()
	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 0, name = 'killedByPlayer', btnType = "T/F", state = config['killedByPlayer']})
	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 1, name = 'playerKilled', btnType = "T/F", state = config['playerKilled']})
	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 2, name = 'killedByFriend', btnType = "T/F", state = config['killedByFriend']})
	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 3, name = 'friendKilled', btnType = "T/F", state = config['friendKilled']})

	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 4, name = 'maxAnnouncements', btnType = "EditLine", value = config['maxAnnouncements']})
	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 5, name = 'fontSize', btnType = "EditLine", value = config['fontSize']})
	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 6, name = 'announcementDistance', btnType = "EditLine", value = config['announcementDistance']})
	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 7, name = 'visibleTime', btnType = "EditLine", value = config['visibleTime']})

	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 8, name = 'killedByPlayerColor', btnType = "Color", color = config['killedByPlayerColor']})
	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 9, name = 'playerKilledColor', btnType = "Color", color = config['playerKilledColor']})
	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 10, name = 'friendKilledColor', btnType = "Color", color = config['friendKilledColor']})
	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 11, name = 'killedByFriendColor', btnType = "Color", color = config['killedByFriendColor']})

	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 12, name = "DnD", btnType = "Simple",})
	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 13, name = 'postInChat', btnType = "T/F", state = config['postInChat']})
	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 14, name = 'announceOnScreen', btnType = "T/F", state = config['announceOnScreen']})
	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 15, name = 'showAbilityName', btnType = "T/F", state = config['showAbilityName']})
	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 16, name = 'showDamageAmount', btnType = "T/F", state = config['showDamageAmount']})

	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 17, name = "experimental", btnType = 'T/F', state = config['experimental']})

	userMods.SendEvent("CONFIG_EVENT_RESPONSE", {NoB = 18, name = 'Defaults', btnType = 'Simple'})


end


function ConfigButton (p)
	config[p.name] = p.state
	userMods.SetAvatarConfigSection('KillAnnounce', config)
end


function ConfigSimple (p)
	if  p.name == 'Defaults' then
		defaults()
		userMods.SendEvent("CONFIG_OPEN_EVENT_RESPONSE", {sender = common.GetAddonName()})
		userMods.SendEvent("CONFIG_OPEN_EVENT_RESPONSE", {sender = common.GetAddonName()})
	end
	if p.name == 'DnD' then
		ToggleDnD()
	end
end

function ToggleDnD()
	MainPanel:SetTransparentInput(DragPanel:IsVisible())
	DragPanel:Show(not DragPanel:IsVisible())
	firstPos = MainPanel:GetPlacementPlain()
	config['pos'] = firstPos
	userMods.SetAvatarConfigSection('KillAnnounce', config)
end


function ConfigColor (p)
	config[p.name] = p.color
	userMods.SetAvatarConfigSection('KillAnnounce', config)
	getColors()
end


function ConfigEditLine (p)
	config[p.name] = tonumber(p.text)
	userMods.SetAvatarConfigSection('KillAnnounce', config)
	userMods.SendEvent("CONFIG_OPEN_EVENT_RESPONSE", {sender = common.GetAddonName()})
	userMods.SendEvent("CONFIG_OPEN_EVENT_RESPONSE", {sender = common.GetAddonName()})
end

function OnSlash(p)
	local m = fromWS(p.text)
	if m == "/kadnd" then
		ToggleDnD()
	elseif m == "/kacw" then
		userMods.SendEvent("CONFIG_OPEN_EVENT_RESPONSE", {sender = common.GetAddonName()})
	elseif m == "/ka ver" then
		PushToChatSimple("KillAnnounce: Version "..version..vdate)
	end
end



--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------
function Init()
	--Initialize widgets
	MainPanel = mainForm:GetChildChecked("MainPanel", false)
	MainPanel:Show(true)
	originalPos = MainPanel:GetPlacementPlain()
	AnnounceText = MainPanel:GetChildChecked( "Announce", false )
	announceDesc = AnnounceText:GetWidgetDesc()
	AnnounceText:SetVal("value", userMods.ToWString("First Announcement"))
	AnnounceText:Show( false )

	config = userMods.GetAvatarConfigSection('KillAnnounce')
	if not config or (config['version'] ~= version and not isInTable(compatible, config['version'])) then
		config = {}
		defaults()
	end
	if config['pos'] then MainPanel:SetPlacementPlain(config['pos']) end
	DragPanel = MainPanel:GetChildChecked("DragPanel", false)
	DragPanel:SetBackgroundColor({r=0;b=0;g=0;a=.4})
	DragPanel:Show(false)

	DnD:Init( DragPanel, MainPanel, true, false)

	firstPos = MainPanel:GetPlacementPlain()

	getColors()
	distance = config['fontSize'] + config['announcementDistance']


	--DnD:Init(653, AnnounceText, AnnounceText)

	--Check if the avatar was created
	common.RegisterEventHandler(OnAvatarCreated,"EVENT_AVATAR_CREATED")
	if avatar.IsExist() then OnAvatarCreated() end

	--Register AddonManager and ConfigWindow handlers
	common.RegisterEventHandler( SCRIPT_ADDON_INFO_REQUEST, "SCRIPT_ADDON_INFO_REQUEST" )
	common.RegisterEventHandler(MemRequest, "U_EVENT_ADDON_MEM_USAGE_REQUEST")

	common.RegisterEventHandler( ConfigInitEvent, "CONFIG_INIT_EVENT" )
	common.RegisterEventHandler( ConfigEvent, "CONFIG_EVENT_"..common.GetAddonName())
	common.RegisterEventHandler( ConfigColor, "CONFIG_COLOR_"..common.GetAddonName())
	common.RegisterEventHandler( ConfigButton, "CONFIG_BUTTON_"..common.GetAddonName())
	common.RegisterEventHandler( ConfigSimple, "CONFIG_SIMPLE_"..common.GetAddonName())
	common.RegisterEventHandler( ConfigEditLine, "CONFIG_EDIT_LINE_"..common.GetAddonName())
	common.RegisterEventHandler( OnSlash, "EVENT_UNKNOWN_SLASH_COMMAND" )

	--Register the rest of the event handlers

	common.RegisterEventHandler(onEffectFinished, "EVENT_EFFECT_FINISHED")
	common.RegisterEventHandler(OnUnitDamageReceived, 'EVENT_UNIT_DAMAGE_RECEIVED')
	common.RegisterEventHandler(OnUnitDeadChanged, 'EVENT_UNIT_DEAD_CHANGED')
end


--------------------------------------------------------------------------------
Init()
--------------------------------------------------------------------------------
