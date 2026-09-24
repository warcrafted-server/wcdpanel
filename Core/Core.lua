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

-- Reconstruye barras y elementos desde cero contra el perfil activo: se llama al entrar y
-- cada vez que AceDB cambia de perfil (copia, reinicio o elegir otro).
function WCDPanel:ReloadProfile()
	for _, runtime in pairs(self.bars) do
		runtime.frame:Hide()
	end
	wipe(self.bars)

	for _, runtime in pairs(self.elements) do
		runtime.frame:Hide()
		runtime.frame:SetParent(nil)
	end
	wipe(self.elements)

	for _, plugin in pairs(self.plugins) do
		plugin.enabled = false
		plugin._elements = {}
		if plugin._eventFrame then plugin._eventFrame:SetScript("OnEvent", nil) end
	end

	self:ActivateBars()
	self:ActivatePlugins()
	if self.ScreenAdjustAll then self:ScreenAdjustAll() end
end

function WCDPanel:OnLogin()
	self.db.RegisterCallback(self, "OnProfileChanged", "ReloadProfile")
	self.db.RegisterCallback(self, "OnProfileCopied", "ReloadProfile")
	self.db.RegisterCallback(self, "OnProfileReset", "ReloadProfile")

	self:ActivateBars()
	self:ActivatePlugins()
	self:Print(L["wcdpanel loaded. Type /wcd for options."])
end

function WCDPanel:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33aaffwcdpanel|r: " .. tostring(msg))
end

-- Comandos de prueba de la fase 1: crear/borrar barras y colocar elementos a mano.
-- Las opciones completas (AceConfig) llegan en la fase 2 y sustituirán esto.
local function handleSlash(msg)
	local cmd, rest = msg:match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()

	if cmd == "bar" then
		local sub, arg = rest:match("^(%S*)%s*(.-)$")
		if sub == "add" then
			local edge = (arg ~= "" and arg or "top"):upper()
			local id = WCDPanel:CreateBar({ edge = edge })
			WCDPanel:Print("Barra " .. id .. " creada (" .. edge .. ").")
		elseif sub == "del" then
			local id = tonumber(arg)
			if id then
				WCDPanel:DeleteBar(id)
				WCDPanel:Print("Barra " .. id .. " borrada.")
			end
		elseif sub == "list" then
			for id, cfg in pairs(WCDPanel.db.profile.bars) do
				WCDPanel:Print(id .. ": " .. cfg.edge .. " stack=" .. cfg.stack ..
					(cfg.enabled and "" or " (oculta)"))
			end
		else
			WCDPanel:Print("uso: /wcd bar add [top|bottom|free] | del <id> | list")
		end
	elseif cmd == "put" then
		local elId, barId, zone, order = rest:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
		if elId then
			WCDPanel:PlaceElement(elId, tonumber(barId), zone:upper(), tonumber(order) or 1)
		else
			WCDPanel:Print("uso: /wcd put <elemento> <barra> <left|center|right> <orden>")
		end
	else
		WCDPanel:Print(L["wcdpanel loaded. Type /wcd for options."])
	end
end

SLASH_WCDPANEL1 = "/wcd"
SLASH_WCDPANEL2 = "/wcdpanel"
SlashCmdList["WCDPANEL"] = handleSlash
