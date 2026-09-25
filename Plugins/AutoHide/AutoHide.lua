-- Un botón por barra que activa/desactiva el autoocultar de esa barra.
local P = WCDPanel:NewPlugin("AutoHide", {
	title = "Autoocultar",
	description = "Un botón en cada barra para activar o desactivar su autoocultar.",
	dynamicElements = true,
	interval = 0.5,
})

local ICON_SHOWN = "Interface\\Buttons\\Arrow-Up-Up"
local ICON_HIDDEN = "Interface\\Buttons\\Arrow-Down-Up"

local function barOf(el) return WCDPanel.elements[el].subId end

function P:AddFor(barId)
	self:AddElement(barId, {
		title = "Autoocultar: " .. (WCDPanel.db.profile.bars[barId] and WCDPanel.db.profile.bars[barId].name or barId),
		defaultPlacement = { bar = barId, zone = "RIGHT", order = 4 },
	})
end

function P:OnEnable()
	for barId in pairs(WCDPanel.db.profile.bars) do self:AddFor(barId) end
	-- El hook pertenece al plugin, no al perfil: una sola vez aunque OnEnable se repita.
	if not self.hooked then
		self.hooked = true
		WCDPanel:OnBarCreatedHook(function(barId) if P.enabled then P:AddFor(barId) end end)
	end
	self.last = {}
end

-- El autoocultar también se cambia desde las opciones o el menú de la barra: se vigila.
function P:OnTick()
	for el in pairs(self._elements) do
		local cfg = WCDPanel.db.profile.bars[barOf(el)]
		local state = cfg and cfg.autoHide or false
		if self.last[el] ~= state then
			self.last[el] = state
			WCDPanel:RefreshElement(el)
		end
	end
end

function P:GetIcon(el)
	local cfg = WCDPanel.db.profile.bars[barOf(el)]
	return (cfg and cfg.autoHide) and ICON_HIDDEN or ICON_SHOWN
end

function P:OnClick(el, button)
	if button ~= "LeftButton" then return end
	local barId = barOf(el)
	local cfg = WCDPanel.db.profile.bars[barId]
	if cfg then WCDPanel:SetBarAutoHide(barId, not cfg.autoHide) end
end

function P:OnTooltip(el, tooltip)
	local cfg = WCDPanel.db.profile.bars[barOf(el)]
	tooltip:SetText("Autoocultar")
	tooltip:AddLine(cfg and cfg.autoHide and "Activado: la barra se oculta sin el ratón encima." or "Desactivado.", 1, 1, 1)
	tooltip:AddLine("Clic para cambiarlo.", 0.6, 0.6, 0.6)
end
