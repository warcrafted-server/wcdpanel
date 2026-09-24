WCDPanel = {}
WCDPanel.plugins = {}
WCDPanel.pluginOrder = {}

local L = LibStub("AceLocale-3.0"):GetLocale("wcdpanel")

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" and addonName == "wcdpanel" then
		WCDPanel:InitDB()
	elseif event == "PLAYER_LOGIN" then
		WCDPanel:OnLogin()
	end
end)

function WCDPanel:OnLogin()
	self:Print(L["wcdpanel loaded. Type /wcd for options."])
end

SLASH_WCDPANEL1 = "/wcd"
SLASH_WCDPANEL2 = "/wcdpanel"
SlashCmdList["WCDPANEL"] = function()
	WCDPanel:Print(L["wcdpanel loaded. Type /wcd for options."])
end

function WCDPanel:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33aaffwcdpanel|r: " .. tostring(msg))
end
