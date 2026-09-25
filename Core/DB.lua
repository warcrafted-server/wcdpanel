local defaults = {
	profile = {
		initialized = false,
		general = {
			locked = false,
			spacing = 14,
			iconGap = 4,
			iconSize = 16,
			hideTooltipsInCombat = false,
			ldbLaunchersIconOnly = true,
			adjust = {},
		},
		bars = {},
		plugins = {},
		elements = {},
	},
}

-- Sube al cambiar el formato del perfil de forma incompatible: los perfiles anteriores se
-- reinician una vez en vez de arrastrar colocaciones que ya no tienen sentido.
local SCHEMA = 2

-- Cambios de valor por defecto que no justifican un reinicio completo del perfil (perdería la
-- colocación que el usuario ya haya ajustado a mano): se aplican una vez a cada perfil, aquí y en
-- cada cambio de perfil (ver ReloadProfile en Core.lua).
function WCDPanel:PatchProfile()
	local profile = self.db.profile
	if not profile.professionsIconOnly then
		for id, cfg in pairs(profile.elements) do
			if id:match("^Professions:") then
				cfg.showLabel, cfg.showText = false, false
			end
		end
		profile.professionsIconOnly = true
	end
end

function WCDPanel:InitDB()
	if self.db then return end
	self.db = LibStub("AceDB-3.0"):New("WCDPanelDB", defaults, true)
	if self.db.profile.schema ~= SCHEMA then
		self.db:ResetProfile(false, true)
		self.db.profile.schema = SCHEMA
	end
	self:PatchProfile()
end
