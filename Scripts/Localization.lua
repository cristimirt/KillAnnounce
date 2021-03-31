Global("Locales",{eng_eu = {}})

-- To add/modify translations, please edit the Locales.lua file
-- For certain languages you might need a special encoding. This is what I recommend
-- English : Latin-1/UTF-8
-- Russian : Win-1251
-- German : Win-1252
-- French : Win-1252
-- Turkish : Win-1254

-- Below is an example

-- Locales["eng_eu"] = {
--     ["testString"] = "This is the english translation"
-- }


local Localization = common.GetLocalization()
local configSectionName = "localization"

-- +=========================================================================+
-- | Get localization of a string                                            |
-- | GTL stands for GetTextLocalized                                         |
-- | @string : unique string identifier                                      |
-- | @locale : locale code. Optional. Defaults to game or saved localization |
-- | @fallback : Fallback string if no localization is found                 |
-- +=========================================================================+
function GTL(string, locale, fallback)
    if string == nil then return "" end
    locale = locale or GetLocalization() or "eng_eu"
    fallback = fallback or string
    return Locales[ locale ][ string ] or Locales[ "eng_eu" ][ string ] or fallback
end

-- +===============================================+
-- | Changes the localization of the current addon |
-- | @string : The code for the new localization   |
-- | Supported codes are eng_us,rus,fra,ger,tr     |
-- +===============================================+
function SetLocalization(new_locale)
    Localization = new_locale
    SaveLocalization()
end

-- +=============================+
-- | Get saved localization code |
-- +=============================+
function GetLocalization()
    return Localization
end

-- +====================================================+
-- | Resets the localization to the client localization |
-- +====================================================+
function ResetLocalization()
    Localization = common.GetLocalization()
    SaveLocalization()
end

-- +===================================+
-- | Saves localization code to config |
-- +===================================+
function SaveLocalization()
    userMods.SetAvatarConfigSection(configSectionName,{locale_code=Localization})
end

-- +=========================================+
-- | Loads the localization code from config |
-- +=========================================+
function LoadLocalizationFromConfig()
    local configSection = userMods.GetAvatarConfigSection(configSectionName)
    if configSection and configSection.locale_code ~= nil then
        Localization = configSection.locale_code
    end
end

-- +===================================================+
-- | Checks if the given string is a valid locale code |
-- +===================================================+
function IsValidLocale(locale)
	return Locales[locale] ~= locale
end

LoadLocalizationFromConfig()


