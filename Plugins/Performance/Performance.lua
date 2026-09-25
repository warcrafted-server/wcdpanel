-- FPS y latencia. El tooltip lista la memoria de los addons (UpdateAddOnMemoryUsage es costoso:
-- solo se llama al abrir el tooltip). Clic: liberar memoria de Lua.
local Util = WCDPanel.Util

local P = WCDPanel:NewPlugin("Performance", {
	title = "Rendimiento",
	defaults = { profile = { topAddons = 15 } },
	defaultPlacement = { bar = true, zone = "LEFT", order = 9 },
	interval = 1,
})

local function latencyColor(ms)
	if ms < 150 then return "20ff20" end
	if ms < 400 then return "ffff00" end
	return "ff2020"
end

local function fpsColor(fps)
	if fps >= 30 then return "20ff20" end
	if fps >= 15 then return "ffff00" end
	return "ff2020"
end

local function memoryText(kb)
	if kb >= 1024 then return format("%.1f MB", kb / 1024) end
	return format("%d KB", kb)
end

function P:OnTick() self:Refresh() end

function P:GetText()
	local fps = math.floor(GetFramerate() + 0.5)
	local _, _, latency = GetNetStats()
	return "", Util.Color(fps, fpsColor(fps)) .. Util.Gray(" fps  ") .. Util.Color(latency, latencyColor(latency)) .. Util.Gray(" ms")
end

function P:GetIcon() return "Interface\\Icons\\INV_Misc_EngGizmos_27" end

function P:OnTooltip(_, tooltip)
	local fps = GetFramerate()
	local down, up, latency = GetNetStats()
	tooltip:SetText("Rendimiento")
	tooltip:AddDoubleLine("FPS", format("%.1f", fps), 1, 0.82, 0, 1, 1, 1)
	tooltip:AddDoubleLine("Latencia", latency .. " ms", 1, 0.82, 0, 1, 1, 1)
	tooltip:AddDoubleLine("Descarga / subida", format("%.2f / %.2f KB/s", down, up), 1, 0.82, 0, 1, 1, 1)

	UpdateAddOnMemoryUsage()
	local addons, total = {}, 0
	for i = 1, GetNumAddOns() do
		local memory = GetAddOnMemoryUsage(i)
		if memory and memory > 0 then
			local name, title = GetAddOnInfo(i)
			table.insert(addons, { name = title or name, memory = memory })
			total = total + memory
		end
	end
	table.sort(addons, function(a, b) return a.memory > b.memory end)
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine("Memoria de addons", memoryText(total), 1, 0.82, 0, 1, 1, 1)
	for i = 1, math.min(#addons, self.db.profile.topAddons) do
		tooltip:AddDoubleLine("  " .. addons[i].name, memoryText(addons[i].memory), 0.8, 0.8, 0.8, 1, 1, 1)
	end
	tooltip:AddLine(" ")
	tooltip:AddLine("Clic: liberar memoria.", 0.6, 0.6, 0.6)
end

function P:OnClick(_, button)
	if button ~= "LeftButton" then return end
	local before = collectgarbage("count")
	collectgarbage("collect")
	self:Print("memoria liberada: " .. memoryText(before - collectgarbage("count")))
end

function P:GetOptions()
	local db = self.db.profile
	return {
		topAddons = {
			type = "range", order = 1, name = "Addons en el tooltip", min = 5, max = 40, step = 1,
			get = function() return db.topAddons end,
			set = function(_, v) db.topAddons = v end,
		},
	}
end
