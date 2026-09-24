-- Panel de opciones (AceConfig): General, Barras, Plugins y Perfiles.
-- Los grupos de Barras y Plugins se generan al vuelo, así que reflejan siempre el estado
-- actual (barras creadas/borradas, plugins activados/desactivados) sin duplicar datos.

local EDGE_NAMES = { TOP = "Arriba", BOTTOM = "Abajo", FREE = "Libre" }

local function barCfg(id) return WCDPanel.db.profile.bars[id] end

local function buildBarArgs()
	local args = {}
	for id, cfg in pairs(WCDPanel.db.profile.bars) do
		args["bar" .. id] = {
			type = "group",
			inline = true,
			order = id,
			name = (cfg.name or ("Barra " .. id)) .. " (" .. (EDGE_NAMES[cfg.edge] or cfg.edge) .. ")",
			args = {
				edge = {
					type = "select", order = 1, name = "Posición",
					values = EDGE_NAMES,
					get = function() return barCfg(id).edge end,
					set = function(_, v)
						barCfg(id).edge = v
						WCDPanel:PositionBar(id)
						WCDPanel:ScreenAdjustAll()
					end,
				},
				height = {
					type = "range", order = 2, name = "Altura", min = 12, max = 64, step = 1,
					get = function() return barCfg(id).height end,
					set = function(_, v)
						barCfg(id).height = v
						WCDPanel:PositionBar(id)
						WCDPanel:ScreenAdjustAll()
					end,
				},
				alpha = {
					type = "range", order = 3, name = "Opacidad", min = 0.1, max = 1, step = 0.05,
					get = function() return barCfg(id).alpha end,
					set = function(_, v)
						barCfg(id).alpha = v
						WCDPanel:ApplyBarAppearance(id)
						if not barCfg(id).autoHide then WCDPanel:RevealBar(id) end
					end,
				},
				scale = {
					type = "range", order = 4, name = "Escala", min = 0.5, max = 2, step = 0.05,
					get = function() return barCfg(id).scale end,
					set = function(_, v) barCfg(id).scale = v WCDPanel:ApplyBarAppearance(id) end,
				},
				stack = {
					type = "range", order = 5, name = "Orden de apilado", min = 1, max = 10, step = 1,
					get = function() return barCfg(id).stack end,
					set = function(_, v)
						barCfg(id).stack = v
						for otherId in pairs(WCDPanel.db.profile.bars) do WCDPanel:PositionBar(otherId) end
						WCDPanel:ScreenAdjustAll()
					end,
				},
				screenAdjust = {
					type = "toggle", order = 6, name = "Desplazar interfaz de Blizzard",
					get = function() return barCfg(id).screenAdjust end,
					set = function(_, v) barCfg(id).screenAdjust = v WCDPanel:ScreenAdjustAll() end,
				},
				autoHide = {
					type = "toggle", order = 7, name = "Autoocultar",
					get = function() return barCfg(id).autoHide end,
					set = function(_, v) WCDPanel:SetBarAutoHide(id, v) end,
				},
				locked = {
					type = "toggle", order = 8, name = "Bloqueada", desc = "No se puede arrastrar",
					get = function() return barCfg(id).locked end,
					set = function(_, v) barCfg(id).locked = v end,
				},
				delete = {
					type = "execute", order = 9, name = "Borrar barra", confirm = true,
					func = function() WCDPanel:DeleteBar(id) end,
				},
			},
		}
	end
	return args
end

local function barChoices()
	local choices = { [false] = "(ninguna)" }
	for id, cfg in pairs(WCDPanel.db.profile.bars) do
		choices[id] = (cfg.name or ("Barra " .. id)) .. " (" .. (EDGE_NAMES[cfg.edge] or cfg.edge) .. ")"
	end
	return choices
end

local function elementCfg(pid)
	return WCDPanel.db.profile.elements[pid]
end

