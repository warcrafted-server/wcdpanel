local defaults = {
	profile = {
		initialized = false,
		general = {
			locked = false,
			spacing = 14,
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

function WCDPanel:InitDB()
	if self.db then return end
	self.db = LibStub("AceDB-3.0"):New("WCDPanelDB", defaults, true)
	if self.db.profile.schema ~= SCHEMA then
		self.db:ResetProfile(false, true)
		self.db.profile.schema = SCHEMA
	end
end
