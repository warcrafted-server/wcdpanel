-- Plugin de prueba de la fase 1, para validar el núcleo de barras en juego.
-- Se retira antes de empezar la fase 5 (plugins reales).
local P = WCDPanel:NewPlugin("Test", {
	title = "Prueba",
	category = "Depuración",
	defaultPlacement = { bar = false, zone = "LEFT", order = 1 },
	events = { "PLAYER_ENTERING_WORLD" },
	interval = 5,
})

function P:OnEnable()
	self.ticks = 0
end

function P:OnEvent()
	self:Refresh()
end

function P:OnTick()
	self.ticks = self.ticks + 1
	self:Refresh()
end

function P:GetText()
	return "Prueba", tostring(self.ticks)
end

function P:GetIcon()
	return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function P:OnTooltip(el, tooltip)
	tooltip:SetText("Plugin de prueba")
	tooltip:AddLine("Ticks: " .. self.ticks)
end

function P:OnClick(el, button)
	self:Print("clic " .. button)
end
