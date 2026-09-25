-- Panel de opciones (AceConfig): General, Barras, Plugins y Perfiles. La tabla se regenera cada
-- vez que se pide (RegisterOptionsTable con función) y tras cada cambio estructural se avisa con
-- NotifyChange, así refleja siempre las barras y elementos que existen.

local EDGE_NAMES = { TOP = "Arriba", BOTTOM = "Abajo", FREE = "Libre" }
local ZONE_NAMES = { LEFT = "Izquierda", CENTER = "Centro", RIGHT = "Derecha" }

local function refresh()
	LibStub("AceConfigRegistry-3.0"):NotifyChange("wcdpanel")
end
WCDPanel.RefreshOptions = refresh

local function barCfg(id) return WCDPanel.db.profile.bars[id] end

local function barChoices()
	local choices = { [0] = "(ninguna)" }
	for id, cfg in pairs(WCDPanel.db.profile.bars) do
		choices[id] = cfg.name .. " (" .. (EDGE_NAMES[cfg.edge] or cfg.edge) .. ")"
	end
	return choices
end

local function buildBarArgs()
	local args = {
		addTop = { type = "execute", order = 1, name = "Añadir arriba", func = function() WCDPanel:CreateBar({ edge = "TOP" }) refresh() end },
		addBottom = { type = "execute", order = 2, name = "Añadir abajo", func = function() WCDPanel:CreateBar({ edge = "BOTTOM" }) refresh() end },
		addFree = { type = "execute", order = 3, name = "Añadir libre", func = function() WCDPanel:CreateBar({ edge = "FREE" }) refresh() end },
	}
	for id, cfg in pairs(WCDPanel.db.profile.bars) do
		args["bar" .. id] = {
			type = "group", order = 10 + id, name = cfg.name,
			args = {
				name = {
					type = "input", order = 1, name = "Nombre",
					get = function() return barCfg(id).name end,
					set = function(_, v) barCfg(id).name = v refresh() end,
				},
				edge = {
					type = "select", order = 2, name = "Posición", values = EDGE_NAMES,
					get = function() return barCfg(id).edge end,
					set = function(_, v)
						barCfg(id).edge = v
						barCfg(id).screenAdjust = v ~= "FREE"
						WCDPanel:PositionAllBars()
						refresh()
					end,
				},
				stack = {
					type = "range", order = 3, name = "Orden de apilado", min = 1, max = 10, step = 1,
					desc = "Con varias barras en el mismo borde, la de número más bajo va más pegada al borde.",
					get = function() return barCfg(id).stack end,
					set = function(_, v) barCfg(id).stack = v WCDPanel:PositionAllBars() end,
				},
				height = {
					type = "range", order = 4, name = "Altura", min = 14, max = 40, step = 1,
					get = function() return barCfg(id).height end,
					set = function(_, v) barCfg(id).height = v WCDPanel:PositionAllBars() end,
				},
				width = {
					type = "range", order = 5, name = "Ancho (barra libre)", min = 100, max = 2000, step = 10,
					hidden = function() return barCfg(id).edge ~= "FREE" end,
					get = function() return barCfg(id).width end,
					set = function(_, v) barCfg(id).width = v WCDPanel:PositionBar(id) WCDPanel:LayoutMarkDirty(id) end,
				},
				scale = {
					type = "range", order = 6, name = "Escala", min = 0.5, max = 2, step = 0.05,
					get = function() return barCfg(id).scale end,
					set = function(_, v) barCfg(id).scale = v WCDPanel:ApplyBarAppearance(id) WCDPanel:PositionAllBars() end,
				},
				alpha = {
					type = "range", order = 7, name = "Opacidad", min = 0.1, max = 1, step = 0.05,
					get = function() return barCfg(id).alpha end,
					set = function(_, v) barCfg(id).alpha = v WCDPanel:ApplyBarAppearance(id) end,
				},
				bg = {
					type = "color", order = 8, name = "Color de fondo", hasAlpha = true,
					get = function() local c = barCfg(id).bg return c.r, c.g, c.b, c.a end,
					set = function(_, r, g, b, a)
						local c = barCfg(id).bg
						c.r, c.g, c.b, c.a = r, g, b, a
						WCDPanel:ApplyBarAppearance(id)
					end,
				},
				screenAdjust = {
					type = "toggle", order = 9, name = "Desplazar la interfaz", width = "full",
					desc = "Baja (o sube) el minimapa, los retratos y las barras de acción para que no queden tapados.",
					hidden = function() return barCfg(id).edge == "FREE" end,
					get = function() return barCfg(id).screenAdjust end,
					set = function(_, v) barCfg(id).screenAdjust = v WCDPanel:ScreenAdjustAll() end,
				},
				autoHide = {
					type = "toggle", order = 10, name = "Autoocultar",
					get = function() return barCfg(id).autoHide end,
					set = function(_, v) WCDPanel:SetBarAutoHide(id, v) end,
				},
				hideInCombat = {
					type = "toggle", order = 11, name = "Ocultar en combate",
					get = function() return barCfg(id).hideInCombat end,
					set = function(_, v) barCfg(id).hideInCombat = v WCDPanel:ApplyBarAppearance(id) end,
				},
				locked = {
					type = "toggle", order = 12, name = "Bloqueada",
					get = function() return barCfg(id).locked end,
					set = function(_, v) barCfg(id).locked = v end,
				},
				delete = {
					type = "execute", order = 20, name = "Borrar barra", confirm = true,
					confirmText = "Los elementos de esta barra se quitarán de las barras.",
					func = function() WCDPanel:DeleteBar(id) refresh() end,
				},
			},
		}
	end
	return args
end

