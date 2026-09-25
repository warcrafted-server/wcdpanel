-- Reloj: hora local y/o del servidor. Clic: cronómetro/alarma de Blizzard; Mayús+clic: calendario.
local Util = WCDPanel.Util

local P = WCDPanel:NewPlugin("Clock", {
	title = "Reloj",
	defaults = { profile = { mode = "local", format24 = true, hideGameTime = false } },
	defaultPlacement = { bar = true, zone = "RIGHT", order = 1 },
	interval = 1,
})

local MODES = { ["local"] = "Hora local", server = "Hora del servidor", both = "Ambas" }

local function formatTime(hour, minute)
	if P.db.profile.format24 then return format("%02d:%02d", hour, minute) end
	local suffix = hour < 12 and "a.m." or "p.m."
	hour = hour % 12
	if hour == 0 then hour = 12 end
	return format("%d:%02d %s", hour, minute, suffix)
end

local function localTime() return formatTime(tonumber(date("%H")), tonumber(date("%M"))) end
local function serverTime() return formatTime(GetGameTime()) end

local function applyGameTime()
	if GameTimeFrame then Util.SetFrameHidden(GameTimeFrame, P.enabled and P.db.profile.hideGameTime) end
end

function P:OnEnable() applyGameTime() end
function P:OnDisable() if GameTimeFrame then Util.RestoreFrame(GameTimeFrame) end end
function P:OnTick() self:Refresh() end

function P:GetText()
	local mode = self.db.profile.mode
	if mode == "server" then return "", Util.White(serverTime()) end
	if mode == "both" then return "", Util.White(localTime()) .. Util.Gray(" (" .. serverTime() .. ")") end
	return "", Util.White(localTime())
end

function P:OnTooltip(_, tooltip)
	tooltip:SetText("Reloj")
	tooltip:AddDoubleLine("Hora local", localTime(), 1, 0.82, 0, 1, 1, 1)
	tooltip:AddDoubleLine("Hora del servidor", serverTime(), 1, 0.82, 0, 1, 1, 1)
	tooltip:AddDoubleLine("Fecha", date("%d/%m/%Y"), 1, 0.82, 0, 1, 1, 1)
	tooltip:AddLine(" ")
	tooltip:AddLine("Clic: cronómetro y alarma. Mayús+clic: calendario.", 0.6, 0.6, 0.6)
end

function P:OnClick(_, button)
	if button ~= "LeftButton" then return end
	if IsShiftKeyDown() then
		ToggleCalendar()
	else
		TimeManager_LoadUI()
		if TimeManager_Toggle then TimeManager_Toggle() end
	end
end

function P:GetOptions()
	local db = self.db.profile
	return {
		mode = {
			type = "select", order = 1, name = "Mostrar", values = MODES,
			get = function() return db.mode end,
			set = function(_, v) db.mode = v P:Refresh() end,
		},
		format24 = {
			type = "toggle", order = 2, name = "Formato 24 horas",
			get = function() return db.format24 end,
			set = function(_, v) db.format24 = v P:Refresh() end,
		},
		hideGameTime = {
			type = "toggle", order = 3, name = "Ocultar el botón del calendario del minimapa", width = "full",
			get = function() return db.hideGameTime end,
			set = function(_, v) db.hideGameTime = v applyGameTime() end,
		},
	}
end
