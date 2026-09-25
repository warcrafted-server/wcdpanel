-- XP descansada en % del nivel ("RestXP: 0.65%"). El tooltip estima la de tus otros personajes
-- del reino: +5 % del nivel cada 8 h descansando (cada 32 h fuera de posada), tope 150 %.
local Util = WCDPanel.Util

local P = WCDPanel:NewPlugin("RestXP", {
	title = "XP descansada",
	defaults = { global = { realms = {} } },
	defaultPlacement = { bar = true, zone = "LEFT", order = 7 },
	events = { "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING", "PLAYER_LEVEL_UP",
		"PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT" },
})

local MAX_LEVEL = 80

local function realmData()
	local realm = GetRealmName()
	P.db.global.realms[realm] = P.db.global.realms[realm] or {}
	return P.db.global.realms[realm]
end

local function store()
	local _, class = UnitClass("player")
	realmData()[UnitName("player")] = {
		level = UnitLevel("player"), rested = GetXPExhaustion() or 0, maxXP = UnitXPMax("player"),
		resting = IsResting() and true or false, time = time(), class = class,
	}
end

local function estimated(data)
	if data.level >= MAX_LEVEL or not data.maxXP or data.maxXP == 0 then return nil end
	local hours = (time() - data.time) / 3600
	local rate = data.resting and 8 or 32
	local rested = data.rested + data.maxXP * 0.05 * (hours / rate)
	return math.min(rested, data.maxXP * 1.5) / data.maxXP
end

function P:OnEnable() store() end

function P:OnEvent()
	store()
	self:Refresh()
end

function P:GetText()
	if UnitLevel("player") >= MAX_LEVEL then return "RestXP:", Util.Gray("—") end
	local maxXP = UnitXPMax("player")
	local ratio = maxXP > 0 and (GetXPExhaustion() or 0) / maxXP or 0
	return "RestXP:", Util.Color(format("%.2f%%", ratio * 100), ratio >= 1.5 and "20ff20" or (ratio > 0 and "68ccef" or "9d9d9d"))
end

function P:GetIcon() return "Interface\\Icons\\Spell_Nature_Sleep" end

function P:OnTooltip(_, tooltip)
	tooltip:SetText("XP descansada")
	local me = UnitName("player")
	local list = {}
	for name, data in pairs(realmData()) do table.insert(list, { name = name, data = data }) end
	table.sort(list, function(a, b) return a.data.level > b.data.level end)
	for _, entry in ipairs(list) do
		local ratio = estimated(entry.data)
		local color = RAID_CLASS_COLORS[entry.data.class] or { r = 1, g = 1, b = 1 }
		local value = ratio and format("%.1f%%%s", ratio * 100, entry.data.resting and " (posada)" or "") or "nivel máximo"
		local label = format("%s (%d)%s", entry.name, entry.data.level, entry.name == me and " *" or "")
		tooltip:AddDoubleLine(label, value, color.r, color.g, color.b, 1, 1, 1)
	end
	tooltip:AddLine(" ")
	tooltip:AddLine(IsResting() and "Estás descansando." or "No estás en una posada ni en una ciudad.", 0.6, 0.6, 0.6)
end