local function elementTitle(runtime)
	return (runtime.info and runtime.info.title) or runtime.plugin.opts.title or runtime.id
end

local function elementGroup(id, order)
	local runtime = WCDPanel.elements[id]
	local cfg = function() return WCDPanel.db.profile.elements[id] end
	local group = {
		type = "group", inline = true, order = order, name = elementTitle(runtime),
		args = {
			bar = {
				type = "select", order = 1, name = "Barra", values = barChoices(),
				get = function() return cfg().bar or 0 end,
				set = function(_, v) WCDPanel:PlaceElement(id, v ~= 0 and v or false) end,
			},
			zone = {
				type = "select", order = 2, name = "Zona", values = ZONE_NAMES,
				get = function() return cfg().zone end,
				set = function(_, v) WCDPanel:PlaceElement(id, cfg().bar, v) end,
			},
			order = {
				type = "range", order = 3, name = "Posición en la zona", min = 1, max = 40, step = 1,
				desc = "1 es el más pegado al borde (en la zona derecha, al borde derecho).",
				disabled = function() return not cfg().bar end,
				get = function() return select(3, WCDPanel:FindInZones(id)) or 1 end,
				set = function(_, v) WCDPanel:PlaceElement(id, cfg().bar, nil, v) end,
			},
		},
	}
	if not runtime.foreign then
		local function toggle(field, name, ord)
			return {
				type = "toggle", order = ord, name = name,
				get = function() return cfg()[field] end,
				set = function(_, v) cfg()[field] = v WCDPanel:RefreshElement(id) end,
			}
		end
		group.args.showIcon = toggle("showIcon", "Icono", 4)
		group.args.showLabel = toggle("showLabel", "Etiqueta", 5)
		group.args.showText = toggle("showText", "Valor", 6)
	end
	return group
end

local function buildPluginArgs()
	local args = {}
	for order, pid in ipairs(WCDPanel.pluginOrder) do
		local plugin = WCDPanel.plugins[pid]
		local group = {
			type = "group", order = order, name = plugin.opts.title or pid,
			args = {
				enabled = {
					type = "toggle", order = 1, name = "Activado", width = "full",
					get = function() return WCDPanel:IsPluginEnabled(pid) end,
					set = function(_, v) WCDPanel:SetPluginEnabled(pid, v) refresh() end,
				},
			},
		}
		if plugin.opts.description then
			group.args.desc = { type = "description", order = 0, name = plugin.opts.description }
		end
		if plugin.GetOptions and plugin.enabled then
			for key, opt in pairs(plugin:GetOptions()) do
				opt.order = (opt.order or 0) + 10
				group.args[key] = opt
			end
		end
		local ids = {}
		for id in pairs(plugin._elements) do table.insert(ids, id) end
		table.sort(ids, function(a, b) return elementTitle(WCDPanel.elements[a]) < elementTitle(WCDPanel.elements[b]) end)
		for i, id in ipairs(ids) do
			group.args["el" .. i] = elementGroup(id, 100 + i)
		end
		args["plugin" .. pid] = group
	end
	return args
end

local function buildOptions()
	local general = WCDPanel.db.profile.general
	return {
		type = "group",
		name = "wcdpanel",
		args = {
			general = {
				type = "group", order = 1, name = "General",
				args = {
					help = {
						type = "description", order = 0,
						name = "Clic derecho en un elemento o en el fondo de una barra abre su menú. " ..
							"Con las barras desbloqueadas, arrastra un elemento para moverlo.",
					},
					locked = {
						type = "toggle", order = 1, name = "Bloquear todas las barras", width = "full",
						get = function() return general.locked end,
						set = function(_, v) WCDPanel:SetLocked(v) end,
					},
					spacing = {
						type = "range", order = 2, name = "Separación entre elementos", min = 2, max = 40, step = 1,
						get = function() return general.spacing end,
						set = function(_, v) general.spacing = v WCDPanel:ReflowAll() end,
					},
					iconGap = {
						type = "range", order = 2.5, name = "Separación entre iconos", min = 0, max = 20, step = 1,
						desc = "Distancia entre dos iconos consecutivos sin etiqueta (LDB, minimapa, volumen...).",
						get = function() return general.iconGap end,
						set = function(_, v) general.iconGap = v WCDPanel:ReflowAll() end,
					},
					iconSize = {
						type = "range", order = 3, name = "Tamaño de icono", min = 10, max = 28, step = 1,
						get = function() return general.iconSize end,
						set = function(_, v)
							general.iconSize = v
							for id in pairs(WCDPanel.elements) do WCDPanel:RefreshElement(id) end
						end,
					},
					hideTooltipsInCombat = {
						type = "toggle", order = 4, name = "Sin tooltips en combate", width = "full",
						get = function() return general.hideTooltipsInCombat end,
						set = function(_, v) general.hideTooltipsInCombat = v end,
					},
				},
			},
			bars = { type = "group", order = 2, name = "Barras", args = buildBarArgs() },
			plugins = { type = "group", order = 3, name = "Plugins", args = buildPluginArgs() },
			profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(WCDPanel.db),
		},
	}
end

function WCDPanel:InitOptions()
	if self._optionsDialog then return end
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("wcdpanel", buildOptions)
	self._optionsDialog = LibStub("AceConfigDialog-3.0")
	self._optionsDialog:AddToBlizOptions("wcdpanel", "wcdpanel")
	self._optionsDialog:SetDefaultSize("wcdpanel", 760, 560)
end

function WCDPanel:OpenOptions()
	self:InitOptions()
	self._optionsDialog:Open("wcdpanel")
end

-- Solo para el banco de pruebas: la tabla de opciones sin pasar por AceConfigDialog.
WCDPanel._debugBuildOptions = buildOptions
