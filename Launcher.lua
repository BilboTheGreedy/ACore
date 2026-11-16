local A = ACore
local UI = A.UI
local ns = A.New("ACore", {}, {
	db = "ACoreDB",
	defaults = { minimap = { show = true, angle = 215 } },
})

local button

local function place()
	local angle = math.rad(ns.db.minimap.angle or 215)
	local radius = (Minimap:GetWidth() / 2) + 6
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function A.OpenMenu(anchor)
	local entries = { { text = "A addons", title = true } }
	for _, a in ipairs(A.addons) do
		entries[#entries + 1] = { text = a.title or a.name, func = a.toggle }
	end
	if #A.addons == 0 then
		entries[#entries + 1] = { text = "Nothing installed", title = true }
	end
	entries[#entries + 1] = { text = "Hide minimap button", func = function() A.SetMinimap(false) end }
	UI.Menu(anchor, entries)
end

local function build()
	button = CreateFrame("Button", "ACoreMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER", 0, 0)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	button:SetScript("OnClick", function(self) A.OpenMenu(self) end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("A addons", 1, 0.82, 0)
		for _, a in ipairs(A.addons) do
			GameTooltip:AddDoubleLine(a.title or a.name, a.slash or "", 0.9, 0.9, 0.92, 0.58, 0.6, 0.65)
		end
		GameTooltip:AddLine("Click for the list, drag to move", 0.58, 0.6, 0.65)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			ns.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
			place()
		end)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
end

local function update()
	if not Minimap or not ns.db then return end
	if ns.db.minimap.show then
		if not button then build() end
		place()
		button:Show()
	elseif button then
		button:Hide()
	end
end

function A.SetMinimap(show)
	if not ns.db then return end
	ns.db.minimap.show = show and true or false
	update()
end

function A.MinimapShown()
	return ns.db and ns.db.minimap.show
end

ns:Listen("LOGIN", update)

function ACore_OnCompartmentClick(_, _, frame)
	A.OpenMenu(frame or UIParent)
end

SLASH_ACORE1 = "/acore"
SLASH_ACORE2 = "/a"
SlashCmdList["ACORE"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "minimap" then
		A.SetMinimap(not A.MinimapShown())
		return
	end
	for _, a in ipairs(A.addons) do
		if msg ~= "" and a.name:lower():find(msg, 1, true) and a.toggle then
			a.toggle()
			return
		end
	end
	for _, a in ipairs(A.addons) do
		print("|cffffd100" .. a.name .. "|r  " .. (a.slash or "") .. "  " .. (a.desc or ""))
	end
end
