local A = ACore

A.movers = {}
local movers = A.movers
local active = false
local grid, bar
local settings = { grid = true, snap = true }
local STEP = 8

local function pretty(name)
	if not name then return nil end
	return (name:gsub("^A(%u%l+)", "A%1 "):gsub("(%l)(%u)", "%1 %2"):gsub("%s+$", ""))
end

function A.RegisterMover(frame, db, onMoved, label, enabled)
	for _, m in ipairs(movers) do
		if m.frame == frame then
			m.db, m.onMoved, m.enabled = db, onMoved, enabled
			return m
		end
	end
	local m = { frame = frame, db = db, onMoved = onMoved, enabled = enabled }
	m.label = label or pretty(frame.GetName and frame:GetName()) or ("Frame " .. (#movers + 1))
	movers[#movers + 1] = m
	if active then A.ShowMover(m) end
	return m
end

function A.NameMover(frame, label)
	for _, m in ipairs(movers) do
		if m.frame == frame then m.label = label end
	end
end

local function combat()
	return InCombatLockdown and InCombatLockdown()
end

local function uiScale()
	local s = UIParent:GetEffectiveScale()
	if type(s) ~= "number" or s <= 0 then return 1 end
	return s
end

local function center(m)
	local x, y = m.frame:GetCenter()
	if type(x) ~= "number" or type(y) ~= "number" then return nil end
	local k = (m.frame:GetEffectiveScale() or 1) / uiScale()
	return x * k, y * k
end

local function place(m, x, y)
	local scale = m.db.scale or 1
	if scale <= 0 then scale = 1 end
	if settings.snap then
		x = math.floor(x / STEP + 0.5) * STEP
		y = math.floor(y / STEP + 0.5) * STEP
	end
	m.db.pos = { "CENTER", "BOTTOMLEFT", x / scale, y / scale }
	if m.frame.Restore then m.frame:Restore() end
	if m.onMoved then pcall(m.onMoved) end
end

local function sync(m)
	local h = m.handle
	if not h then return end
	local w, hh = m.frame:GetWidth() or 0, m.frame:GetHeight() or 0
	local k = (m.frame:GetEffectiveScale() or 1) / uiScale()
	local x, y = center(m)
	h:ClearAllPoints()
	h:SetSize(math.max(24, w * k), math.max(16, hh * k))
	if x then
		h:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	else
		h:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	h.size:SetText(math.floor((m.db.scale or 1) * 100 + 0.5) .. "%")
end

function A.ScaleMover(m, scale)
	if combat() then return end
	scale = math.max(0.4, math.min(3, scale))
	scale = math.floor(scale * 20 + 0.5) / 20
	local x, y = center(m)
	m.db.scale = scale
	if x then
		local snap = settings.snap
		settings.snap = false
		place(m, x, y)
		settings.snap = snap
	elseif m.frame.Restore then
		m.frame:Restore()
	end
	sync(m)
end

function A.ResetMover(m)
	if combat() then return end
	m.db.pos = nil
	m.db.scale = 1
	if m.frame.Restore then m.frame:Restore() end
	if m.onMoved then pcall(m.onMoved) end
	sync(m)
end

local function menu(m)
	local UI = A.UI
	local entries = {
		{ text = m.label, title = true },
		{ text = "Reset position and size", func = function() A.ResetMover(m) end },
		{ text = "Centre horizontally", func = function()
			local _, y = center(m)
			if y then place(m, UIParent:GetWidth() / 2, y) sync(m) end
		end },
		{ text = "Size", title = true },
	}
	for _, s in ipairs({ 0.6, 0.8, 1, 1.2, 1.5, 2 }) do
		entries[#entries + 1] = {
			text = math.floor(s * 100 + 0.5) .. "%", checked = math.abs((m.db.scale or 1) - s) < 0.01,
			func = function() A.ScaleMover(m, s) end,
		}
	end
	UI.Menu(m.handle, entries)
end

function A.ShowMover(m)
	local UI = A.UI
	local h = m.handle
	if m.enabled and not m.enabled() then
		if h then h:Hide() end
		return
	end
	if not h then
		h = CreateFrame("Button", nil, UIParent)
		h:SetFrameStrata("FULLSCREEN")
		h:SetMovable(true)
		h:SetClampedToScreen(true)
		h:RegisterForDrag("LeftButton")
		h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		h:EnableMouseWheel(true)
		h.bg = UI.Fill(h, { 1, 0.82, 0, 0.22 })
		h.edges = UI.Border(h, { 1, 0.82, 0, 0.9 })
		h.hl = UI.Fill(h, { 1, 1, 1, 0.12 }, "HIGHLIGHT")
		h.name = UI.Text(h, "GameFontNormalSmall", "CENTER", { 1, 1, 1 })
		h.name:SetPoint("CENTER", 0, 5)
		h.size = UI.Text(h, "GameFontDisableSmall", "CENTER", { 0.9, 0.9, 0.92 })
		h.size:SetPoint("TOP", h.name, "BOTTOM", 0, -1)
		h:SetScript("OnDragStart", function(self)
			if combat() then return end
			self:StartMoving()
		end)
		h:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			local x, y = self:GetCenter()
			if type(x) == "number" and type(y) == "number" and not combat() then place(m, x, y) end
			sync(m)
		end)
		h:SetScript("OnMouseWheel", function(_, delta)
			A.ScaleMover(m, (m.db.scale or 1) + delta * 0.05)
		end)
		h:SetScript("OnClick", function(_, button)
			if button == "RightButton" then menu(m) end
		end)
		m.handle = h
	end
	h.name:SetText(m.label)
	sync(m)
	h:Show()
end

local function buildGrid()
	local UI = A.UI
	grid = CreateFrame("Frame", nil, UIParent)
	grid:SetAllPoints(UIParent)
	grid:SetFrameStrata("BACKGROUND")
	local w, h = UIParent:GetWidth() or 1920, UIParent:GetHeight() or 1080
	local size = 64
	for x = 0, math.floor(w / 2 / size) do
		for _, sign in ipairs({ -1, 1 }) do
			if not (x == 0 and sign == 1) then
				local t = UI.Tex(grid, "BACKGROUND", x == 0 and { 1, 0.82, 0, 0.55 } or { 1, 1, 1, 0.1 })
				t:SetWidth(1)
				t:SetPoint("TOP", grid, "TOP", sign * x * size, 0)
				t:SetPoint("BOTTOM", grid, "BOTTOM", sign * x * size, 0)
			end
		end
	end
	for y = 0, math.floor(h / 2 / size) do
		for _, sign in ipairs({ -1, 1 }) do
			if not (y == 0 and sign == 1) then
				local t = UI.Tex(grid, "BACKGROUND", y == 0 and { 1, 0.82, 0, 0.55 } or { 1, 1, 1, 0.1 })
				t:SetHeight(1)
				t:SetPoint("LEFT", grid, "LEFT", 0, sign * y * size)
				t:SetPoint("RIGHT", grid, "RIGHT", 0, sign * y * size)
			end
		end
	end
end

local function buildBar()
	local UI = A.UI
	bar = CreateFrame("Frame", "ACoreLayoutBar", UIParent)
	bar:SetSize(560, 30)
	bar:SetPoint("TOP", UIParent, "TOP", 0, -40)
	bar:SetFrameStrata("FULLSCREEN_DIALOG")
	UI.Fill(bar, UI.colors.bg)
	UI.Border(bar)
	local text = UI.Text(bar, "GameFontHighlightSmall", "LEFT")
	text:SetPoint("LEFT", 10, 0)
	text:SetText("Drag to move, mouse wheel to resize, right-click for more")
	local done = UI.Button(bar, "Lock", function() A.LayoutMode(false) end)
	done:SetPoint("RIGHT", -6, 0)
	bar.snap = UI.Button(bar, "Snap", function()
		settings.snap = not settings.snap
		bar.snap:SetActive(settings.snap)
	end)
	bar.snap:SetPoint("RIGHT", done, "LEFT", -6, 0)
	bar.grid = UI.Button(bar, "Grid", function()
		settings.grid = not settings.grid
		bar.grid:SetActive(settings.grid)
		grid:SetShown(settings.grid)
	end)
	bar.grid:SetPoint("RIGHT", bar.snap, "LEFT", -6, 0)
end

function A.LayoutActive()
	return active
end

function A.LayoutMode(on)
	if on == nil then on = not active end
	if on and combat() then
		print("|cffffd100ACore|r: frames cannot be moved in combat")
		return false
	end
	active = on and true or false
	if active then
		if not grid then buildGrid() end
		if not bar then buildBar() end
		bar.snap:SetActive(settings.snap)
		bar.grid:SetActive(settings.grid)
		grid:SetShown(settings.grid)
		bar:Show()
		for _, m in ipairs(movers) do A.ShowMover(m) end
	else
		if grid then grid:Hide() end
		if bar then bar:Hide() end
		for _, m in ipairs(movers) do
			if m.handle then m.handle:Hide() end
		end
		if A.UI.CloseMenu then A.UI.CloseMenu() end
	end
	for _, fn in ipairs(A.layoutListeners or {}) do pcall(fn, active) end
	return true
end

function A.OnLayout(fn)
	A.layoutListeners = A.layoutListeners or {}
	A.layoutListeners[#A.layoutListeners + 1] = fn
end

local watcher = CreateFrame("Frame")
pcall(watcher.RegisterEvent, watcher, "PLAYER_REGEN_DISABLED")
watcher:SetScript("OnEvent", function()
	if active then
		A.LayoutMode(false)
		print("|cffffd100ACore|r: combat started, frames locked")
	end
end)
