-- Un botón por profesión aprendida, con su nivel, que abre la ventana correspondiente.
--
-- Se detecta por ID de hechizo, no por nombre: en esES el nombre de la habilidad no coincide
-- con el del hechizo en las de recolección ("Herboristería" / "Recolectar hierbas").
-- Abrir una profesión es lanzar un hechizo: el botón es seguro (SecureActionButtonTemplate) y
-- usa los atributos type1/spell1 (clic izquierdo) y shift-type1/shift-spell1; el clic derecho
-- queda libre para el menú. spell lleva el ID: SecureActionButton_OnClick usa CastSpellByID.
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
	[182] = { names = { enUS = "Herbalism", esES = "Herboristería" }, ranks = { 2366, 2368, 3570, 11993, 28695, 50300 }, clickSpell = 2383 },
	[393] = { names = { enUS = "Skinning", esES = "Desollar" }, ranks = { 8613, 8617, 8618, 10768, 32678, 50305 }, noClick = true },
	[356] = { names = { enUS = "Fishing", esES = "Pesca" }, ranks = { 7620, 7731, 7732, 18248, 33095, 51294 } },
	[0] = { single = 53428 }, -- Forja de runas (DK): sin línea de habilidad, sin nivel
}
local DISPLAY_ORDER = { 171, 164, 333, 202, 773, 755, 165, 197, 186, 182, 393, 185, 129, 356, 0 }

local P = WCDPanel:NewPlugin("Professions", {
	title = "Profesiones",
	description = "Un botón por profesión con su nivel. Clic: abre la profesión (Minería: fundir; " ..
		"Herboristería: buscar hierbas). Mayús+clic: Minería busca minerales, Cocina enciende una hoguera.",
	dynamicElements = true,
	secure = true,
	events = { "SKILL_LINES_CHANGED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB" },
})

local state = {}

-- Nombre de la profesión (el de la habilidad, no el del hechizo: "Herboristería", no
-- "Recolectar hierbas"); si el idioma no está en la tabla, el del hechizo.
local function displayName(skillLineId)
	local def, info = PROFESSIONS[skillLineId], state[skillLineId]
	local name = def.names and (def.names[GetLocale()] or (GetLocale() == "esMX" and def.names.esES))
	return name or (info and GetSpellInfo(info.spellId)) or "?"
end

local function knownSpells()
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

local function highestKnown(known, ranks)
	for i = #ranks, 1, -1 do
		if known[ranks[i]] then return ranks[i] end
	end
end

local function skillLineOf(name)
	for skillLineId, def in pairs(PROFESSIONS) do
		if def.names and (def.names.enUS == name or def.names.esES == name) then return skillLineId end
	end
end

-- Recorre las habilidades desplegando las cabeceras plegadas (si no, sus hijos no aparecen) y
-- las vuelve a plegar. No toca nada con la ventana de habilidades abierta.
local function skillLevels()
	if SkillFrame and SkillFrame:IsVisible() then return nil end
	local expanded = {}
	local i = 1
	while i <= GetNumSkillLines() do
		local name, isHeader, isExpanded = GetSkillLineInfo(i)
		if isHeader and not isExpanded then
			ExpandSkillHeader(i)
			expanded[name] = true
		end
		i = i + 1
	end
	local levels = {}
	for j = 1, GetNumSkillLines() do
		local name, isHeader, _, rank, _, modifier, maxRank = GetSkillLineInfo(j)
		local skillLineId = not isHeader and skillLineOf(name)
		if skillLineId then levels[skillLineId] = { rank = rank, maxRank = maxRank, modifier = modifier or 0 } end
	end
	for j = GetNumSkillLines(), 1, -1 do
		local name, isHeader = GetSkillLineInfo(j)
		if isHeader and expanded[name] then CollapseSkillHeader(j) end
	end
	return levels
end

