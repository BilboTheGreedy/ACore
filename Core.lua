ACore = {}
local A = ACore

A.UI = {}
A.addons = {}

function A.Fill(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			A.Fill(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

function A.IsSecret(v)
	if issecretvalue then
		local ok, secret = pcall(issecretvalue, v)
		return ok and secret
	end
	return false
end

function A.After(delay, fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(delay, fn)
	else
		fn()
	end
end

function A.Money(copper)
	copper = math.floor(copper or 0)
	local g = math.floor(copper / 10000)
	local s = math.floor(copper / 100) % 100
	local c = copper % 100
	local out = {}
	if g > 0 then out[#out + 1] = "|cffffd100" .. g .. "g|r" end
	if s > 0 or g > 0 then out[#out + 1] = "|cffc7c7cf" .. s .. "s|r" end
	if c > 0 or #out == 0 then out[#out + 1] = "|cffeda55f" .. c .. "c|r" end
	return table.concat(out, " ")
end

function A.Short(n)
	if n >= 1000000 then return string.format("%.2fm", n / 1000000) end
	if n >= 10000 then return string.format("%.1fk", n / 1000) end
	return tostring(math.floor(n + 0.5))
end

function A.New(name, ns, opts)
	opts = opts or {}
	ns.name = name
	ns.UI = setmetatable({}, { __index = A.UI })
	ns.IsSecret = A.IsSecret
	ns.After = A.After
	ns.playerFaction = "Alliance"
	ns.playerClass = "WARRIOR"

	local listeners = {}
	function ns:Listen(msg, fn)
		listeners[msg] = listeners[msg] or {}
		table.insert(listeners[msg], fn)
	end

	function ns:Fire(msg, ...)
		local l = listeners[msg]
		if not l then return end
		for i = 1, #l do l[i](...) end
	end

	local frame = CreateFrame("Frame")
	local handlers = {}
	ns.events = frame
	function ns:On(event, fn)
		if not handlers[event] then
			handlers[event] = {}
			pcall(frame.RegisterEvent, frame, event)
		end
		table.insert(handlers[event], fn)
	end

	frame:SetScript("OnEvent", function(_, event, ...)
		local l = handlers[event]
		if not l then return end
		for i = 1, #l do l[i](...) end
	end)

	function ns.Print(msg)
		print("|cffffd100" .. name .. "|r: " .. tostring(msg))
	end

	local pending = {}
	function ns.Debounce(key, delay, fn)
		if pending[key] then
			pending[key] = fn
			return
		end
		pending[key] = fn
		A.After(delay, function()
			local f = pending[key]
			pending[key] = nil
			if f then f() end
		end)
	end

	ns:On("ADDON_LOADED", function(loaded)
		if loaded ~= name then return end
		if opts.db and opts.profile then
			local prof, sv = A.ProfileTable(opts.db, opts.shared)
			ns.db = A.Fill(prof, opts.defaults or {})
			ns.sv = sv
		elseif opts.db then
			_G[opts.db] = A.Fill(_G[opts.db] or {}, opts.defaults or {})
			ns.db = _G[opts.db]
		end
		if opts.char then
			_G[opts.char] = A.Fill(_G[opts.char] or {}, opts.charDefaults or {})
			ns.chardb = _G[opts.char]
		end
		ns:Fire("READY")
	end)

	ns:On("PLAYER_LOGIN", function()
		local faction = UnitFactionGroup and UnitFactionGroup("player")
		if faction == "Horde" or faction == "Alliance" then ns.playerFaction = faction end
		local _, class = UnitClass("player")
		if class then ns.playerClass = class end
		ns:Fire("LOGIN")
	end)

	return ns
end

local function copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = type(v) == "table" and copy(v) or v
	end
	return out
end
A.Copy = copy

function A.CharKey()
	local name = UnitName and UnitName("player") or "?"
	local realm = GetRealmName and GetRealmName() or "?"
	return tostring(realm) .. "-" .. tostring(name)
end

local function core()
	ACoreDB = ACoreDB or {}
	local db = ACoreDB
	db.chars = db.chars or {}
	db.names = db.names or { "Default" }
	db.copyFrom = db.copyFrom or {}
	db.stamps = db.stamps or {}
	return db
end

function A.Profile()
	local db = core()
	local name = db.chars[A.CharKey()] or "Default"
	for _, n in ipairs(db.names) do
		if n == name then return name end
	end
	return "Default"
end

function A.ProfileSync(profiles, stamps)
	local db = core()
	for pname, stamp in pairs(db.stamps) do
		if stamps[pname] ~= stamp then
			profiles[pname] = nil
			stamps[pname] = stamp
		end
	end
	local name = A.Profile()
	if type(profiles[name]) ~= "table" then
		local from = db.copyFrom[name]
		if from and type(profiles[from]) == "table" then
			profiles[name] = copy(profiles[from])
		else
			profiles[name] = {}
		end
	end
	return name
end

function A.ProfileTable(global, shared)
	shared = shared or {}
	local sv = _G[global]
	if type(sv) ~= "table" then sv = {} end
	if type(sv.profiles) ~= "table" then
		local old = sv
		sv = { profiles = { Default = old }, stamps = {} }
		for _, k in ipairs(shared) do
			sv[k] = old[k]
			old[k] = nil
		end
	end
	sv.stamps = sv.stamps or {}
	_G[global] = sv
	local name = A.ProfileSync(sv.profiles, sv.stamps)
	local prof = sv.profiles[name]
	if #shared > 0 then
		local set = {}
		for _, k in ipairs(shared) do
			set[k] = true
			for _, other in pairs(sv.profiles) do rawset(other, k, nil) end
		end
		setmetatable(prof, {
			__index = function(_, k)
				if set[k] then return sv[k] end
			end,
			__newindex = function(t, k, v)
				if set[k] then sv[k] = v else rawset(t, k, v) end
			end,
		})
	end
	return prof, sv
end

function A.Profiles()
	return core().names
end

local function reload()
	if ReloadUI then ReloadUI() end
end

function A.SetProfile(name)
	local db = core()
	local found = false
	for _, n in ipairs(db.names) do
		if n == name then found = true end
	end
	if not found then return false end
	db.chars[A.CharKey()] = name
	reload()
	return true
end

function A.NewProfile(name, from)
	name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then return false end
	local db = core()
	for _, n in ipairs(db.names) do
		if n == name then return false end
	end
	db.names[#db.names + 1] = name
	db.copyFrom[name] = from
	db.chars[A.CharKey()] = name
	reload()
	return true
end

function A.ResetProfile(name)
	local db = core()
	name = name or A.Profile()
	db.stamps[name] = (db.stamps[name] or 0) + 1
	db.copyFrom[name] = nil
	reload()
end

function A.DeleteProfile(name)
	local db = core()
	if name == "Default" then return false end
	for i, n in ipairs(db.names) do
		if n == name then
			table.remove(db.names, i)
			db.stamps[name] = (db.stamps[name] or 0) + 1
			db.copyFrom[name] = nil
			for key, used in pairs(db.chars) do
				if used == name then db.chars[key] = nil end
			end
			reload()
			return true
		end
	end
	return false
end

function A.Register(info)
	for i, a in ipairs(A.addons) do
		if a.name == info.name then
			A.addons[i] = info
			return
		end
	end
	A.addons[#A.addons + 1] = info
	table.sort(A.addons, function(x, y) return x.name < y.name end)
end
