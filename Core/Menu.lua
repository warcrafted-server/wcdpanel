-- Menú contextual (clic derecho) de un elemento, con EasyMenu/UIDropDownMenu de Blizzard.

local menuFrame = CreateFrame("Frame", "WCDPanelElementMenu", UIParent, "UIDropDownMenuTemplate")

local function toggle(cfg, field, id)
	return function()
		cfg[field] = not cfg[field]
		WCDPanel:RefreshElement(id)
	end
end

function WCDPanel:ShowElementMenu(id, anchor)
	local runtime = self.elements[id]
	if not runtime then return end
	local plugin, cfg = runtime.plugin, self.db.profile.elements[id]

	local menu = {
		{ text = plugin.opts.title or plugin.id, isTitle = true, notCheckable = true },
		{ text = "Icono", checked = cfg.showIcon, isNotRadio = true, keepShownOnClick = true,
			func = toggle(cfg, "showIcon", id) },
		{ text = "Etiqueta", checked = cfg.showLabel, isNotRadio = true, keepShownOnClick = true,
			func = toggle(cfg, "showLabel", id) },
		{ text = "Valor", checked = cfg.showText, isNotRadio = true, keepShownOnClick = true,
			func = toggle(cfg, "showText", id) },
		{ text = "Texto coloreado", checked = cfg.colored, isNotRadio = true, keepShownOnClick = true,
			func = toggle(cfg, "colored", id) },
		{ text = "Ocultar", notCheckable = true, func = function() WCDPanel:PlaceElement(id, false) end },
	}

	if plugin.BuildMenu then plugin:BuildMenu(id, menu) end

	EasyMenu(menu, menuFrame, anchor, 0, 0, "MENU")
end
