-- Modo de botín del grupo ("Saqueo: Solo") y dificultad de instancia. El líder puede
-- cambiarlos desde el menú (clic derecho).
local Util = WCDPanel.Util

local P = WCDPanel:NewPlugin("LootType", {
	title = "Saqueo",
	defaultPlacement = { bar = true, zone = "LEFT", order = 6 },
	events = { "PARTY_LOOT_METHOD_CHANGED", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE",
		"PARTY_LEADER_CHANGED", "PLAYER_ENTERING_WORLD", "UPDATE_INSTANCE_INFO" },
})

-- Las cadenas del cliente llevan prefijo ("Botín: libre"): se quita y se capitaliza.
local function short(text)
	text = (text or ""):gsub("^[^:]+:%s*", "")
	return text:sub(1, 1):upper() .. text:sub(2)
end

local METHODS = {
	{ key = "freeforall", name = function() return short(LOOT_FREE_FOR_ALL) end },
	{ key = "roundrobin", name = function() return short(LOOT_ROUND_ROBIN) end },
	{ key = "master", name = function() return short(LOOT_MASTER_LOOTER) end },
	{ key = "group", name = function() return short(LOOT_GROUP_LOOT) end },
	{ key = "needbeforegreed", name = function() return short(LOOT_NEED_BEFORE_GREED) end },
}

local function methodName(key)
	for _, m in ipairs(METHODS) do
		if m.key == key then return m.name() end
	end
	return key or "?"
end

local function inGroup() return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 end

local function qualityText(q)
	local color = ITEM_QUALITY_COLORS[q]
	local name = _G["ITEM_QUALITY" .. q .. "_DESC"] or tostring(q)
	return color and (color.hex .. name .. "|r") or name
end

function P:OnEvent() self:Refresh() end

function P:GetText()
	if not inGroup() then return "Saqueo:", Util.White(SOLO) end
	return "Saqueo:", Util.White(methodName(GetLootMethod()))
end

function P:GetIcon() return "Interface\\Icons\\INV_Misc_Coin_02" end

function P:OnTooltip(_, tooltip)
	tooltip:SetText("Saqueo")
	if inGroup() then
		local method, partyMaster, raidMaster = GetLootMethod()
		tooltip:AddDoubleLine("Modo", methodName(method), 1, 0.82, 0, 1, 1, 1)
		tooltip:AddDoubleLine("Umbral", qualityText(GetLootThreshold()), 1, 0.82, 0, 1, 1, 1)
		if method == "master" then
			local unit = raidMaster and ("raid" .. raidMaster) or (partyMaster == 0 and "player" or (partyMaster and "party" .. partyMaster))
			if unit then tooltip:AddDoubleLine("Maestro despojador", UnitName(unit) or "?", 1, 0.82, 0, 1, 1, 1) end
		end
	else
		tooltip:AddLine(SOLO, 1, 1, 1)
	end
	tooltip:AddDoubleLine("Mazmorra", _G["DUNGEON_DIFFICULTY" .. (GetDungeonDifficulty() or 1)] or "?", 1, 0.82, 0, 1, 1, 1)
	tooltip:AddDoubleLine("Banda", _G["RAID_DIFFICULTY" .. (GetRaidDifficulty() or 1)] or "?", 1, 0.82, 0, 1, 1, 1)
	tooltip:AddLine(" ")
	tooltip:AddLine("Clic derecho: cambiar (si eres el líder).", 0.6, 0.6, 0.6)
end

function P:BuildMenu(_, menu)
	local leader = not inGroup() or IsPartyLeader() or IsRaidLeader()
	local methods, thresholds, dungeon, raid = {}, {}, {}, {}
	local current = GetLootMethod()
	for _, m in ipairs(METHODS) do
		table.insert(methods, {
			text = m.name(), checked = inGroup() and current == m.key, disabled = not (inGroup() and leader),
			func = function() SetLootMethod(m.key, m.key == "master" and UnitName("player") or nil) end,
		})
	end
	for q = 2, 4 do
		table.insert(thresholds, {
			text = qualityText(q), checked = inGroup() and GetLootThreshold() == q, disabled = not (inGroup() and leader),
			func = function() SetLootThreshold(q) end,
		})
	end
	for d = 1, 2 do
		table.insert(dungeon, {
			text = _G["DUNGEON_DIFFICULTY" .. d], checked = GetDungeonDifficulty() == d, disabled = not leader,
			func = function() SetDungeonDifficulty(d) end,
		})
	end
	for d = 1, 4 do
		table.insert(raid, {
			text = _G["RAID_DIFFICULTY" .. d], checked = GetRaidDifficulty() == d, disabled = not leader,
			func = function() SetRaidDifficulty(d) end,
		})
	end
	table.insert(menu, { text = "Modo de botín", notCheckable = true, hasArrow = true, menuList = methods })
	table.insert(menu, { text = "Umbral", notCheckable = true, hasArrow = true, menuList = thresholds })
	table.insert(menu, { text = "Dificultad de mazmorra", notCheckable = true, hasArrow = true, menuList = dungeon })
	table.insert(menu, { text = "Dificultad de banda", notCheckable = true, hasArrow = true, menuList = raid })
end
