-- Chincheta por barra: clic activa/desactiva el autoocultar de esa barra concreta.
local P = WCDPanel:NewPlugin("AutoHide", {
	title = "Autoocultar",
	category = "Núcleo",
	dynamicElements = true,
})

local PINNED = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local UNPINNED = "Interface\\Buttons\\UI-GroupLoot-Pass-Down"

local function placementFor(barId)
	return { bar = barId, zone = "RIGHT", order = 100 }
end

function P:OnEnable()
	for barId in pairs(WCDPanel.db.profile.bars) do
		self:AddElement(barId, { defaultPlacement = placementFor(barId) })
	end
	-- El hook es del plugin, no del perfil: se registra una sola vez y sobrevive a los
	-- cambios de perfil (si no, cada reactivación añadiría otro cierre duplicado).
	if not self._hookRegistered then
		WCDPanel:OnBarCreatedHook(function(barId)
			if P.enabled then
				P:AddElement(barId, { defaultPlacement = placementFor(barId) })
			end
		end)
		self._hookRegistered = true
	end
end

local function barIdOf(el)
	return WCDPanel.elements[el].subId
end

function P:GetIcon(el)
	local cfg = WCDPanel.db.profile.bars[barIdOf(el)]
	return (cfg and cfg.autoHide) and PINNED or UNPINNED
end

function P:GetText()
	return "", ""
end

function P:OnClick(el)
	local barId = barIdOf(el)
	local cfg = WCDPanel.db.profile.bars[barId]
	if not cfg then return end
	WCDPanel:SetBarAutoHide(barId, not cfg.autoHide)
	self:Refresh(el)
end

function P:OnTooltip(el, tooltip)
	local barId = barIdOf(el)
	local cfg = WCDPanel.db.profile.bars[barId]
	tooltip:SetText("Autoocultar")
	tooltip:AddLine(cfg and cfg.autoHide and "Activado en esta barra" or "Desactivado en esta barra")
end
