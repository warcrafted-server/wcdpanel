-- Un único OnUpdate compartido: temporizadores por intervalo para los OnTick de los
-- plugins, y una cola de "sucios" para repintar elementos como mucho una vez por frame.

local tickers = {}
local dirty = {}
local hasDirty = false

local frame = CreateFrame("Frame")
frame:SetScript("OnUpdate", function(self, elapsed)
	for id, t in pairs(tickers) do
		t.elapsed = t.elapsed + elapsed
		if t.elapsed >= t.interval then
			t.elapsed = 0
			t.fn(t.interval)
		end
	end

	if hasDirty then
		local toFlush = dirty
		dirty = {}
		hasDirty = false
		for _, fn in pairs(toFlush) do
			fn()
		end
	end
end)

function WCDPanel:StartTicker(id, interval, fn)
	tickers[id] = { interval = interval, elapsed = 0, fn = fn }
end

function WCDPanel:StopTicker(id)
	tickers[id] = nil
end

function WCDPanel:MarkDirty(key, fn)
	dirty[key] = fn
	hasDirty = true
end
