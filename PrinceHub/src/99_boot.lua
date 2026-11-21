-- ############################################################
-- BOOT
-- ############################################################
PrinceNewTabs.prepareHubConfig()

local hubOk, hubErr = pcall(Modules.Hub)
if not hubOk then
	warn("[Prince Hub] Hub UI error: " .. tostring(hubErr))
end

PrinceNewTabs.boot()
