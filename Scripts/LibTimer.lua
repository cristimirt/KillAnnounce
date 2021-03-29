-- +=================================+
-- |LibTimer                         |
-- |Emulate a simple timer function  |
-- |Author: Zurion/Cristi Mirt       |
-- |Version: 1.0.0                   |
-- |Last update: 01-11-2016          |
-- +=================================+

local TimerWidgetDesc = nil
local TimerFunctions = {}
local TimerFunctionsParams = {}

function InitTimer()
    --Need to get a widget description
    local stateAddons = common.GetStateManagedAddons()
    for k,v in pairs(stateAddons) do
        if v.isLoaded then
            local wtAddonMainForm = common.GetAddonMainForm( v.name )
            local children = common.GetAddonMainForm( v.name ):GetNamedChildren()
            for i,j in ipairs(children) do
                TimerWidgetDesc = j:GetWidgetDesc()
                if TimerWidgetDesc then
                    break
                end
            end
            if TimerWidgetDesc then
                break
            end
        end
    end
end

function ExecuteTimerFunction(params)
    local widgetName = params.wtOwner:GetName()
    if TimerFunctions[widgetName] ~= nil then
        local func = TimerFunctions[widgetName]
        if TimerFunctionsParams[widgetName] ~= nil then
            local params = TimerFunctionsParams[widgetName]
            func(unpack(params))
            TimerFunctionsParams[widgetName] = nil
        else
            func()
        end
        TimerFunctions[widgetName] = nil
        params.wtOwner:DestroyWidget()
    end
end

function StartTimer(func,time,...)
    if not TimerWidgetDesc then return end
    local wtTimerWidget = mainForm:CreateWidgetByDesc( TimerWidgetDesc )
    wtTimerWidget:Show(false)
    local timerWidgetName = "TimerWidget" .. tostring(common.GetRandFloat( 10000.0, 100000.0 ))
    wtTimerWidget:SetName(timerWidgetName)
    TimerFunctions[timerWidgetName] = func
    TimerFunctionsParams[timerWidgetName] = {select(1,...)}
    wtTimerWidget:PlayFadeEffect( 1.0, 1.0, time, EA_MONOTONOUS_INCREASE )
end

common.RegisterEventHandler( ExecuteTimerFunction , "EVENT_EFFECT_FINISHED")

InitTimer()
