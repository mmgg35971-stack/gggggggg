-- ############################################################
-- BOOT
-- ############################################################
PrinceNewTabs.prepareHubConfig()

local hubOk = PH_try("Hub UI", Modules.Hub) -- [PRINCE HUB v18] يسجل الخطأ بسجل الهب

PrinceNewTabs.boot()
