-- Estimación de cuánto falta para el siguiente nivel, a partir del ritmo de XP reciente (XP/hora
-- en los últimos minutos), al estilo del "tiempo restante" que traía TitanXP.
local Util = WCDPanel.Util
local MAX_LEVEL = 80
local MIN_SPAN = 60 -- menos de un minuto de datos: el ritmo es demasiado ruidoso para fiarse.

local P = WCDPanel:NewPlugin("TTL", {
	title = "Tiempo para subir de nivel",
	description = "Estima cuánto falta para el siguiente nivel según tu ritmo de XP de los últimos minutos.",
	defaultPlacement = { bar = true, zone = "LEFT", order = 7.5 },
	defaults = { profile = { windowMinutes = 15 } },
	events = { "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" },
})

local samples = {} -- { {t = GetTime(), gain = xp ganada} , ... }, más antiguas primero
local lastXP

local function windowSeconds() return (P.db.profile.windowMinutes or 15) * 60 end

local function prune(now)
	local window = windowSeconds()
	while samples[1] and now - samples[1].t > window do table.remove(samples, 1) end
end

local function record()
	local xp, now = UnitXP("player"), GetTime()
	if lastXP and xp > lastXP then
		table.insert(samples, { t = now, gain = xp - lastXP })
	end
	lastXP = xp
	prune(now)
end

-- XP por segundo, o nil si aún no hay suficientes datos.
local function rate()
	if #samples == 0 then return nil end
	local span = GetTime() - samples[1].t
	if span < MIN_SPAN then return nil end
	local total = 0
	for _, s in ipairs(samples) do total = total + s.gain end
	return total / span
end

local function formatDuration(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h, m = math.floor(seconds / 3600), math.floor((seconds % 3600) / 60)
	if h > 0 then return format("%dh %dm", h, m) end
	if m > 0 then return format("%dm", m) end
	return "<1m"
end

function P:OnEnable()
	samples, lastXP = {}, UnitXP("player")
end

function P:OnEvent(event)
	if event == "PLAYER_LEVEL_UP" then
		samples, lastXP = {}, 0 -- la XP del cliente ya vuelve a 0; el próximo PLAYER_XP_UPDATE reengancha
	else
		record()
	end
	self:Refresh()
end

function P:GetText()
	if UnitLevel("player") >= MAX_LEVEL then return "Nivel:", Util.Gray("máximo") end
	if IsXPUserDisabled and IsXPUserDisabled() then return "Nivel:", Util.Gray("XP desactivada") end
	local r = rate()
	if not r or r <= 0 then return "Nivel:", Util.Gray("calculando…") end
	local remaining = UnitXPMax("player") - UnitXP("player")
	return "Nivel:", Util.White("~" .. formatDuration(remaining / r))
end

function P:GetIcon() return "Interface\\Icons\\INV_Misc_PocketWatch_02" end

function P:OnTooltip(_, tooltip)
	tooltip:SetText("Tiempo para subir de nivel")
	if UnitLevel("player") >= MAX_LEVEL then
		tooltip:AddLine("Ya tienes el nivel máximo.", 1, 1, 1)
		return
	end
	local remaining = UnitXPMax("player") - UnitXP("player")
	tooltip:AddDoubleLine("XP para el siguiente nivel", remaining, 1, 1, 1, 1, 1, 1)
	local r = rate()
	if r then
		tooltip:AddDoubleLine("Ritmo", format("%d XP/h", math.floor(r * 3600)), 1, 1, 1, 1, 1, 1)
		tooltip:AddLine(format("Calculado sobre los últimos %d min.", P.db.profile.windowMinutes), 0.6, 0.6, 0.6)
	else
		tooltip:AddLine("Todavía no hay suficiente XP reciente para calcularlo.", 0.6, 0.6, 0.6)
	end
end

function P:GetOptions()
	return {
		windowMinutes = {
			type = "range", order = 1, name = "Ventana de cálculo (minutos)", min = 5, max = 60, step = 5,
			desc = "Cuánto XP reciente se promedia para el ritmo. Menos: reacciona antes a un cambio de ritmo. " ..
				"Más: una sola misión grande pesa menos en la estimación.",
			get = function() return P.db.profile.windowMinutes end,
			set = function(_, v) P.db.profile.windowMinutes = v end,
		},
	}
end
