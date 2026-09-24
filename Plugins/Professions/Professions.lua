-- Un botón por profesión aprendida, con su nivel, que abre la ventana correspondiente.
-- Detecta por ID de hechizo, no por nombre: en esES el nombre de la habilidad no coincide
-- con el del hechizo en las de recolección ("Herboristería" vs "Recolectar hierbas",
-- "Desollar" vs "Desuello"). Abrir una profesión es lanzar un hechizo, así que el botón tiene
-- que ser seguro (plugin.opts.secure) y sus atributos solo se tocan fuera de combate.
--
-- IDs verificados en SkillLine.dbc/Spell.dbc (base y esES) del propio servidor.
local PROFESSIONS = {
	[171] = { names = { enUS = "Alchemy", esES = "Alquimia" }, ranks = { 2259, 3101, 3464, 11611, 28596, 51304 } },
	[164] = { names = { enUS = "Blacksmithing", esES = "Herrería" }, ranks = { 2018, 3100, 3538, 9785, 29844, 51300 } },
	[333] = { names = { enUS = "Enchanting", esES = "Encantamiento" }, ranks = { 7411, 7412, 7413, 13920, 28029, 51313 } },
	[202] = { names = { enUS = "Engineering", esES = "Ingeniería" }, ranks = { 4036, 4037, 4038, 12656, 30350, 51306 } },
	[773] = { names = { enUS = "Inscription", esES = "Inscripción" }, ranks = { 45357, 45358, 45359, 45360, 45361, 45363 } },
	[755] = { names = { enUS = "Jewelcrafting", esES = "Joyería" }, ranks = { 25229, 25230, 28894, 28895, 28897, 51311 } },
	[165] = { names = { enUS = "Leatherworking", esES = "Peletería" }, ranks = { 2108, 3104, 3811, 10662, 32549, 51302 } },
	[197] = { names = { enUS = "Tailoring", esES = "Sastrería" }, ranks = { 3908, 3909, 3910, 12180, 26790, 51309 } },
	[185] = { names = { enUS = "Cooking", esES = "Cocina" }, ranks = { 2550, 3102, 3413, 18260, 33359, 51296 }, shiftSpell = 818 },
	[129] = { names = { enUS = "First Aid", esES = "Primeros auxilios" }, ranks = { 3273, 3274, 7924, 10846, 27028, 45542 } },
	[186] = { names = { enUS = "Mining", esES = "Minería" }, ranks = { 2575, 2576, 3564, 10248, 29354, 50310 }, clickSpell = 2656, shiftSpell = 2580 },
	[182] = { names = { enUS = "Herb Gathering", esES = "Recolectar hierbas" }, ranks = { 2366, 2368, 3570, 11993, 28695, 50300 }, clickSpell = 2383 },
	[393] = { names = { enUS = "Skinning", esES = "Desuello" }, ranks = { 8613, 8617, 8618, 10768, 32678, 50305 }, noClick = true },
	[356] = { names = { enUS = "Fishing", esES = "Pesca" }, ranks = { 7620, 7731, 7732, 18248, 33095, 51294 } },
	[0] = { single = 53428 }, -- Forja de runas (DK): sin línea de habilidad, sin nivel
}

local P = WCDPanel:NewPlugin("Professions", {
	title = "Profesiones",
	category = "Personaje",
	dynamicElements = true,
	secure = true,
	events = { "PLAYER_LOGIN", "SKILL_LINES_CHANGED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB" },
})

local state = {}

local function scanKnownSpells()
	local known = {}
	for tab = 1, GetNumSpellTabs() do
		local _, _, offset, numSpells = GetSpellTabInfo(tab)
		for i = offset + 1, offset + numSpells do
			local link = GetSpellLink(i, BOOKTYPE_SPELL)
			local id = link and tonumber(link:match("spell:(%d+)"))
			if id then known[id] = true end
		end
	end
	return known
end

local function highestKnownRank(known, ranks)
	for i = #ranks, 1, -1 do
		if known[ranks[i]] then return ranks[i] end
	end
end

local function findSkillLine(name)
	for skillLineId, def in pairs(PROFESSIONS) do
		if def.names and (def.names.enUS == name or def.names.esES == name) then
			return skillLineId
		end
	end
end

