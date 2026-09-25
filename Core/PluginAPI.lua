-- Registro de plugins. Los plugins se registran al cargarse el archivo (antes de que la base
-- de datos exista), así que aquí solo se guarda la definición; activarlos (namespace de la
-- base de datos, eventos, frame del elemento) pasa en WCDPanel:ActivatePlugins, tras InitDB.

WCDPanel.plugins = WCDPanel.plugins or {}
WCDPanel.pluginOrder = WCDPanel.pluginOrder or {}

local PluginMixin = {}
WCDPanel.PluginMixin = PluginMixin

function PluginMixin:Print(msg)
	WCDPanel:Print((self.opts.title or self.id) .. ": " .. tostring(msg))
end

-- subId nil = el propio plugin es el elemento (caso normal).
-- subId presente = plugin con elementos dinámicos (LDB, profesiones, botones de minimapa).
function PluginMixin:ElementId(subId)
	return subId ~= nil and (self.id .. ":" .. subId) or self.id
end

function PluginMixin:AddElement(subId, info)
	local id = self:ElementId(subId)
	WCDPanel:RegisterElement(id, self, subId, info)
	return id
end

function PluginMixin:RemoveElement(subId)
	WCDPanel:UnregisterElement(self:ElementId(subId))
end

function PluginMixin:Refresh(elementId)
	if elementId then
		WCDPanel:RefreshElement(elementId)
	else
		for id in pairs(self._elements) do WCDPanel:RefreshElement(id) end
	end
end

function WCDPanel:NewPlugin(id, opts)
	assert(not self.plugins[id], "plugin ya registrado: " .. id)
	assert(type(opts) == "table", "faltan las opciones del plugin: " .. id)
	local plugin = setmetatable({ id = id, opts = opts, _elements = {}, enabled = false }, { __index = PluginMixin })
	self.plugins[id] = plugin
	table.insert(self.pluginOrder, id)
	return plugin
end

function WCDPanel:IsPluginEnabled(id)
	local cfg = self.db.profile.plugins[id]
	if cfg == nil then
		local plugin = self.plugins[id]
		return not (plugin and plugin.opts.enabledByDefault == false)
	end
	return cfg.enabled ~= false
end

function WCDPanel:EnablePlugin(plugin)
	if plugin.enabled then return end
	plugin.enabled = true

	-- El namespace de AceDB se registra una sola vez: da error si se repite, y ya sigue él solo
	-- los cambios de perfil.
	if plugin.opts.defaults and not plugin.db then
		plugin.db = self.db:RegisterNamespace(plugin.id, plugin.opts.defaults)
	end

	if plugin.opts.events then
		plugin._eventFrame = plugin._eventFrame or CreateFrame("Frame")
		local frame = plugin._eventFrame
		frame:SetScript("OnEvent", function(_, event, ...)
			if plugin.enabled and plugin.OnEvent then plugin:OnEvent(event, ...) end
		end)
		for _, event in ipairs(plugin.opts.events) do frame:RegisterEvent(event) end
	end

	if plugin.opts.interval and plugin.OnTick then
		self:StartTicker("plugin:" .. plugin.id, plugin.opts.interval, function(elapsed)
			if plugin.enabled then plugin:OnTick(elapsed) end
		end)
	end

	if not plugin.opts.dynamicElements then
		self:RegisterElement(plugin.id, plugin, nil)
	end

	if plugin.OnEnable then plugin:OnEnable() end
	plugin:Refresh()
end

function WCDPanel:DisablePlugin(plugin)
	if not plugin.enabled then return end
	plugin.enabled = false

	if plugin._eventFrame then
		plugin._eventFrame:UnregisterAllEvents()
		plugin._eventFrame:SetScript("OnEvent", nil)
	end
	self:StopTicker("plugin:" .. plugin.id)

	if plugin.OnDisable then plugin:OnDisable() end

	local ids = {}
	for id in pairs(plugin._elements) do table.insert(ids, id) end
	for _, id in ipairs(ids) do self:UnregisterElement(id) end
end

function WCDPanel:SetPluginEnabled(id, enabled)
	local plugin = self.plugins[id]
	if not plugin then return end
	self.db.profile.plugins[id] = self.db.profile.plugins[id] or {}
	self.db.profile.plugins[id].enabled = enabled and true or false
	if enabled then self:EnablePlugin(plugin) else self:DisablePlugin(plugin) end
end

function WCDPanel:ActivatePlugins()
	for _, id in ipairs(self.pluginOrder) do
		if self:IsPluginEnabled(id) then self:EnablePlugin(self.plugins[id]) end
	end
end

function WCDPanel:DeactivatePlugins()
	for _, id in ipairs(self.pluginOrder) do self:DisablePlugin(self.plugins[id]) end
end
