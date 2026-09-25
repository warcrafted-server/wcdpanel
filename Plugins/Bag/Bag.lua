-- Huecos de las bolsas: "Bolsas: 86/114". Clic: abre todas las bolsas.
local Util = WCDPanel.Util

local P = WCDPanel:NewPlugin("Bag", {
	title = "Bolsas",
	defaults = { profile = { showFree = false, countSpecial = false } },
	defaultPlacement = { bar = true, zone = "LEFT", order = 2 },
	events = { "BAG_UPDATE", "PLAYER_ENTERING_WORLD" },
})

local function scan(countSpecial)
	local free, total = 0, 0
	local special = {}
	for bag = 0, NUM_BAG_SLOTS or 4 do
		local slots = GetContainerNumSlots(bag)
		if slots and slots > 0 then
			local bagFree, bagType = GetContainerNumFreeSlots(bag)
			if bagType == 0 or bagType == nil or countSpecial then
				free, total = free + bagFree, total + slots
			else
				table.insert(special, { name = GetBagName(bag) or "?", free = bagFree, total = slots })
			end
		end
	end
	return free, total, special
end

function P:OnEvent() self:Refresh() end

function P:GetText()
	local free, total = scan(self.db.profile.countSpecial)
	local used = total - free
	local color = Util.RatioColor(total > 0 and free / total * 2 or 1)
	local shown = self.db.profile.showFree and free or used
	return "Bolsas:", Util.Color(shown, color) .. Util.Gray("/" .. total)
end

function P:GetIcon() return "Interface\\Icons\\INV_Misc_Bag_08" end

function P:OnTooltip(_, tooltip)
	local free, total, special = scan(self.db.profile.countSpecial)
	tooltip:SetText("Bolsas")
	tooltip:AddDoubleLine("Libres", free .. " / " .. total, 1, 0.82, 0, 1, 1, 1)
	for _, bag in ipairs(special) do
		tooltip:AddDoubleLine(bag.name, bag.free .. " / " .. bag.total, 0.7, 0.7, 0.7, 1, 1, 1)
	end
	tooltip:AddLine(" ")
	tooltip:AddLine("Clic: abrir las bolsas.", 0.6, 0.6, 0.6)
end

function P:OnClick(_, button)
	if button == "LeftButton" then OpenAllBags() end
end

function P:GetOptions()
	local db = self.db.profile
	return {
		showFree = {
			type = "toggle", order = 1, name = "Mostrar huecos libres (en vez de ocupados)", width = "full",
			get = function() return db.showFree end,
			set = function(_, v) db.showFree = v P:Refresh() end,
		},
		countSpecial = {
			type = "toggle", order = 2, name = "Contar bolsas de profesión y munición", width = "full",
			get = function() return db.countSpecial end,
			set = function(_, v) db.countSpecial = v P:Refresh() end,
		},
	}
end
