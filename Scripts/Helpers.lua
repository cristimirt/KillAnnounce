-- +=============+
-- TABLE HELPERS |
-- +=============+

-- +========================================================+
-- | Print table to log and returns it as a string          |
-- | @t : table (required)                                  |
-- | @nr : current iteration number (internal only)         |
-- | @tbl : parent table (for printing table name)          |
-- | @returnOnly : if you only want the output as a string, |
-- |             without it being printed to the log file   |
-- +========================================================+
function PrintTable( t, nr, tbl, returnOnly)
	if t == nil or type(t) ~= "table" then 
		return false 
	end
    returnOnly = returnOnly or false
	tbl = tbl or _G
	nr = nr or 0
	local tab = ""
    local bufferTable = {}
    local stringOutput = ""
	for i=0,nr-1 do tab = tab.."  " end
    local tableName = ""
    for k, v in pairs(tbl) do
        if v == t then
            tableName = k
            break
        end
      end
    if nr == 0 then
        table.insert(bufferTable,"Printing table " ..tostring(tableName))
    end
    table.insert(bufferTable,"{")
	-- common.LogInfo("",tab..tostring(getTableName(t,tbl)).." = {")
	for i,v in pairs(t) do
		if type(v) == "string" then
            table.insert(bufferTable,tab.."  "..tostring(i).." = "..v.."("..tostring(type(v))..")")
		elseif common.IsWString(v) then
            table.insert(bufferTable,tab.."  "..tostring(i).." = "..userMods.FromWString(v) .."(WString)")
		elseif type(v) == "number" or type(v) == "boolean" then
            table.insert(bufferTable,tab.."  "..tostring(i).." = "..tostring(v).."("..tostring(type(v))..")")
		elseif type(v) == "table" then
            table.insert(bufferTable,tab.."  "..tostring(i).." = "..PrintTable(v,nr+1, t, true))
		elseif type(v) == "userdata" then
            table.insert(bufferTable,tab.."  "..tostring(i).." is Userdata:"..common.GetApiType(v))
		else 
            table.insert(bufferTable,tab.."  "..tostring(i).." : " .. type(v))
		end
	end
    table.insert(bufferTable,tab.."}")
    for i,v in pairs(bufferTable) do
        stringOutput = stringOutput .. v
        if i < #bufferTable then
           stringOutput = stringOutput  .. "\n"
        end
    end
    if not returnOnly then
        common.LogInfo("",stringOutput)
    end
    return stringOutput
end

-- +==================================================+
-- | Get name of a table                              |
-- | Only works if the table is part of another table |
-- | @t : table                                       |
-- | @tbl : parent table                              |
-- +==================================================+
function GetTableName(t, tbl)
    for k, v in pairs(tbl) do
      if v == t then
            return k
      end
    end
    return nil
end

---Get index of value in a table or nil
---@param needle string Value to search for
---@param stack table Table in what to search value in
---@param compareF function Function used for comparing two values
---@return number | nil
function FindInTable(needle, stack,compareF)
    compareF = compareF or function(a,b) return a == b end
    for i,v in pairs(stack) do
        if compareF(v,needle) then
            return i
        end
    end
    return nil
end

-- +=================+
-- | GENERAL HELPERS |
-- +=================+

-- +==============================+
-- | Shorthand for common.LogInfo |
-- +==============================+
function LogInfo(...)
    local args = {...}
    if #args == 0 then return false end
    for i,v in pairs(args) do
        if type(v) == 'string' or common.IsWString(v) then
            --Do nothing
        else
            args[i] = tostring(v)
        end
    end
	common.LogInfo("",unpack(args))
end

-- +==========================+
-- | Get text from game files |
-- | @path : text file path   |
-- +==========================+
function GetTextFromFile(path)
	local VT = common.CreateValuedText()
	VT:SetFormat(userMods.ToWString("<html><t href='"..path.."'/></html>"))
	local text
	text = userMods.FromWString(common.ExtractWStringFromValuedText(VT))
	return text
end

-- +===========================+
-- |Deep compare two variables |
-- +===========================+
function Compare(t1, t2)
    --TODO we have to account for usertypes
    -- If they're the same object, return true
    if t1 == t1 then return true end
    -- One of them is nil, return false
	if t1 == nil or t2 == nil then return false end
    -- If their type differs, return false
	if type(t1) ~= type(t2) then return false end
	if type(t1) == "string" or type(t1) == "number" or type(t1) == "boolean" then
        -- For basic types, simple equality will do
		if not (t1 == t2) then
			return false
		end
	else
		for i, _ in pairs(t1) do
			local type1 = type(t1[i])
			local type2 = type(t2[i])
			if type1 ~= type2 then
				return false
			else
				if type1 == "string" or type1 == "number" or type1 == "boolean" then
					if t2[i] == nil or not (t1[i] == t2[i]) then
						return false
					end
				elseif type1 == "table" then
					if not Compare(t1[i], t2[i]) then
						return false
					end
				else
					if t1[i].IsEqual == nil then break
					else
						if not t1[i]:IsEqual(t2[i]) then
							return false
						end
					end
				end
			end
		end
		for i, _ in pairs(t2) do
			local type1 = type(t1[i])
			local type2 = type(t2[i])
			if type1 ~= type2 then
				return false
			else
				if type2 == "string" or type2 == "number" or type2 == "boolean" then
					if t1[i] == nil or not (t2[i] == t1[i]) then
					 	return false
					end
				elseif type2 == "table" then
					if not Compare(t2[i], t1[i]) then
						return false
					end
				else
					if t2[i].IsEqual == nil then break
					else
						if not t2[i]:IsEqual(t1[i]) then
							return false
						end
					end
				end
			end
		end
	end
	return true
