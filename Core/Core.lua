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

-- Un perfil nuevo arranca con una barra arriba: los plugins colocan sus elementos en ella
-- (defaultPlacement.bar = true) y así el addon se ve funcionando desde el primer inicio.
function WCDPanel:EnsureDefaultLayout()
	if self.db.profile.initialized then return end
	self.db.profile.initialized = true
	if next(self.db.profile.bars) == nil then
		self:CreateBar({ edge = "TOP" })
	end
end

function WCDPanel:ReloadProfile()
	self:DeactivatePlugins()
	for id in pairs(self.bars) do self:DestroyBarFrame(id) end
	self:PatchProfile()
	self:EnsureDefaultLayout()
	self:ActivateBars()
	self:ActivatePlugins()
	self:ScreenAdjustAll()
end

function WCDPanel:OnLogin()
	self.db.RegisterCallback(self, "OnProfileChanged", "ReloadProfile")
	self.db.RegisterCallback(self, "OnProfileCopied", "ReloadProfile")
	self.db.RegisterCallback(self, "OnProfileReset", "ReloadProfile")

	self:EnsureDefaultLayout()
	self:ActivateBars()
	self:ActivatePlugins()
	self:InitOptions()
	self:Print(L["wcdpanel loaded. Type /wcd for options."])
end

function WCDPanel:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33aaffwcdpanel|r: " .. tostring(msg))
end

function WCDPanel:SetLocked(locked)
	self.db.profile.general.locked = locked and true or false
	self:Print(locked and "barras bloqueadas" or "barras desbloqueadas: arrastra los elementos para moverlos")
end

local function handleSlash(msg)
	local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	if cmd == "" or cmd == "config" then
		WCDPanel:OpenOptions()
	elseif cmd == "lock" then
		WCDPanel:SetLocked(not WCDPanel.db.profile.general.locked)
	elseif cmd == "bar" then
		local sub, arg = rest:match("^(%S*)%s*(.-)$")
		if sub == "add" then
			local edge = (arg ~= "" and arg or "top"):upper()
			local id = WCDPanel:CreateBar({ edge = edge })
			WCDPanel:Print("barra " .. id .. " creada (" .. edge .. ")")
		elseif sub == "del" and tonumber(arg) then
			WCDPanel:DeleteBar(tonumber(arg))
		else
			for id, cfg in pairs(WCDPanel.db.profile.bars) do
				WCDPanel:Print(id .. ": " .. cfg.name .. " (" .. cfg.edge .. ")")
			end
		end
	else
		WCDPanel:Print("/wcd abre las opciones · /wcd lock bloquea o desbloquea · /wcd bar add top|bottom|free · /wcd bar del <n>")
	end
end

SLASH_WCDPANEL1 = "/wcd"
SLASH_WCDPANEL2 = "/wcdpanel"
SlashCmdList["WCDPANEL"] = handleSlash
