-- ############################################################
-- ############################################################
--   NEW TABS: Kaitun + Cupid + Waves  (داخل واجهة الهب الكامل)
--   - التبويب Kaitun  -> يشغّل MODULE: Kaitun
--   - التبويب Cupid   -> يشغّل MODULE: Cupid
--   - التبويب Waves   -> يشغّل MODULE: Waves (دنجن الأمواج، سولو/بارتي)
--   - التبويب Impel   -> يشغّل MODULE: Impel (سكربت zephyron للـ Impel Down بطيران الكايتون)
--   - زر X على القائمة + مربع صغير P يرجّعها
--   الإعدادات تنحفظ بـ PrinceHubNewTabs.json حتى تكمل بعد التيليبورت.
-- ############################################################
-- ############################################################

local PN_Players     = game:GetService("Players")
local PN_UIS         = game:GetService("UserInputService")
local PN_Http        = game:GetService("HttpService")
local PN_LocalPlayer = PN_Players.LocalPlayer
local PN_SAVE_FILE   = "PrinceHubNewTabs.json"

local function PN_deepCopy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = PN_deepCopy(v) end
	return out
end

local function PN_get(tbl, ...)
	local cur = tbl
	for _, key in ipairs({ ... }) do
		if type(cur) ~= "table" then return nil end
		cur = cur[key]
	end
	return cur
end

local function PN_pick(value, default)
	if value == nil then return default end
	return value
end

local function PN_indexOf(list, value)
	for i, v in ipairs(list) do
		if v == value then return i end
	end
	return nil
end

-- الـ labels بالواجهة سطر واحد (حوالي 34 حرف)، فنقص النص الطويل
local function PN_cut(text, maxLen)
	text = tostring(text == nil and "" or text)
	if #text > maxLen then
		return string.sub(text, 1, maxLen)
	end
	return text
end

-- ------------------------------------------------------------
-- Config اللي حطيته بالـ loader (قبل ما أي سكربت يغيّره)
-- ------------------------------------------------------------
local PN_UserConfig = PN_deepCopy(getgenv().PrinceHubUserConfig or getgenv().Config) or {}
getgenv().PrinceHubUserConfig = PN_UserConfig
local PN_UMain = PN_UserConfig.MAIN or {}

