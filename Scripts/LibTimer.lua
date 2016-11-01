-- +=================================+
-- |LibTimer                         |
-- |Emulate a simple timer function  |
-- |Author: Zurion/Cristi Mirt       |
-- |Last update: 01-11-2016          |
-- +=================================+

Global("timerWidgetDesc",nil)
Global("timerFunctions",{})
Global("timerFunctionsParams",{})

function InitTimer()
    --Need to get a widget description
    local stateAddons = common.GetStateManagedAddons()
    for k,v in pairs(stateAddons) do
        if v.isLoaded then
            local wtAddonMainForm = common.GetAddonMainForm( v.name )
            local wtChild = wtAddonMainForm:GetNamedChildren()[0]
            timerWidgetDesc = wtChild:GetWidgetDesc()
            break;
        end
    end
end

function ExecuteTimerFunction(params)
    local widgetName = params.wtOwner:GetName()
    if timerFunctions[widgetName] ~= nil then
        local func = timerFunctions[widgetName]
        if timerFunctionsParams[widgetName] ~= nil then
            local params = timerFunctionsParams[widgetName]
            func(unpack(params))
            timerFunctionsParams[widgetName] = nil
        else
            func()
        end
        timerFunctions[widgetName] = nil
        params.wtOwner:DestroyWidget()
    end
end

function StartTimer(func,time,...)
    local wtTimerWidget = mainForm:CreateWidgetByDesc( timerWidgetDesc )
    wtTimerWidget:Show(false)
    local timerWidgetName = "TimerWidget" .. tostring(common.GetRandFloat( 10000.0, 100000.0 ))
    wtTimerWidget:SetName(timerWidgetName)
    timerFunctions[timerWidgetName] = func
    timerFunctionsParams[timerWidgetName] = {select(1,...)}
    wtTimerWidget:PlayFadeEffect( 1.0, 1.0, time, EA_MONOTONOUS_INCREASE )
end

common.RegisterEventHandler( ExecuteTimerFunction , "EVENT_EFFECT_FINISHED")

InitTimer()