function P:ApplyAttributes(el, skillLineId)
	local def, info = PROFESSIONS[skillLineId], state[skillLineId]
	WCDPanel:RunOutOfCombat("profattr:" .. el, function()
		local runtime = WCDPanel.elements[el]
		if not runtime then return end
		local frame = runtime.frame
		if def.noClick then
			frame:SetAttribute("type1", nil)
			frame:SetAttribute("spell1", nil)
		else
			frame:SetAttribute("type1", "spell")
			frame:SetAttribute("spell1", def.clickSpell or info.spellId)
		end
		if def.shiftSpell then
			frame:SetAttribute("shift-type1", "spell")
			frame:SetAttribute("shift-spell1", def.shiftSpell)
		end
	end)
end

function P:Rescan()
	self.suppressUntil = GetTime() + 1
	local known = knownSpells()
	local levels = skillLevels()
	for position, skillLineId in ipairs(DISPLAY_ORDER) do
		local def = PROFESSIONS[skillLineId]
		local spellId = def.single and (known[def.single] and def.single) or (def.ranks and highestKnown(known, def.ranks))
		if spellId then
			local info = state[skillLineId] or {}
			state[skillLineId] = info
			info.spellId = spellId
			if levels and levels[skillLineId] then
				info.rank, info.maxRank, info.modifier = levels[skillLineId].rank, levels[skillLineId].maxRank, levels[skillLineId].modifier
			end
			local el = self:AddElement(skillLineId, {
				title = displayName(skillLineId),
				defaultPlacement = { bar = true, zone = "LEFT", order = 20 + position },
			})
			self:ApplyAttributes(el, skillLineId)
			self:Refresh(el)
		elseif self._elements[self:ElementId(skillLineId)] then
			self:RemoveElement(skillLineId) -- profesión olvidada
			state[skillLineId] = nil
		end
	end
end

function P:OnEnable() self:Rescan() end

-- Expandir/plegar cabeceras dispara SKILL_LINES_CHANGED: se ignora el eco de nuestro propio
-- escaneo y se agrupan las ráfagas en un solo reescaneo.
function P:OnEvent(event)
	if event == "SKILL_LINES_CHANGED" and self.suppressUntil and GetTime() < self.suppressUntil then return end
	WCDPanel:StartTicker("professions:rescan", 0.5, function()
		WCDPanel:StopTicker("professions:rescan")
		if P.enabled then P:Rescan() end
	end)
end

function P:GetText(el)
	local skillLineId = WCDPanel.elements[el].subId
	local def, info = PROFESSIONS[skillLineId], state[skillLineId]
	if not info then return "", "" end
	local label = displayName(skillLineId)
	if def.single or not info.rank or not info.maxRank then return label, "" end
	local value = WCDPanel.Util.Color(info.rank, WCDPanel.Util.RatioColor(info.rank / math.max(info.maxRank, 1)))
		.. WCDPanel.Util.Gray("/" .. info.maxRank)
	if info.modifier and info.modifier > 0 then value = value .. WCDPanel.Util.Green(" +" .. info.modifier) end
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
	tooltip:SetText(displayName(skillLineId))
	if not def.single and info.rank and info.maxRank then
		tooltip:AddLine(format("Nivel %d / %d", info.rank, info.maxRank), 1, 1, 1)
		if info.modifier and info.modifier > 0 then tooltip:AddLine(format("Bonificación: +%d", info.modifier), 0.1, 1, 0.1) end
		if info.maxRank < 450 and info.rank >= info.maxRank - 25 then
			tooltip:AddLine("Cerca del máximo: busca un instructor para el siguiente rango.", 1, 0.6, 0)
		end
	end
	if def.noClick then
		tooltip:AddLine("Esta profesión no tiene ventana propia.", 0.6, 0.6, 0.6)
	else
		tooltip:AddLine("Clic: " .. (GetSpellInfo(def.clickSpell or info.spellId) or "abrir"), 0.6, 0.6, 0.6)
	end
	if def.shiftSpell then
		tooltip:AddLine("Mayús+clic: " .. (GetSpellInfo(def.shiftSpell) or ""), 0.6, 0.6, 0.6)
	end
end
