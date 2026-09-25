-- Durabilidad del equipo y reparación automática en el vendedor.
-- El coste de reparación sale del tooltip del objeto (GameTooltip:SetInventoryItem devuelve
-- hasItem, hasCooldown, repairCost), en un tooltip oculto propio.
local Util = WCDPanel.Util

local P = WCDPanel:NewPlugin("Repair", {
	title = "Durabilidad",
	defaults = { profile = { lowest = true, showCost = true, autoRepair = false, useGuild = false, report = true } },
	defaultPlacement = { bar = true, zone = "LEFT", order = 3 },
	events = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_ENTERING_WORLD", "MERCHANT_SHOW", "PLAYER_MONEY" },
})

-- Ranuras con durabilidad (sin camisa, tabardo ni munición).
local SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }

local scanTip = CreateFrame("GameTooltip", "WCDPanelRepairScanTooltip", nil, "GameTooltipTemplate")

local function equippedCost()
	local cost = 0
	for _, slot in ipairs(SLOTS) do
		scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
		local _, _, repairCost = scanTip:SetInventoryItem("player", slot)
		cost = cost + (repairCost or 0)
	end
	scanTip:Hide()
	return cost
end

local function durability()
	local current, maximum, lowest, items = 0, 0, 1, {}
	for _, slot in ipairs(SLOTS) do
		local cur, max = GetInventoryItemDurability(slot)
		if cur and max and max > 0 then
			current, maximum = current + cur, maximum + max
			local ratio = cur / max
			if ratio < lowest then lowest = ratio end
			if ratio < 1 then table.insert(items, { slot = slot, ratio = ratio }) end
		end
	end
	local average = maximum > 0 and current / maximum or 1
	table.sort(items, function(a, b) return a.ratio < b.ratio end)
	return average, lowest, items
end

local function autoRepair()
	local db = P.db.profile
	if not db.autoRepair or not CanMerchantRepair() then return end
	local cost, canRepair = GetRepairAllCost()
	if not canRepair or cost <= 0 then return end
	if db.useGuild and IsInGuild() and CanGuildBankRepair() then
		local limit = GetGuildBankWithdrawMoney()
		-- -1 = sin límite (maestro de la hermandad)
		if limit == -1 or limit >= cost then
			RepairAllItems(1)
			if db.report then P:Print("reparado con fondos de hermandad: " .. Util.Money(cost, true)) end
			return
		end
	end
	if GetMoney() >= cost then
		RepairAllItems()
		if db.report then P:Print("reparado: " .. Util.Money(cost, true)) end
	else
		P:Print("no tienes dinero para reparar (" .. Util.Money(cost, true) .. ")")
	end
end

function P:OnEvent(event)
	if event == "MERCHANT_SHOW" then autoRepair() end
	self:Refresh()
end

function P:GetText()
	local average, lowest = durability()
	local ratio = self.db.profile.lowest and lowest or average
	local value = Util.Color(format("%d%%", math.floor(ratio * 100)), Util.RatioColor(ratio))
	return "Durabilidad:", value
end

function P:GetIcon() return "Interface\\Icons\\Ability_Repair" end

function P:OnTooltip(_, tooltip)
	local average, lowest, items = durability()
	tooltip:SetText("Durabilidad")
	tooltip:AddDoubleLine("Media", format("%d%%", average * 100), 1, 0.82, 0, 1, 1, 1)
	tooltip:AddDoubleLine("Objeto más dañado", format("%d%%", lowest * 100), 1, 0.82, 0, 1, 1, 1)
	for _, item in ipairs(items) do
		local link = GetInventoryItemLink("player", item.slot)
		if link then tooltip:AddDoubleLine(link, Util.Color(format("%d%%", item.ratio * 100), Util.RatioColor(item.ratio))) end
	end
	if self.db.profile.showCost then
		local cost = equippedCost()
		tooltip:AddDoubleLine("Coste de reparación", cost > 0 and Util.Money(cost, true) or "—", 1, 0.82, 0, 1, 1, 1)
	end
	tooltip:AddLine(" ")
	tooltip:AddLine("Reparación automática: " .. (self.db.profile.autoRepair and "sí" or "no"), 0.6, 0.6, 0.6)
end

function P:OnClick(_, button)
	if button == "LeftButton" then ToggleCharacter("PaperDollFrame") end
end

function P:BuildMenu(_, menu)
	local db = self.db.profile
	table.insert(menu, { text = "Reparación automática", checked = db.autoRepair, func = function() db.autoRepair = not db.autoRepair end })
	table.insert(menu, { text = "Usar fondos de hermandad", checked = db.useGuild, func = function() db.useGuild = not db.useGuild end })
end

function P:GetOptions()
	local db = self.db.profile
	local function toggle(order, key, name)
		return {
			type = "toggle", order = order, name = name, width = "full",
			get = function() return db[key] end,
			set = function(_, v) db[key] = v P:Refresh() end,
		}
	end
	return {
		lowest = toggle(1, "lowest", "Mostrar el objeto más dañado (si no, la media)"),
		showCost = toggle(2, "showCost", "Coste de reparación en el tooltip"),
		autoRepair = toggle(3, "autoRepair", "Reparar automáticamente al hablar con un vendedor"),
		useGuild = toggle(4, "useGuild", "Usar primero los fondos de la hermandad"),
		report = toggle(5, "report", "Avisar en el chat de lo que cuesta"),
	}
end
