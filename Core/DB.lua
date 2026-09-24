local defaults = {
	profile = {
		general = {
			locked = false,
			spacing = 12,
			iconSpacing = 4,
			iconSize = 16,
			font = { name = "Friz Quadrata TT", size = 10 },
			hideTooltipsInCombat = false,
			ldbLaunchersRight = true,
			adjust = {},
		},
		bars = {},
		plugins = {},
		elements = {},
	},
}

function WCDPanel:InitDB()
	if self.db then return end
	self.db = LibStub("AceDB-3.0"):New("WCDPanelDB", defaults, true)
end
