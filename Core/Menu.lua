-- Menús contextuales con EasyMenu (UIDropDownMenu de Blizzard): clic derecho en un elemento
-- (Ctrl+clic derecho en los que usan su propio clic derecho, como los de LDB) y en el fondo
-- de una barra.

local menuFrame = CreateFrame("Frame", "WCDPanelContextMenu", UIParent, "UIDropDownMenuTemplate")

local ZONE_NAMES = { LEFT = "Izquierda", CENTER = "Centro", RIGHT = "Derecha" }
local ZONE_ORDER = { "LEFT", "CENTER", "RIGHT" }

local function title(text) return { text = text, isTitle = true, notCheckable = true } end
local function spacer() return { text = " ", disabled = true, notCheckable = true } end

local function sortedBarIds()
	local ids = {}
	for id in pairs(WCDPanel.db.profile.bars) do table.insert(ids, id) end
	table.sort(ids)
	return ids
end

local function markMenuOpen(barId)
	for id, runtime in pairs(WCDPanel.bars) do runtime.menuOpen = (id == barId) end
end

local function show(menu, anchor, barId)
	markMenuOpen(barId)
	EasyMenu(menu, menuFrame, anchor, 0, 0, "MENU")
end

local function toggleEntry(text, cfg, field, id)
	return {
		text = text, checked = cfg[field], keepShownOnClick = true,
		func = function()
			cfg[field] = not cfg[field]
			WCDPanel:RefreshElement(id)
		end,
	}
end

local function moveSubmenu(id)
	local list = {}
	for _, barId in ipairs(sortedBarIds()) do
		local bar = WCDPanel.db.profile.bars[barId]
		local zones = {}
		for _, zone in ipairs(ZONE_ORDER) do
			table.insert(zones, {
				text = ZONE_NAMES[zone], notCheckable = true,
				func = function()
					WCDPanel:PlaceElement(id, barId, zone, 999)
					CloseDropDownMenus()
				end,
			})
		end
		table.insert(list, { text = bar.name, notCheckable = true, hasArrow = true, menuList = zones })
	end
	return list
end

function WCDPanel:ShowElementMenu(id, anchor)
	local runtime = self.elements[id]
	if not runtime then return end
	local plugin, cfg = runtime.plugin, self.db.profile.elements[id]

	local menu = { title((runtime.info and runtime.info.title) or plugin.opts.title or id) }
	if not runtime.foreign then
		table.insert(menu, toggleEntry("Mostrar icono", cfg, "showIcon", id))
		table.insert(menu, toggleEntry("Mostrar etiqueta", cfg, "showLabel", id))
		table.insert(menu, toggleEntry("Mostrar valor", cfg, "showText", id))
		table.insert(menu, toggleEntry("Colores", cfg, "colored", id))
	end
	if plugin.BuildMenu then
		table.insert(menu, spacer())
		plugin:BuildMenu(id, menu)
	end
	table.insert(menu, spacer())
	table.insert(menu, { text = "Mover a", notCheckable = true, hasArrow = true, menuList = moveSubmenu(id) })
	table.insert(menu, { text = "Quitar de la barra", notCheckable = true, func = function() WCDPanel:PlaceElement(id, false) end })
	table.insert(menu, { text = "Opciones de wcdpanel", notCheckable = true, func = function() WCDPanel:OpenOptions() end })
	show(menu, anchor, cfg.bar)
end

function WCDPanel:ShowBarMenu(barId, anchor)
	local cfg = self.db.profile.bars[barId]
	if not cfg then return end
	local menu = {
		title(cfg.name),
		{ text = "Autoocultar", checked = cfg.autoHide, func = function() WCDPanel:SetBarAutoHide(barId, not cfg.autoHide) end },
		{ text = "Bloquear todas las barras", checked = self.db.profile.general.locked,
			func = function() WCDPanel:SetLocked(not WCDPanel.db.profile.general.locked) end },
		spacer(),
		{ text = "Añadir barra arriba", notCheckable = true, func = function() WCDPanel:CreateBar({ edge = "TOP" }) end },
		{ text = "Añadir barra abajo", notCheckable = true, func = function() WCDPanel:CreateBar({ edge = "BOTTOM" }) end },
		{ text = "Añadir barra libre", notCheckable = true, func = function() WCDPanel:CreateBar({ edge = "FREE" }) end },
		spacer(),
		{ text = "Opciones de wcdpanel", notCheckable = true, func = function() WCDPanel:OpenOptions() end },
	}
	show(menu, "cursor", barId)
end