-- Recorre la lista de habilidades desplegando las cabeceras plegadas (si no, sus hijos no
-- aparecen) y las vuelve a plegar tal como estaban. No toca nada si el jugador tiene la
-- ventana de habilidades abierta, para no interferirle mientras la mira.
local function scanSkillLevels()
	if SkillFrame and SkillFrame:IsVisible() then return nil end

	local expandedNames = {}
	local i = 1
	while i <= GetNumSkillLines() do
		local name, isHeader, isExpanded = GetSkillLineInfo(i)
		if isHeader and not isExpanded then
			ExpandSkillHeader(i)
			table.insert(expandedNames, name)
		end
		i = i + 1
	end

	local levels = {}
	for j = 1, GetNumSkillLines() do
		local name, isHeader, _, rank, _, modifier, maxRank = GetSkillLineInfo(j)
		if not isHeader then
			local skillLineId = findSkillLine(name)
			if skillLineId then
				levels[skillLineId] = { rank = rank, maxRank = maxRank, modifier = modifier or 0 }
			end
		end
	end

	for j = GetNumSkillLines(), 1, -1 do
		local name, isHeader = GetSkillLineInfo(j)
		if isHeader then
			for _, expName in ipairs(expandedNames) do
				if expName == name then
					CollapseSkillHeader(j)
					break
				end
			end
		end
	end

	return levels
end

function P:ApplyAttributes(id, skillLineId, def)
	local runtime = WCDPanel.elements[id]
	local info = state[skillLineId]
	if not runtime or not info then return end
	local spellName = GetSpellInfo(info.spellId)
	if not spellName then return end

	WCDPanel:RunOutOfCombat("profattr:" .. id, function()
		local frame = runtime.frame
		if def.noClick then
			frame:SetAttribute("type", nil)
			frame:SetAttribute("spell", nil)
		elseif def.clickSpell then
			frame:SetAttribute("type", "spell")
			frame:SetAttribute("spell", GetSpellInfo(def.clickSpell))
		else
			frame:SetAttribute("type", "spell")
			frame:SetAttribute("spell", spellName)
		end
		if def.shiftSpell then
			frame:SetAttribute("type-shift", "spell")
			frame:SetAttribute("spell-shift", GetSpellInfo(def.shiftSpell))
		end
	end)
end

function P:Rescan()
	local known = scanKnownSpells()
	local levels = scanSkillLevels()

	for skillLineId, def in pairs(PROFESSIONS) do
		local spellId = def.single and (known[def.single] and def.single or nil)
			or highestKnownRank(known, def.ranks or {})
		if spellId then
			state[skillLineId] = state[skillLineId] or {}
			state[skillLineId].spellId = spellId
			if levels and levels[skillLineId] then
				state[skillLineId].rank = levels[skillLineId].rank
				state[skillLineId].maxRank = levels[skillLineId].maxRank
				state[skillLineId].modifier = levels[skillLineId].modifier
			end
			local id = self:AddElement(skillLineId, { defaultPlacement = { bar = false, zone = "LEFT", order = 40 } })
			self:ApplyAttributes(id, skillLineId, def)
			self:Refresh(id)
		end
	end
end

function P:OnEnable() self:Rescan() end
function P:OnEvent() self:Rescan() end

function P:GetText(el)
	local skillLineId = WCDPanel.elements[el].subId
	local def, info = PROFESSIONS[skillLineId], state[skillLineId]
	if not info then return "", "" end
	local label = GetSpellInfo(info.spellId) or "?"
	local value = ""
	if not def.single and info.rank and info.maxRank then
		value = info.rank .. "/" .. info.maxRank
		if info.modifier and info.modifier > 0 then
			value = value .. " (+" .. info.modifier .. ")"
		end
	end
	return label, value
end

function P:GetIcon(el)
	local info = state[WCDPanel.elements[el].subId]
	return info and GetSpellTexture(info.spellId)
end

function P:OnTooltip(el, tooltip)
	local skillLineId = WCDPanel.elements[el].subId
	local def, info = PROFESSIONS[skillLineId], state[skillLineId]
	if not info then return end
	tooltip:SetText(GetSpellInfo(info.spellId) or "Profesión")
	if not def.single and info.rank and info.maxRank then
		tooltip:AddLine(info.rank .. " / " .. info.maxRank)
		if info.maxRank < 450 and info.rank >= info.maxRank - 25 then
			tooltip:AddLine("Busca un instructor para seguir progresando")
		end
	end
	if def.shiftSpell then
		tooltip:AddLine("Mayús+clic: " .. (GetSpellInfo(def.shiftSpell) or ""))
	end
end