local function buildPluginArgs()
	local args = {}
	for order, pid in ipairs(WCDPanel.pluginOrder) do
		local plugin = WCDPanel.plugins[pid]
		local group = {
			type = "group",
			inline = true,
			order = order,
			name = plugin.opts.title or pid,
			args = {
				enabled = {
					type = "toggle", order = 1, name = "Activado",
					get = function() return WCDPanel:IsPluginEnabled(pid) end,
					set = function(_, v)
						WCDPanel.db.profile.plugins[pid] = WCDPanel.db.profile.plugins[pid] or {}
						WCDPanel.db.profile.plugins[pid].enabled = v
						if v then WCDPanel:EnablePlugin(plugin) else WCDPanel:DisablePlugin(plugin) end
					end,
				},
			},
		}
		-- Un plugin con un único elemento fijo se puede colocar desde aquí; uno con
		-- elementos dinámicos (LDB, profesiones...) gestiona su propia colocación.
		if not plugin.opts.dynamicElements then
			group.args.bar = {
				type = "select", order = 2, name = "Barra",
				values = barChoices(),
				get = function() local c = elementCfg(pid) return c and c.bar or false end,
				set = function(_, v) WCDPanel:PlaceElement(pid, v) end,
			}
			group.args.zone = {
				type = "select", order = 3, name = "Zona",
				values = { LEFT = "Izquierda", CENTER = "Centro", RIGHT = "Derecha" },
				get = function() local c = elementCfg(pid) return c and c.zone or "LEFT" end,
				set = function(_, v)
					local c = elementCfg(pid)
					WCDPanel:PlaceElement(pid, c and c.bar, v)
				end,
			}
			group.args.order = {
				type = "range", order = 4, name = "Orden", min = 1, max = 20, step = 1,
				get = function() local c = elementCfg(pid) return c and c.order or 1 end,
				set = function(_, v)
					local c = elementCfg(pid)
					WCDPanel:PlaceElement(pid, c and c.bar, nil, v)
				end,
			}
		end
		if plugin.GetOptions then
			local sub = plugin:GetOptions()
			if sub then
				for key, opt in pairs(sub) do
					opt.order = (opt.order or 0) + 10
					group.args[key] = opt
				end
			end
		end
		args["plugin" .. pid] = group
	end
	return args
end

local function buildOptions()
	return {
		type = "group",
		name = "wcdpanel",
		args = {
			general = {
				type = "group", order = 1, name = "General",
				args = {
					locked = {
						type = "toggle", order = 1, name = "Bloquear todas las barras",
						get = function() return WCDPanel.db.profile.general.locked end,
						set = function(_, v) WCDPanel.db.profile.general.locked = v end,
					},
					spacing = {
						type = "range", order = 2, name = "Separación entre elementos",
						min = 0, max = 40, step = 1,
						get = function() return WCDPanel.db.profile.general.spacing end,
						set = function(_, v)
							WCDPanel.db.profile.general.spacing = v
							for id in pairs(WCDPanel.bars) do WCDPanel:Reflow(id) end
						end,
					},
					iconSize = {
						type = "range", order = 3, name = "Tamaño de icono",
						min = 10, max = 32, step = 1,
						get = function() return WCDPanel.db.profile.general.iconSize end,
						set = function(_, v)
							WCDPanel.db.profile.general.iconSize = v
							for id in pairs(WCDPanel.elements) do WCDPanel:RefreshElement(id) end
						end,
					},
					hideTooltipsInCombat = {
						type = "toggle", order = 4, name = "Ocultar tooltips en combate",
						get = function() return WCDPanel.db.profile.general.hideTooltipsInCombat end,
						set = function(_, v) WCDPanel.db.profile.general.hideTooltipsInCombat = v end,
					},
				},
			},
			addBar = {
				type = "group", order = 2, name = "Añadir barra",
				args = {
					top = { type = "execute", order = 1, name = "Arriba", func = function() WCDPanel:CreateBar({ edge = "TOP" }) end },
					bottom = { type = "execute", order = 2, name = "Abajo", func = function() WCDPanel:CreateBar({ edge = "BOTTOM" }) end },
					free = { type = "execute", order = 3, name = "Libre", func = function() WCDPanel:CreateBar({ edge = "FREE" }) end },
				},
			},
			bars = { type = "group", order = 3, name = "Barras", args = buildBarArgs() },
			plugins = { type = "group", order = 4, name = "Plugins", args = buildPluginArgs() },
			profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(WCDPanel.db),
		},
	}
end

function WCDPanel:InitOptions()
	local registry = LibStub("AceConfigRegistry-3.0")
	registry:RegisterOptionsTable("wcdpanel", buildOptions)
	local dialog = LibStub("AceConfigDialog-3.0")
	dialog:AddToBlizOptions("wcdpanel", "wcdpanel")
	self._optionsDialog = dialog
end

function WCDPanel:OpenOptions()
	if not self._optionsDialog then self:InitOptions() end
	self._optionsDialog:Open("wcdpanel")
end

-- Solo para el banco de pruebas: acceso directo a la tabla de opciones sin pasar por
-- AceConfigDialog, para comprobar get/set sin simular la interfaz completa de Ace3.
WCDPanel._debugBuildOptions = buildOptions
