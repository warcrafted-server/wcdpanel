-- Oro del personaje con iconos de moneda. El tooltip suma el oro de todos tus personajes del
-- reino (guardado por cuenta, en global) y lo ganado en esta sesión.
local Util = WCDPanel.Util

local P = WCDPanel:NewPlugin("Gold", {
	title = "Oro",
	defaults = { profile = { sameFaction = false }, global = { realms = {} } },
	defaultPlacement = { bar = true, zone = "LEFT", order = 5, showLabel = false },
	events = { "PLAYER_MONEY", "PLAYER_ENTERING_WORLD" },
})

local startMoney

local function realmData()
	local realm = GetRealmName()
	P.db.global.realms[realm] = P.db.global.realms[realm] or {}
	return P.db.global.realms[realm]
end

local function store()
	local name = UnitName("player")
	local _, class = UnitClass("player")
	realmData()[name] = { money = GetMoney(), faction = UnitFactionGroup("player"), class = class }
end

function P:OnEnable()
	startMoney = startMoney or GetMoney()
	store()
end

function P:OnEvent()
	store()
	self:Refresh()
end

function P:GetText()
	return "Oro:", Util.White(Util.Money(GetMoney(), true))
end

function P:OnTooltip(_, tooltip)
	local chars, total = {}, 0
	local faction = UnitFactionGroup("player")
	for name, data in pairs(realmData()) do
		if not self.db.profile.sameFaction or data.faction == faction then
			table.insert(chars, { name = name, data = data })
			total = total + data.money
		end
	end
	table.sort(chars, function(a, b) return a.data.money > b.data.money end)

	tooltip:SetText("Oro en " .. GetRealmName())
	for _, c in ipairs(chars) do
		local color = RAID_CLASS_COLORS[c.data.class] or { r = 1, g = 1, b = 1 }
		tooltip:AddDoubleLine(c.name, Util.Money(c.data.money, true), color.r, color.g, color.b, 1, 1, 1)
	end
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine("Total", Util.Money(total, true), 1, 0.82, 0, 1, 1, 1)
	local session = GetMoney() - (startMoney or GetMoney())
	local sessionText = (session < 0 and Util.Red("-") or Util.Green("+")) .. Util.Money(math.abs(session), true)
	tooltip:AddDoubleLine("Esta sesión", sessionText, 1, 0.82, 0, 1, 1, 1)
end

function P:BuildMenu(_, menu)
	local forget = {}
	local me = UnitName("player")
	for name in pairs(realmData()) do
		if name ~= me then
			table.insert(forget, { text = name, notCheckable = true, func = function()
				realmData()[name] = nil
				P:Print(name .. " quitado de la lista")
			end })
		end
	end
	if #forget > 0 then
		table.sort(forget, function(a, b) return a.text < b.text end)
		table.insert(menu, { text = "Olvidar personaje", notCheckable = true, hasArrow = true, menuList = forget })
	end
end

function P:GetOptions()
	local db = self.db.profile
	return {
		sameFaction = {
			type = "toggle", order = 1, name = "Solo personajes de mi facción", width = "full",
			get = function() return db.sameFaction end,
			set = function(_, v) db.sameFaction = v end,
		},
	}
end