end

-- +===============+
-- | Event Handler |
-- +===============+
function RegisterEventHandlers( handlers )
	for event, handler in pairs(handlers) do
        local func = nil
        local params = {}
        if type(handler) == 'table' then
            func = handler.func or nil
            params = handler.params or {}
        else
            func = handler or nil
        end
        if func ~= nil then
            RegisterEventHandler(event, func, params)
        end
	end
end

---@param event string  Event name
---@param handler function   Function to execute
---@param params table  Paramteres to filter event
function RegisterEventHandler(event, handler, params)
    common.RegisterEventHandler(handler,event,params)
end

---Unregisters a handler from an event. If no Handler is provided, 
---unregisters all handlers from the event
---@param event string Event name
---@param handler function Handler to unregister
function UnregisterEvent(event,handler)
    if handler ~= nil then
        common.UnRegisterEventHandler(handler,event)
    else
        common.UnRegisterEvent(event)
    end
end

-- +==================+
-- | Reaction Handler |
-- +==================+
function RegisterReactionHandlers( handlers )
	for reaction, handler in pairs(handlers) do
        RegisterReactionHandler(reaction, handler)
	end
end
function RegisterReactionHandler(reaction, handler)
    common.RegisterReactionHandler( handler, reaction )
end

function UnregisterReaction(event,handler)
    common.UnRegisterReactionHandler(handler,event)
end



function SendUserEvent( eventName, params )
    params = params or {}
    userMods.SendEvent( eventName, params)
end

--Shorthand for userMods.ToWString
function ToWS( arg )
	return userMods.ToWString(arg)
end

-- Shorthand for userMods.FromWString
function FromWS( arg )
	return userMods.FromWString(arg)
end

-- +--------+
-- |Rounding|
-- +--------+
function Round(val, decimal)
    if val == 0 then return 0 end
    local exp = decimal and 10^decimal or 1
    return math.ceil(val * exp - 0.5) / exp
end

function IsAddonActive(addonName)
	local addons = common.GetStateManagedAddons ()
	for _,v in pairs(addons) do
		if v.name == "UserAddon/"..addonName and v.isLoaded then
			return true
		end
	end
	return false
end

-- Shorthand for userMods.GetAvatarConfigSection
function GetSettings( name,global )
    if global then
        return userMods.GetGlobalConfigSection( name )
    else   
        return userMods.GetAvatarConfigSection( name )
    end
end

-- Shorthand for userMods.SetAvatarConfigSection
function SetSettings( name,value,global )
    if global then
        userMods.SetGlobalConfigSection( name,value )
    else
	    userMods.SetAvatarConfigSection( name,value )
    end
end

---Push-to-Chat

function PushToChat(message,size,color)
	local fsize = size or 18
	local textFormat = string.format('<header color="0x%s" fontsize="%s" outline="1" shadow="1"><rs class="class">%s</rs></header>',color, tostring(fsize),message)
	local VT = common.CreateValuedText()
	VT:SetFormat(ToWS(textFormat))
	local chatContainer = stateMainForm:GetChildUnchecked("ChatLog", false):GetChildUnchecked("Area", false):GetChildUnchecked("Panel02",false):GetChildUnchecked("Container", false)
	chatContainer:PushFrontValuedText(VT)
end

function PushToChatSimple(message)
	local textFormat = string.format("<html fontsize='18'><rs class='class'>%s</rs></html>",message)
	local VT = common.CreateValuedText()
	VT:SetFormat(ToWS(textFormat))
	VT:SetClassVal("class", "LogColorYellow")
	local chatContainer = stateMainForm:GetChildUnchecked("ChatLog", false):GetChildUnchecked("Area", false):GetChildUnchecked("Panel02",false):GetChildUnchecked("Container", false)
	chatContainer:PushFrontValuedText(VT)
end

--Stuff taken from Ciuine's NCT, I'm far too lazy to rewrite all this from scratch
function ToHexConc(N)
	if not N then
		N = {r = 0.86; g = 0.82; b = 0.078; a = 1}
	end
	local color = ""..ToHex(N.a*255)..ToHex(N.r*255)..ToHex(N.g*255)..ToHex(N.b*255)
	return color
end


function ToHex(N) --Modified version of someone else's free source C code. CREATES HEX FROM RGBA
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