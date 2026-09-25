-- Correo: icono que se enciende con correo nuevo, remitentes en el tooltip, avisos de subasta
-- del chat. Opción de ocultar el icono de correo del minimapa.
local Util = WCDPanel.Util

local P = WCDPanel:NewPlugin("Mail", {
	title = "Correo",
	defaults = { profile = { hideMinimap = true, sound = true, chat = true } },
	defaultPlacement = { bar = true, zone = "RIGHT", order = 3 },
	events = { "UPDATE_PENDING_MAIL", "MAIL_INBOX_UPDATE", "MAIL_CLOSED", "PLAYER_ENTERING_WORLD", "CHAT_MSG_SYSTEM" },
})

local ICON = "Interface\\Icons\\INV_Letter_15"
local hadMail = false
local auctions = {}

-- Convierte "Ha aparecido un comprador para tu subasta de %s." en un patrón de Lua.
local function pattern(globalString)
	if not globalString then return nil end
	local escaped = globalString:gsub("([%.%-%+%*%?%[%]%^%$%(%)])", "%%%1")
	return "^" .. escaped:gsub("%%s", "(.+)") .. "$"
end

local AUCTION_EVENTS = {
	{ pattern = pattern(ERR_AUCTION_SOLD_S), text = "Vendido" },
	{ pattern = pattern(ERR_AUCTION_WON_S), text = "Ganado" },
	{ pattern = pattern(ERR_AUCTION_OUTBID_S), text = "Superada tu puja" },
	{ pattern = pattern(ERR_AUCTION_EXPIRED_S), text = "Caducado" },
}

local function applyMinimap()
	if MiniMapMailFrame then Util.SetFrameHidden(MiniMapMailFrame, P.enabled and P.db.profile.hideMinimap) end
end

function P:OnEnable() applyMinimap() end
function P:OnDisable() if MiniMapMailFrame then Util.RestoreFrame(MiniMapMailFrame) end end

function P:OnEvent(event, message)
	if event == "CHAT_MSG_SYSTEM" then
		for _, a in ipairs(AUCTION_EVENTS) do
			local item = a.pattern and message and message:match(a.pattern)
			if item then
				table.insert(auctions, 1, date("%H:%M") .. " " .. a.text .. ": " .. item)
				while #auctions > 6 do table.remove(auctions) end
			end
		end
		return
	end
	local has = HasNewMail() and true or false
	if has and not hadMail then
		if self.db.profile.sound then PlaySound("TellMessage") end
		if self.db.profile.chat then self:Print("tienes correo nuevo") end
	end
	hadMail = has
	self:Refresh()
end

function P:GetText()
	if not HasNewMail() then return "", "" end
	local n = GetInboxNumItems()
	return "", n > 0 and tostring(n) or ""
end

function P:GetIcon()
	if HasNewMail() then return ICON end
	return ICON, nil, 0.35, 0.35, 0.35
end

function P:OnTooltip(_, tooltip)
	if HasNewMail() then
		tooltip:SetText("Correo nuevo")
		local s1, s2, s3 = GetLatestThreeSenders()
		for _, sender in ipairs({ s1, s2, s3 }) do tooltip:AddLine(sender, 1, 1, 1) end
	else
		tooltip:SetText("Sin correo nuevo")
	end
	if #auctions > 0 then
		tooltip:AddLine(" ")
		tooltip:AddLine("Subastas", 1, 0.82, 0)
		for _, line in ipairs(auctions) do tooltip:AddLine(line, 1, 1, 1) end
	end
end

function P:GetOptions()
	local db = self.db.profile
	local function toggle(order, key, name, after)
		return {
			type = "toggle", order = order, name = name, width = "full",
			get = function() return db[key] end,
			set = function(_, v) db[key] = v if after then after() end end,
		}
	end
	return {
		hideMinimap = toggle(1, "hideMinimap", "Ocultar el icono de correo del minimapa", applyMinimap),
		sound = toggle(2, "sound", "Sonido al llegar correo"),
		chat = toggle(3, "chat", "Aviso en el chat al llegar correo"),
	}
end
