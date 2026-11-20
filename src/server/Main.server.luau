-- Main.server.luau
-- "Brainrot Carnival" — whole server game.
-- Sections: (a) services + requires, (b) BrainrotRemotes, (c) world,
-- (d) DataStore save/load, (e) parade spawner, (f) buy, (g) deposit,
-- (h) sell, (i) steal, (j) shop / shield / lock / rebirth,
-- (k) income loop, (l) Ferris Wheel event, (m) leaderboard,
-- (n) every loop wrapped in pcall so a failure never kills a loop.
-- ENGLISH ONLY. No placeholder stubs: every remote handler fully works.
-- Shared contract (required by path, never redefined here):
--   ReplicatedStorage.Shared.BrainrotData / Economy / BoothLogic
--   Server CharacterModels (src/server/CharacterModels.luau, this repo)
--   WorldBuilder (ServerScriptService or ServerStorage, another worker)

-- (a) Services + requires -------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotData = require(Shared:WaitForChild("BrainrotData"))
local Economy = require(Shared:WaitForChild("Economy"))
local BoothLogic = require(Shared:WaitForChild("BoothLogic"))
local CharacterModels = require(script.Parent:WaitForChild("CharacterModels"))

-- WorldBuilder: another worker's module in ServerScriptService or
-- ServerStorage. Try both places, then src/server, before falling back.
local WorldBuilder = nil
do
	local found = ServerScriptService:FindFirstChild("WorldBuilder")
	if found == nil then
		found = ServerStorage:FindFirstChild("WorldBuilder")
	end
	if found == nil then
		found = script.Parent:FindFirstChild("WorldBuilder")
	end
	if found ~= nil then
		local ok, mod = pcall(require, found)
		if ok then
			WorldBuilder = mod
		else
			warn("[BrainrotCarnival] WorldBuilder require failed: " .. tostring(mod))
		end
	end
end

-- (b) BrainrotRemotes folder + all remotes -------------------------------
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "BrainrotRemotes"
remotesFolder.Parent = ReplicatedStorage

local function createRemoteEvent(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local BuyBrainrot = createRemoteEvent("BuyBrainrot")
local DepositBrainrot = createRemoteEvent("DepositBrainrot")
local SellBrainrot = createRemoteEvent("SellBrainrot")
local StealBrainrot = createRemoteEvent("StealBrainrot")
local BuyShopItem = createRemoteEvent("BuyShopItem")
local UseShield = createRemoteEvent("UseShield")
local ToggleLock = createRemoteEvent("ToggleLock")
local Rebirth = createRemoteEvent("Rebirth")
local ProfileUpdate = createRemoteEvent("ProfileUpdate")
local Notify = createRemoteEvent("Notify")
local EventWarning = createRemoteEvent("EventWarning")
local LeaderboardUpdate = createRemoteEvent("LeaderboardUpdate")

local GetProfile = Instance.new("RemoteFunction")
GetProfile.Name = "GetProfile"
GetProfile.Parent = remotesFolder

-- (c) Build world ---------------------------------------------------------
local world = nil
if WorldBuilder ~= nil and type(WorldBuilder.buildWorld) == "function" then
	local ok, result = pcall(function()
		return WorldBuilder.buildWorld()
	end)
	if ok and type(result) == "table" then
		world = result
	else
		warn("[BrainrotCarnival] WorldBuilder.buildWorld failed: " .. tostring(result))
	end
end

-- Fallback world (only if the other worker's module is absent or failed):
-- 8 booths in a row, a straight conveyor, spawn and ferris wheel spots.
-- Booths are assigned in order of player join, booth 1 to the first player.
-- The fallback MUST be a complete physical world, not data-only: a
-- data-only fallback has no baseplate and no SpawnLocation, so a player
-- whose spawn falls back to it spawns over the void and falls through
-- the world. Every part below is anchored and collidable, and no code
-- path may ever load a world without a baseplate under the spawn.
if world == nil then
	warn("[BrainrotCarnival] Using fallback world layout.")
	local fallbackModel = Instance.new("Model")
	fallbackModel.Name = "FallbackWorld"
	fallbackModel.Parent = Workspace

	local function fallbackPart(name, size, position, color)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Position = position
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = fallbackModel
		return part
	end

	-- Text on a sign board, legible from BOTH large faces. (Same rule as
	-- WorldBuilder.addTextLabel: a single SurfaceGui on Front is invisible
	-- from the other side, and the kiosk board is thin in Z, so its large
	-- faces are Front and Back. The label is drawn on both.)
	local function addFallbackLabel(part, text, textColor, bgColor)
		local size = part.Size
		local faces = {}
		if size.X <= size.Y and size.X <= size.Z then
			faces = { Enum.NormalId.Left, Enum.NormalId.Right }
		elseif size.Z <= size.X and size.Z <= size.Y then
			faces = { Enum.NormalId.Front, Enum.NormalId.Back }
		else
			faces = { Enum.NormalId.Top, Enum.NormalId.Bottom }
		end
		for i, face in ipairs(faces) do
			local gui = Instance.new("SurfaceGui")
			gui.Name = "LabelGui" .. tostring(i)
			gui.Face = face
			gui.AlwaysOnTop = false
			gui.Parent = part
			local label = Instance.new("TextLabel")
			label.Name = "Label"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundColor3 = bgColor
			label.BackgroundTransparency = 0
			label.Text = text
			label.TextColor3 = textColor
			label.TextScaled = true
			label.Font = Enum.Font.FredokaOne
			label.TextStrokeTransparency = 0.2
			label.Parent = gui
		end
	end

	-- Baseplate: 512 x 4 x 512, centred at (0, 0, 0), top at y = 2.
	fallbackPart("Baseplate", Vector3.new(512, 4, 512), Vector3.new(0, 0, 0), Color3.fromRGB(58, 214, 74))

	-- SpawnLocation: real pad centred at (0, 2.5, 30), top at y = 3,
	-- matching the fallback spawn position (0, 3, 30) below.
	-- WHITE on purpose (same reason as the primary world): the spawn pad
	-- must not look like a booth pad; booth #4 is the green one.
	local fallbackSpawn = Instance.new("SpawnLocation")
	fallbackSpawn.Name = "SpawnLocation"
	fallbackSpawn.Size = Vector3.new(10, 1, 10)
	fallbackSpawn.Position = Vector3.new(0, 2.5, 30)
	fallbackSpawn.Color = Color3.fromRGB(240, 240, 240)
	fallbackSpawn.Material = Enum.Material.SmoothPlastic
	fallbackSpawn.Anchored = true
	fallbackSpawn.CanCollide = true
	fallbackSpawn.Neutral = true
	fallbackSpawn.TopSurface = Enum.SurfaceType.Smooth
	fallbackSpawn.BottomSurface = Enum.SurfaceType.Smooth
	fallbackSpawn.Parent = fallbackModel

	-- 8 booth pads in a row at z = -20, tops at y = 3, pedestals at y = 4.
	-- Logical booth positions use y = 2 (the pad centre height, as in the
	-- primary world) so deposit pads, deposit distance and safe zones all
	-- read the same heights as the primary world.
	local boothPadColors = {
		Color3.fromRGB(255, 45, 45),
		Color3.fromRGB(255, 140, 0),
		Color3.fromRGB(255, 214, 0),
		Color3.fromRGB(0, 200, 83),
		Color3.fromRGB(0, 140, 255),
		Color3.fromRGB(160, 60, 255),
		Color3.fromRGB(255, 80, 200),
		Color3.fromRGB(0, 220, 230),
	}
	local booths = {}
	for i = 1, 8 do
		local boothX = (i - 4.5) * 16
		local boothPos = Vector3.new(boothX, 2, -20)
		-- Physical pad: 12 x 1 x 12, top at y = 3.
		fallbackPart("BoothPad" .. tostring(i), Vector3.new(12, 1, 12), Vector3.new(boothX, 2.5, -20), boothPadColors[i])
		local pedestals = {}
		for s = 1, 8 do
			local col = (s - 1) % 4
			local row = math.floor((s - 1) / 4)
			-- Pedestal logical positions at y = 4, as in the primary world.
			pedestals[s] = boothPos + Vector3.new((col - 1.5) * 4, 2, (row - 0.5) * 5)
		end
		booths[i] = {
			position = boothPos,
			pedestals = pedestals,
			signPosition = boothPos + Vector3.new(0, 6, 0),
			safeCenter = boothPos,
			safeRadius = 12,
		}
	end

	-- Conveyor belt at z = 10: top at y = 3, waypoints at y = 3.5.
	fallbackPart("ConveyorBelt", Vector3.new(80, 1, 6), Vector3.new(0, 2.5, 10), Color3.fromRGB(64, 64, 72))

	-- Small shop kiosk at z = 55: counter, two posts, roof and sign board.
	fallbackPart("ShopKioskCounter", Vector3.new(8, 2, 3), Vector3.new(0, 3, 55), Color3.fromRGB(255, 214, 0))
	fallbackPart("ShopKioskPost", Vector3.new(0.8, 5, 0.8), Vector3.new(-3.5, 4.5, 55), Color3.fromRGB(120, 72, 20))
	fallbackPart("ShopKioskPost", Vector3.new(0.8, 5, 0.8), Vector3.new(3.5, 4.5, 55), Color3.fromRGB(120, 72, 20))
	fallbackPart("ShopKioskRoof", Vector3.new(10, 0.6, 5), Vector3.new(0, 7.3, 55), Color3.fromRGB(255, 45, 45))
	local kioskSign = fallbackPart("ShopKioskSign", Vector3.new(8, 2, 0.6), Vector3.new(0, 6, 55), Color3.fromRGB(255, 255, 255))
	addFallbackLabel(kioskSign, "SHOP", Color3.fromRGB(40, 40, 40), Color3.fromRGB(255, 255, 255))

	-- Boundary fence (same rectangle as the primary world: x in [-70, 70],
	-- z in [-115, 130]): bright red/white panels 14 high so the empty grass
	-- outside cannot be seen from inside, plus an invisible 20-high barrier
	-- just outside it so no player can walk out. No booth, conveyor, shop
	-- or spawn position is moved.
	do
		local fenceX0, fenceX1 = -70, 70
		local fenceZ0, fenceZ1 = -115, 130
		local panelColors = { Color3.fromRGB(255, 45, 45), Color3.fromRGB(255, 255, 255) }
		local function fenceRun(x0, z0, x1, z1)
			local dx, dz = x1 - x0, z1 - z0
			local length = math.max(math.abs(dx), math.abs(dz))
			local count = math.ceil(length / 10)
			local step = length / count
			for i = 1, count do
				local t = (i - 0.5) / count
				local size
				if math.abs(dx) >= math.abs(dz) then
					size = Vector3.new(step, 14, 1)
				else
					size = Vector3.new(1, 14, step)
				end
				fallbackPart("FencePanel", size, Vector3.new(x0 + dx * t, 9, z0 + dz * t), panelColors[((i - 1) % 2) + 1])
			end
		end
		fenceRun(fenceX0, fenceZ0, fenceX1, fenceZ0)
		fenceRun(fenceX0, fenceZ1, fenceX1, fenceZ1)
		fenceRun(fenceX0, fenceZ0, fenceX0, fenceZ1)
		fenceRun(fenceX1, fenceZ0, fenceX1, fenceZ1)
		for _, cx in ipairs({ fenceX0, fenceX1 }) do
			for _, cz in ipairs({ fenceZ0, fenceZ1 }) do
				fallbackPart("FencePost", Vector3.new(2, 16, 2), Vector3.new(cx, 10, cz), Color3.fromRGB(255, 214, 0))
			end
		end
		local function invisibleWall(name, size, position)
			local wall = Instance.new("Part")
			wall.Name = name
			wall.Size = size
			wall.Position = position
			wall.Color = Color3.fromRGB(255, 255, 255)
			wall.Transparency = 1
			wall.Material = Enum.Material.SmoothPlastic
			wall.Anchored = true
			wall.CanCollide = true
			wall.CanTouch = false
			wall.CanQuery = false
			wall.TopSurface = Enum.SurfaceType.Smooth
			wall.BottomSurface = Enum.SurfaceType.Smooth
			wall.Parent = fallbackModel
		end
		invisibleWall("FenceBarrierNorth", Vector3.new(144, 20, 1), Vector3.new(0, 12, fenceZ0 - 1.5))
		invisibleWall("FenceBarrierSouth", Vector3.new(144, 20, 1), Vector3.new(0, 12, fenceZ1 + 1.5))
		invisibleWall("FenceBarrierWest", Vector3.new(1, 20, 249), Vector3.new(fenceX0 - 1.5, 12, 7.5))
		invisibleWall("FenceBarrierEast", Vector3.new(1, 20, 249), Vector3.new(fenceX1 + 1.5, 12, 7.5))
	end

	world = {
		booths = booths,
		conveyor = {
			start = Vector3.new(-40, 3.5, 10),
			finish = Vector3.new(40, 3.5, 10),
			waypoints = {
				Vector3.new(-40, 3.5, 10),
				Vector3.new(0, 3.5, 10),
				Vector3.new(40, 3.5, 10),
			},
		},
		spawnPosition = Vector3.new(0, 3, 30),
		ferrisWheelPosition = Vector3.new(0, 10, -40),
	}
end

-- Pedestal markers: one glowing ring per pedestal, placed once at startup.
do
	local folder = Instance.new("Folder")
	folder.Name = "PedestalMarkers"
	folder.Parent = Workspace
	for _, booth in ipairs(world.booths) do
		for _, pedestalPos in ipairs(booth.pedestals) do
			local marker = CharacterModels.buildPedestalMarker(Color3.fromRGB(255, 215, 0))
			marker.CFrame = CFrame.new(pedestalPos) * CFrame.Angles(0, 0, math.pi / 2)
			marker.Parent = folder
		end
	end
end

-- Deposit prompts: one per booth, on an invisible pad at the booth centre.
-- Coordinator fix 2/3: ActionText "Deposit", ObjectText "Deposit Brainrot".
-- This is the PRIMARY deposit path (server-side ProximityPrompt.Triggered);
-- the client does not fire DepositBrainrot. The trigger calls the global
-- depositCarriedBrainrot(player, boothIndex) defined in section (g), which
-- validates that the booth is the trigger player's OWN booth and that they
-- are within 16 studs of it. The closure only runs at trigger time, after
-- the whole script has loaded, so the later global definition is safe.
-- Radius 16 (was 12): the booth pad is 12x12, so a player standing anywhere
-- on their own pad is always inside the prompt radius.
do
	local folder = Instance.new("Folder")
	folder.Name = "DepositPads"
	folder.Parent = Workspace
	for boothIndex, booth in ipairs(world.booths) do
		local pad = Instance.new("Part")
		pad.Name = "DepositPad"
		pad.Size = Vector3.new(6, 1, 6)
		pad.CFrame = CFrame.new(booth.position + Vector3.new(0, 1, 0))
		pad.Anchored = true
		pad.CanCollide = false
		pad.CanTouch = false
		pad.CanQuery = true
		pad.Transparency = 1
		pad.Parent = folder
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Deposit"
		prompt.ObjectText = "Deposit Brainrot"
		prompt.HoldDuration = 0
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad
		local thisBoothIndex = boothIndex
		prompt.Triggered:Connect(function(player)
			local ok, err = pcall(depositCarriedBrainrot, player, thisBoothIndex)
			if not ok then
				warn("[BrainrotCarnival] Deposit prompt handler failed: " .. tostring(err))
			end
		end)
	end
end

local paradeFolder = Instance.new("Folder")
paradeFolder.Name = "Parade"
paradeFolder.Parent = Workspace

-- (d) DataStore + server state --------------------------------------------
local dataStore = nil
do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("BrainrotCarnivalV1")
	end)
	if ok then
		dataStore = store
	else
		warn("[BrainrotCarnival] DataStore unavailable: " .. tostring(store))
	end
end

local function dataKey(player)
	return "Player_" .. tostring(player.UserId)
end

local profiles = {} -- [Player] = profile table
local boothAssignment = {} -- [Player] = booth index (1-based)
local boothTaken = {} -- [boothIndex] = Player
local carrying = {} -- [Player] = {charId, mutation, model, weld, slotIndex}
local boothBeacons = {} -- [Player] = beacon Model marking their own booth
local pedestalModels = {} -- [Player] = {[slotIndex] = {model, baseCFrame, charId, mutation}}
local stunnedUntil = {} -- [Player] = os.clock() timestamp
local parade = {} -- array of {id, charId, mutation, cost, model, prompt, waypointIndex}
local nextParadeId = 1
local ferrisActive = false

-- Profile-shape helpers. The Economy profile is treated as a black box:
-- we only read/write through these helpers and the Economy functions, and
-- tolerate the brainrot list living under .brainrots / .slots / .booth.
local function getBrainrotList(profile)
	if profile == nil then
		return {}
	end
	if type(profile.brainrots) == "table" then
		return profile.brainrots
	end
	if type(profile.slots) == "table" then
		return profile.slots
	end
	if type(profile.booth) == "table" then
		return profile.booth
	end
	return {}
end

local function getSlotEntry(profile, slotIndex)
	local list = getBrainrotList(profile)
	return list[slotIndex]
end

local function getEntryCharId(entry)
	if entry == nil then
		return nil
	end
	if type(entry) == "string" then
		return entry
	end
	if type(entry) == "table" then
		return entry.charId or entry.id or entry.characterId or entry.CharacterId
	end
	return nil
end

local function getEntryMutation(entry)
	if type(entry) == "table" then
		return entry.mutation or entry.Mutation or "None"
	end
	return "None"
end

local function getMoney(profile)
	if profile == nil then
		return 0
	end
	return profile.money or profile.Money or profile.cash or profile.Cash or 0
end

local function getTotalEarned(profile)
	if profile == nil then
		return 0
	end
	return profile.totalEarned or profile.TotalEarned or profile.lifetimeEarned or 0
end

local function getShopLevel(profile, itemId)
	if profile == nil then
		return 0
	end
	local tables = { profile.shopLevels, profile.shop, profile.upgrades, profile.shopItems }
	for _, tbl in ipairs(tables) do
		if type(tbl) == "table" then
			local v = tbl[itemId]
			if type(v) == "number" then
				return v
			elseif type(v) == "table" and type(v.level) == "number" then
				return v.level
			end
		end
	end
	return 0
end

local function getWalkSpeed(profile)
	local level = getShopLevel(profile, "speed")
	if level == 0 then
		level = getShopLevel(profile, "walkspeed")
	end
	if level == 0 then
		level = getShopLevel(profile, "walk_speed")
	end
	return 16 * (1 + 0.15 * level)
end

local function findFreePedestalSlot(player)
	local placed = pedestalModels[player]
	for slotIndex = 1, 8 do
		if placed == nil or placed[slotIndex] == nil then
			return slotIndex
		end
	end
	return nil
end

local function findProfileSlotForCharacter(profile, charId, mutation, excludePlayer)
	-- Find a profile slot holding this character whose pedestal is not yet
	-- placed (and which is not already being carried by that player).
	local list = getBrainrotList(profile)
	for slotIndex = 1, 8 do
		local entry = list[slotIndex]
		if entry ~= nil and getEntryCharId(entry) == charId then
			if mutation == nil or getEntryMutation(entry) == mutation or getEntryMutation(entry) == "None" then
				return slotIndex
			end
		end
	end
	return nil
end

local function setModelAnchored(model, anchored)
	if model == nil then
		return
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
			descendant.CanCollide = false
		end
	end
end

local function attachCarriedModel(player, model)
	local character = player.Character
	if character == nil then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp == nil then
		return nil
	end
	local primary = model.PrimaryPart
	if primary == nil then
		return nil
	end
	setModelAnchored(model, false)
	model.Parent = character
	primary.CFrame = hrp.CFrame * CFrame.new(0, 0.2, -2.2)
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = hrp
	weld.Part1 = primary
	weld.C0 = CFrame.new(0, 0.2, -2.2)
	weld.Parent = primary
	return weld
end

local function destroyCarrying(player)
	local entry = carrying[player]
	if entry ~= nil then
		if entry.weld ~= nil then
			pcall(function()
				entry.weld:Destroy()
			end)
		end
		if entry.model ~= nil then
			pcall(function()
				entry.model:Destroy()
			end)
		end
		carrying[player] = nil
	end
end

local function clearPedestalModels(player)
	local placed = pedestalModels[player]
	if placed ~= nil then
		for _, item in pairs(placed) do
			if item ~= nil and item.model ~= nil then
				pcall(function()
					item.model:Destroy()
				end)
			end
		end
	end
	pedestalModels[player] = {}
end

local function sendProfile(player)
	local profile = profiles[player]
	if profile ~= nil then
		pcall(function()
			-- Coordinator fix 1: the client HUD reads profile.incomePerSec
			-- (fallback profile.income). Send a shallow copy with both set
			-- from Economy.totalIncomePerSecond; the stored profile itself
			-- is not mutated and Economy is not changed.
			local payload = {}
			for key, value in pairs(profile) do
				payload[key] = value
			end
			local income = 0
			pcall(function()
				local computed = Economy.totalIncomePerSecond(profile)
				if type(computed) == "number" then
					income = computed
				end
			end)
			payload.incomePerSec = income
			payload.income = income
			ProfileUpdate:FireClient(player, payload)
		end)
	end
end

local function notifyPlayer(player, text, color)
	pcall(function()
		Notify:FireClient(player, { text = text, color = color })
	end)
end

local function getBooth(player)
	local index = boothAssignment[player]
	if index == nil then
		return nil, nil
	end
	return world.booths[index], index
end

local function saveProfile(player)
	local profile = profiles[player]
	if profile == nil or dataStore == nil then
		return
	end
	local ok, err = pcall(function()
		local data = profile
		if type(Economy.serialize) == "function" then
			local serialized = Economy.serialize(profile)
			if serialized ~= nil then
				data = serialized
			end
		end
		dataStore:SetAsync(dataKey(player), data)
	end)
	if not ok then
		warn("[BrainrotCarnival] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

local function loadProfile(player)
	local profile = nil
	if dataStore ~= nil then
		local ok, data = pcall(function()
			return dataStore:GetAsync(dataKey(player))
		end)
		if ok and data ~= nil then
			local ok2, result = pcall(function()
				if type(Economy.deserialize) == "function" then
					return Economy.deserialize(data)
				end
				return data
			end)
			if ok2 and type(result) == "table" then
				profile = result
			else
				warn("[BrainrotCarnival] Deserialize failed for " .. player.Name .. ", using a fresh profile.")
			end
		elseif not ok then
			warn("[BrainrotCarnival] Load failed for " .. player.Name .. ": " .. tostring(data))
		end
	end
	if profile == nil then
		profile = Economy.newProfile()
	end
	profiles[player] = profile
	return profile
end

local function assignBooth(player)
	for i = 1, #world.booths do
		if boothTaken[i] == nil then
			boothTaken[i] = player
			boothAssignment[player] = i
			return i
		end
	end
	return nil
end

-- "YOUR BOOTH" beacon: a tall Neon beam + floating label above the player's
-- OWN booth, so a carrying player can always find where to deposit.
-- ROOT CAUSE of the reported deposit failure (Studio, 2026-11-20): the
-- player stood on the GREEN spawn pad in front of the entrance sign and
-- pressed E there. That pad is not a booth — the solo player's booth is
-- #1 (RED, at x=-22, z=-80), ~27 studs from spawn, and the Deposit prompt
-- only exists at the booth itself. Nothing in the world pointed at the
-- booth, so the player never reached a prompt at all. The beam is visible
-- from spawn and the label names the booth number.
local function getBoothPadColor(boothIndex)
	local ok, color = pcall(function()
		local worldModel = Workspace:FindFirstChild("BrainrotCarnivalWorld")
		if worldModel ~= nil then
			local boothModel = worldModel:FindFirstChild("Booth" .. tostring(boothIndex))
			if boothModel ~= nil then
				local pad = boothModel:FindFirstChild("BoothPad")
				if pad ~= nil then
					return pad.Color
				end
			end
		end
		local fallbackModel = Workspace:FindFirstChild("FallbackWorld")
		if fallbackModel ~= nil then
			local pad = fallbackModel:FindFirstChild("BoothPad" .. tostring(boothIndex))
			if pad ~= nil then
				return pad.Color
			end
		end
		return nil
	end)
	if ok and color ~= nil then
		return color
	end
	return Color3.fromRGB(255, 214, 0)
end

local function createBoothBeacon(player, boothIndex)
	local booth = world.booths[boothIndex]
	if booth == nil then
		return
	end
	pcall(function()
		destroyBoothBeacon(player)
	end)
	local beacon = Instance.new("Model")
	beacon.Name = "YourBoothBeacon"
	local beam = Instance.new("Part")
	beam.Name = "BeaconBeam"
	beam.Size = Vector3.new(1.5, 50, 1.5)
	beam.Position = booth.position + Vector3.new(0, 25, 0)
	beam.Color = getBoothPadColor(boothIndex)
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.55
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.TopSurface = Enum.SurfaceType.Smooth
	beam.BottomSurface = Enum.SurfaceType.Smooth
	beam.Parent = beacon
	local gui = Instance.new("BillboardGui")
	gui.Name = "YourBoothLabel"
	gui.Size = UDim2.fromOffset(220, 60)
	gui.ExtentsOffsetWorldSpace = Vector3.new(0, -13, 0)
	gui.AlwaysOnTop = true
	gui.Parent = beam
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "YOUR BOOTH #" .. tostring(boothIndex)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0
	label.Parent = gui
	beacon.Parent = Workspace
	boothBeacons[player] = beacon
end

function destroyBoothBeacon(player)
	local beacon = boothBeacons[player]
	if beacon ~= nil then
		pcall(function()
			beacon:Destroy()
		end)
	end
	boothBeacons[player] = nil
end

local function onPlayerAdded(player)
	local ok, err = pcall(function()
		loadProfile(player)
		local boothIndex = assignBooth(player)
		pedestalModels[player] = {}
		if boothIndex ~= nil then
			createBoothBeacon(player, boothIndex)
			notifyPlayer(player, "Welcome to Brainrot Carnival! Your booth is #" .. tostring(boothIndex) .. ". Buy a brainrot from the conveyor (E), then press E at your booth to deposit it.", Color3.fromRGB(80, 220, 120))
		else
			notifyPlayer(player, "Welcome to Brainrot Carnival! All booths are taken right now, but you can still watch the parade.", Color3.fromRGB(255, 200, 60))
		end
		sendProfile(player)
		-- Restore walk speed (shop speed upgrade) when the character spawns.
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 5)
			if humanoid ~= nil then
				local profile = profiles[player]
				if profile ~= nil then
					humanoid.WalkSpeed = getWalkSpeed(profile)
				end
			end
		end)
	end)
	if not ok then
		warn("[BrainrotCarnival] PlayerAdded failed for " .. player.Name .. ": " .. tostring(err))
	end
end

local function onPlayerRemoving(player)
	pcall(function()
		saveProfile(player)
	end)
	pcall(function()
		destroyCarrying(player)
		destroyBoothBeacon(player)
		clearPedestalModels(player)
		local boothIndex = boothAssignment[player]
		if boothIndex ~= nil and boothTaken[boothIndex] == player then
			boothTaken[boothIndex] = nil
		end
		boothAssignment[player] = nil
		profiles[player] = nil
		pedestalModels[player] = nil
		stunnedUntil[player] = nil
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Autosave every 60 s.
task.spawn(function()
	while true do
		task.wait(60)
		local ok, err = pcall(function()
			for _, player in ipairs(Players:GetPlayers()) do
				saveProfile(player)
			end
		end)
		if not ok then
			warn("[BrainrotCarnival] Autosave failed: " .. tostring(err))
		end
	end
end)

-- (e) Parade spawner -------------------------------------------------------
local function collectCharactersByRarity()
	local byRarity = {}
	local all = {}
	local chars = BrainrotData.CHARACTERS
	if type(chars) == "table" then
		for key, value in pairs(chars) do
			local entry = value
			local id = nil
			local rarity = nil
			if type(value) == "table" then
				id = value.id or value.Id
				if id == nil and type(key) == "string" then
					id = key
				end
				rarity = value.rarity or value.Rarity
			elseif type(value) == "string" then
				id = value
			end
			if id ~= nil then
				table.insert(all, id)
				if rarity ~= nil then
					byRarity[rarity] = byRarity[rarity] or {}
					table.insert(byRarity[rarity], id)
				end
			end
		end
	end
	return byRarity, all
end

local function pickWeightedCharacter()
	local byRarity, all = collectCharactersByRarity()
	if #all == 0 then
		return nil
	end
	-- Common 45%, Rare 25%, Epic 15%, Legendary 8%, Mythic 4%, God 2%, Secret 1%.
	local roll = math.random(1, 100)
	local rarity = "Common"
	if roll <= 45 then
		rarity = "Common"
	elseif roll <= 70 then
		rarity = "Rare"
	elseif roll <= 85 then
		rarity = "Epic"
	elseif roll <= 93 then
		rarity = "Legendary"
	elseif roll <= 97 then
		rarity = "Mythic"
	elseif roll <= 99 then
		rarity = "God"
	else
		rarity = "Secret"
	end
	local pool = byRarity[rarity]
	if pool ~= nil and #pool > 0 then
		return pool[math.random(1, #pool)]
	end
	return all[math.random(1, #all)]
end

local function findParadeEntry(paradeId)
	for index, entry in ipairs(parade) do
		if entry.id == paradeId then
			return entry, index
		end
	end
	return nil, nil
end

local function removeParadeEntry(entry, index)
	if index ~= nil then
		table.remove(parade, index)
	else
		for i, item in ipairs(parade) do
			if item == entry then
				table.remove(parade, i)
				break
			end
		end
	end
	if entry ~= nil and entry.model ~= nil then
		pcall(function()
			entry.model:Destroy()
		end)
	end
end

local function spawnParadeBrainrot(charId, mutation, startPosition)
	local chosenId = charId
	if chosenId == nil then
		chosenId = pickWeightedCharacter()
	end
	if chosenId == nil then
		return nil
	end
	local chosenMutation = mutation
	if chosenMutation == nil then
		if type(BrainrotData.rollMutation) == "function" then
			local ok, rolled = pcall(function()
				return BrainrotData.rollMutation()
			end)
			if ok then
				chosenMutation = rolled
			else
				chosenMutation = "None"
			end
		else
			chosenMutation = "None"
		end
	end

	local charName = tostring(chosenId)
	local cost = 0
	do
		local ok, result = pcall(function()
			return BrainrotData.getCharacter(chosenId)
		end)
		if ok and type(result) == "table" then
			charName = result.name or result.Name or charName
		end
		local ok2, costResult = pcall(function()
			return BrainrotData.costOf(chosenId)
		end)
		if ok2 and type(costResult) == "number" then
			cost = costResult
		end
	end

	local model = nil
	do
		local ok, built = pcall(function()
			-- showPrice true: the parade tag shows the buy price.
			return CharacterModels.buildCharacterModel(chosenId, chosenMutation, true)
		end)
		if ok and built ~= nil then
			model = built
		else
			warn("[BrainrotCarnival] buildCharacterModel failed: " .. tostring(built))
			return nil
		end
	end

	local startPos = startPosition or world.conveyor.start
	setModelAnchored(model, true)
	model.Parent = paradeFolder
	if model.PrimaryPart ~= nil then
		model.PrimaryPart.CFrame = CFrame.new(startPos)
	end

	local prompt = Instance.new("ProximityPrompt")
	-- Coordinator fix 2: ActionText EXACTLY "Buy", ObjectText = display name.
	-- (Cost is shown by the client HUD from BrainrotData.costOf, not here.)
	prompt.ActionText = "Buy"
	prompt.ObjectText = charName
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart

	local entry = {
		id = nextParadeId,
		charId = chosenId,
		mutation = chosenMutation,
		cost = cost,
		model = model,
		prompt = prompt,
		waypointIndex = 1,
	}
	nextParadeId = nextParadeId + 1
	table.insert(parade, entry)

	-- Coordinator fix 3: prompt-triggered is the PRIMARY (only) buy path.
	-- ProximityPrompt.Triggered already runs on the server, so call the
	-- buy core directly. Exactly ONE connection: the old code had two
	-- (one bogus server-side FireServer call, one real buy) which could
	-- double-fire. The BuyBrainrot remote is still created (section b)
	-- but no longer has a server handler.
	prompt.Triggered:Connect(function(player)
		local ok, err = pcall(buyParadeBrainrot, player, entry.id)
		if not ok then
			warn("[BrainrotCarnival] Buy prompt handler failed: " .. tostring(err))
		end
	end)

	return entry
end

-- Forward declaration: the buy core is used by both the prompt and the remote.
function buyParadeBrainrot(player, paradeId)
	local profile = profiles[player]
	if profile == nil then
		return
	end
	if carrying[player] ~= nil then
		notifyPlayer(player, "You are already carrying a brainrot. Deposit it at your booth first.", Color3.fromRGB(255, 200, 60))
		return
	end
	local entry, index = findParadeEntry(paradeId)
	if entry == nil then
		notifyPlayer(player, "That brainrot already left the parade.", Color3.fromRGB(255, 120, 120))
		return
	end
	if player.Character == nil or player.Character:FindFirstChild("HumanoidRootPart") == nil then
		notifyPlayer(player, "Wait until your character loads, then try again.", Color3.fromRGB(255, 200, 60))
		return
	end

	local ok, result, slotIndex = pcall(function()
		return Economy.buyBrainrot(profile, entry.charId, entry.mutation)
	end)
	if not ok then
		warn("[BrainrotCarnival] buyBrainrot error: " .. tostring(result))
		notifyPlayer(player, "Could not buy that brainrot. Try again.", Color3.fromRGB(255, 120, 120))
		return
	end
	-- Economy.buyBrainrot returns true/false, optionally with a slot index.
	local bought = result
	if bought == nil then
		bought = true
	end
	if bought == false then
		notifyPlayer(player, "Not enough money, or your booth is full.", Color3.fromRGB(255, 120, 120))
		return
	end
	local slot = slotIndex
	if type(slot) ~= "number" then
		slot = findProfileSlotForCharacter(profile, entry.charId, entry.mutation, player)
	end
	if type(slot) ~= "number" then
		slot = findFreePedestalSlot(player)
	end

	-- Remove from the belt first, then hand the same model to the player.
	local model = entry.model
	removeParadeEntry(entry, index)
	-- removeParadeEntry destroys the model; rebuild a fresh one to carry.
	local carriedModel = nil
	do
		local ok2, built = pcall(function()
			return CharacterModels.buildCharacterModel(entry.charId, entry.mutation)
		end)
		if ok2 and built ~= nil then
			carriedModel = built
		else
			warn("[BrainrotCarnival] Carry model build failed: " .. tostring(built))
			return
		end
	end
	-- The old belt model was destroyed by removeParadeEntry; the carried
	-- model above is the one the player holds. (model variable is now dead.)
	model = carriedModel
	local weld = attachCarriedModel(player, carriedModel)
	if weld == nil then
		pcall(function()
			carriedModel:Destroy()
		end)
		notifyPlayer(player, "Could not pick up the brainrot. Try again.", Color3.fromRGB(255, 120, 120))
		return
	end
	carrying[player] = {
		charId = entry.charId,
		mutation = entry.mutation,
		model = carriedModel,
		weld = weld,
		slotIndex = slot,
	}
	sendProfile(player)
	local charName = tostring(entry.charId)
	do
		local ok3, ch = pcall(function()
			return BrainrotData.getCharacter(entry.charId)
		end)
		if ok3 and type(ch) == "table" then
			charName = ch.name or ch.Name or charName
		end
	end
	local _, ownBoothIndex = getBooth(player)
	local boothText = "your booth"
	if ownBoothIndex ~= nil then
		boothText = "your booth #" .. tostring(ownBoothIndex)
	end
	notifyPlayer(player, "Bought " .. charName .. " for $" .. tostring(entry.cost) .. "! Carry it to " .. boothText .. " (follow the light beam) and press E to deposit it.", Color3.fromRGB(80, 220, 120))
end

-- Parade spawner: every 6 s, one brainrot, max 10 on the belt.
task.spawn(function()
	while true do
		task.wait(6)
		local ok, err = pcall(function()
			if #parade < 10 then
				spawnParadeBrainrot(nil, nil, nil)
			end
		end)
		if not ok then
			warn("[BrainrotCarnival] Parade spawner failed: " .. tostring(err))
		end
	end
end)

-- Parade movement + pedestal bobbing: one loop, 10 ticks per second.
task.spawn(function()
	local speed = 4 -- studs per second
	while true do
		task.wait(0.1)
		local ok, err = pcall(function()
			-- Move the parade along the conveyor waypoints.
			local waypoints = world.conveyor.waypoints
			local toRemove = {}
			for _, entry in ipairs(parade) do
				if entry.model == nil or entry.model.Parent == nil then
					table.insert(toRemove, entry)
				else
					local target = waypoints[entry.waypointIndex]
					if target == nil then
						table.insert(toRemove, entry)
					else
						local primary = entry.model.PrimaryPart
						if primary ~= nil then
							local current = primary.Position
							local delta = target - current
							local distance = delta.Magnitude
							if distance < 0.5 then
								if entry.waypointIndex >= #waypoints then
									table.insert(toRemove, entry)
								else
									entry.waypointIndex = entry.waypointIndex + 1
								end
							else
								local step = math.min(distance, speed * 0.1)
								local newPos = current + (delta / distance) * step
								entry.model:PivotTo(CFrame.new(newPos))
							end
						end
					end
				end
			end
			for _, entry in ipairs(toRemove) do
				removeParadeEntry(entry, nil)
			end
			-- Gentle bobbing for deposited brainrots.
			local t = os.clock()
			for _, placed in pairs(pedestalModels) do
				for slotIndex, item in pairs(placed) do
					if item ~= nil and item.model ~= nil and item.model.Parent ~= nil and item.baseCFrame ~= nil then
						local bob = math.sin(t * 2 + slotIndex) * 0.15
						item.model:PivotTo(item.baseCFrame * CFrame.new(0, bob, 0))
					end
				end
			end
		end)
		if not ok then
			warn("[BrainrotCarnival] Parade/bobbing loop failed: " .. tostring(err))
		end
	end
end)

-- (f) Buy: NO BuyBrainrot remote handler (coordinator fix 3). The buy core
-- buyParadeBrainrot is invoked ONLY from the parade ProximityPrompt.Triggered
-- connection in spawnParadeBrainrot. The BuyBrainrot RemoteEvent is still
-- created in section (b) because the client references it.

-- (g) Deposit: place the carried brainrot on a free pedestal at your booth.
-- Coordinator fix 3: PRIMARY path is the booth "Deposit" ProximityPrompt
-- (created in section c); NO DepositBrainrot remote handler. The prompt
-- passes its own booth index, which must match the player's assigned booth.
-- The carried brainrot is deposited at the nearest free pedestal of THEIR
-- OWN booth (its assigned slot if free, else the first free pedestal).
-- Also wires the Sell/Steal prompts onto the deposited model (fix 2).
function depositCarriedBrainrot(player, boothIndexFromPrompt)
	local ok, err = pcall(function()
		local profile = profiles[player]
		if profile == nil then
			return
		end
		local carried = carrying[player]
		if carried == nil then
			notifyPlayer(player, "You are not carrying a brainrot.", Color3.fromRGB(255, 200, 60))
			return
		end
		local booth, boothIndex = getBooth(player)
		if booth == nil then
			notifyPlayer(player, "You do not have a booth yet.", Color3.fromRGB(255, 120, 120))
			return
		end
		if boothIndexFromPrompt ~= nil and boothIndexFromPrompt ~= boothIndex then
			notifyPlayer(player, "That is not your booth. Deposit at your own booth (booth #" .. tostring(boothIndex) .. ").", Color3.fromRGB(255, 120, 120))
			return
		end
		local character = player.Character
		local hrp = nil
		if character ~= nil then
			hrp = character:FindFirstChild("HumanoidRootPart")
		end
		if hrp == nil then
			return
		end
		local distance = (hrp.Position - booth.position).Magnitude
		if distance > 16 then
			notifyPlayer(player, "Go to your own booth (booth #" .. tostring(boothIndex) .. ") to deposit this brainrot.", Color3.fromRGB(255, 200, 60))
			return
		end
		local slotIndex = carried.slotIndex
		local placed = pedestalModels[player]
		if placed == nil then
			placed = {}
			pedestalModels[player] = placed
		end
		if type(slotIndex) ~= "number" or placed[slotIndex] ~= nil then
			slotIndex = findFreePedestalSlot(player)
		end
		if slotIndex == nil then
			notifyPlayer(player, "Your booth is full. Sell a brainrot first.", Color3.fromRGB(255, 120, 120))
			return
		end
		local pedestalPos = booth.pedestals[slotIndex]
		if pedestalPos == nil then
			notifyPlayer(player, "No pedestal found for that slot.", Color3.fromRGB(255, 120, 120))
			return
		end
		-- Detach from the player and anchor it on the pedestal.
		if carried.weld ~= nil then
			pcall(function()
				carried.weld:Destroy()
			end)
		end
		local model = carried.model
		setModelAnchored(model, true)
		model.Parent = Workspace
		local baseCFrame = CFrame.new(pedestalPos + Vector3.new(0, 1, 0))
		if model.PrimaryPart ~= nil then
			model.PrimaryPart.CFrame = baseCFrame
		else
			model:PivotTo(baseCFrame)
		end
		placed[slotIndex] = {
			model = model,
			baseCFrame = baseCFrame,
			charId = carried.charId,
			mutation = carried.mutation,
		}
		-- Coordinator fix 2: Sell + Steal prompts on the deposited model.
		-- ProximityPrompt properties are shared, so BOTH prompts live on
		-- the model: ActionText "Sell" (ObjectText = brainrot name) and
		-- ActionText "Steal" (ObjectText = brainrot name). Each handler
		-- enforces ownership: Sell only works for the booth owner, Steal
		-- only for a rival (and only if BoothLogic.canSteal allows it).
		-- The prompts are children of the model, so selling / stealing /
		-- rebirth destroys them together with the model.
		if model.PrimaryPart ~= nil then
			local depositedName = tostring(carried.charId)
			do
				local okName, ch = pcall(function()
					return BrainrotData.getCharacter(carried.charId)
				end)
				if okName and type(ch) == "table" then
					depositedName = ch.name or ch.Name or depositedName
				end
			end
			local ownerPlayer = player
			local thisSlot = slotIndex
			local sellPrompt = Instance.new("ProximityPrompt")
			sellPrompt.Name = "SellPrompt"
			sellPrompt.ActionText = "Sell"
			sellPrompt.ObjectText = depositedName
			sellPrompt.HoldDuration = 0
			sellPrompt.KeyboardKeyCode = Enum.KeyCode.E
			sellPrompt.MaxActivationDistance = 10
			sellPrompt.RequiresLineOfSight = false
			sellPrompt.Parent = model.PrimaryPart
			sellPrompt.Triggered:Connect(function(triggerPlayer)
				local okSell, errSell = pcall(sellPedestalBrainrot, triggerPlayer, ownerPlayer, thisSlot)
				if not okSell then
					warn("[BrainrotCarnival] Sell prompt handler failed: " .. tostring(errSell))
				end
			end)
			local stealPrompt = Instance.new("ProximityPrompt")
			stealPrompt.Name = "StealPrompt"
			stealPrompt.ActionText = "Steal"
			stealPrompt.ObjectText = depositedName
			stealPrompt.HoldDuration = 0
			stealPrompt.KeyboardKeyCode = Enum.KeyCode.E
			stealPrompt.MaxActivationDistance = 10
			stealPrompt.RequiresLineOfSight = false
			stealPrompt.Parent = model.PrimaryPart
			stealPrompt.Triggered:Connect(function(triggerPlayer)
				local okSteal, errSteal = pcall(stealPedestalBrainrot, triggerPlayer, ownerPlayer, thisSlot)
				if not okSteal then
					warn("[BrainrotCarnival] Steal prompt handler failed: " .. tostring(errSteal))
				end
			end)
		end
		carrying[player] = nil
		sendProfile(player)
		notifyPlayer(player, "Deposited! It now earns money every second.", Color3.fromRGB(80, 220, 120))
	end)
	if not ok then
		warn("[BrainrotCarnival] Deposit prompt handler failed: " .. tostring(err))
	end
end

-- (h) Sell: remove the pedestal model, Economy.sellBrainrot pays the refund.
-- Coordinator fix 3: PRIMARY path is the pedestal "Sell" ProximityPrompt
-- (created in depositCarriedBrainrot); NO SellBrainrot remote handler.
-- sellPedestalBrainrot(triggerPlayer, ownerPlayer, slotIndex): only the
-- booth owner may sell; a rival triggering Sell is told to use Steal.
function sellPedestalBrainrot(player, ownerPlayer, slotIndex)
	local ok, err = pcall(function()
		if ownerPlayer ~= nil and ownerPlayer ~= player then
			notifyPlayer(player, "That brainrot is not yours. Use Steal to take it.", Color3.fromRGB(255, 200, 60))
			return
		end
		local profile = profiles[player]
		if profile == nil then
			return
		end
		slotIndex = tonumber(slotIndex)
		if slotIndex == nil or slotIndex < 1 or slotIndex > 8 then
			notifyPlayer(player, "Pick a valid booth slot (1-8) to sell.", Color3.fromRGB(255, 200, 60))
			return
		end
		local entry = getSlotEntry(profile, slotIndex)
		if entry == nil then
			notifyPlayer(player, "That slot is empty.", Color3.fromRGB(255, 200, 60))
			return
		end
		local placed = pedestalModels[player]
		if placed ~= nil and placed[slotIndex] ~= nil then
			pcall(function()
				placed[slotIndex].model:Destroy()
			end)
			placed[slotIndex] = nil
		end
		local refund = nil
		do
			local ok2, result = pcall(function()
				return Economy.sellBrainrot(profile, slotIndex)
			end)
			if ok2 then
				refund = result
			else
				warn("[BrainrotCarnival] sellBrainrot error: " .. tostring(result))
			end
		end
		sendProfile(player)
		if type(refund) == "number" then
			notifyPlayer(player, "Sold for $" .. tostring(refund) .. ".", Color3.fromRGB(80, 220, 120))
		else
			notifyPlayer(player, "Sold.", Color3.fromRGB(80, 220, 120))
		end
	end)
	if not ok then
		warn("[BrainrotCarnival] Sell prompt handler failed: " .. tostring(err))
	end
end

-- (i) Steal: validate with BoothLogic, move the brainrot, thief carries it.
-- Coordinator fix 3: PRIMARY path is the pedestal "Steal" ProximityPrompt
-- (created in depositCarriedBrainrot); NO StealBrainrot remote handler.
-- stealPedestalBrainrot(thiefPlayer, victimPlayer, slotIndex): the prompt
-- already knows the victim (the booth owner), so no UserId lookup is
-- needed. The owner triggering Steal on their own brainrot is refused.
function stealPedestalBrainrot(player, victimPlayer, slotIndex)
	local ok, err = pcall(function()
		local thiefProfile = profiles[player]
		if thiefProfile == nil then
			return
		end
		if carrying[player] ~= nil then
			notifyPlayer(player, "Deposit what you are carrying first, then steal.", Color3.fromRGB(255, 200, 60))
			return
		end
		slotIndex = tonumber(slotIndex)
		if slotIndex == nil or slotIndex < 1 or slotIndex > 8 then
			notifyPlayer(player, "Pick a valid slot (1-8) to steal from.", Color3.fromRGB(255, 200, 60))
			return
		end
		local victim = victimPlayer
		if victim == nil or victim == player then
			notifyPlayer(player, "You cannot steal your own brainrot. Use Sell instead.", Color3.fromRGB(255, 200, 60))
			return
		end
		local victimProfile = profiles[victim]
		if victimProfile == nil then
			notifyPlayer(player, "That player has no profile yet.", Color3.fromRGB(255, 120, 120))
			return
		end
		local victimEntry = getSlotEntry(victimProfile, slotIndex)
		if victimEntry == nil then
			notifyPlayer(player, "That slot is empty.", Color3.fromRGB(255, 200, 60))
			return
		end
		local victimCharId = getEntryCharId(victimEntry)
		local victimMutation = getEntryMutation(victimEntry)
		local now = os.time()
		local canSteal = false
		do
			local ok2, result = pcall(function()
				return BoothLogic.canSteal(thiefProfile, victimProfile, now)
			end)
			if ok2 then
				canSteal = result
			else
				warn("[BrainrotCarnival] canSteal error: " .. tostring(result))
			end
		end
		if canSteal == false or canSteal == nil then
			local shielded = false
			local locked = false
			pcall(function()
				shielded = BoothLogic.isShielded(victimProfile, now)
				locked = BoothLogic.isLocked(victimProfile, now)
			end)
			if shielded then
				notifyPlayer(player, "That booth is shielded. Try again later.", Color3.fromRGB(255, 120, 120))
			elseif locked then
				notifyPlayer(player, "That booth is locked. Try again later.", Color3.fromRGB(255, 120, 120))
			else
				notifyPlayer(player, "You cannot steal that brainrot right now (your booth may be full).", Color3.fromRGB(255, 120, 120))
			end
			return
		end
		-- Steal it: remove the victim's pedestal model first.
		local victimPlaced = pedestalModels[victim]
		if victimPlaced ~= nil and victimPlaced[slotIndex] ~= nil then
			pcall(function()
				victimPlaced[slotIndex].model:Destroy()
			end)
			victimPlaced[slotIndex] = nil
		end
		local thiefSlot = nil
		do
			local ok2, result, slot = pcall(function()
				return BoothLogic.applySteal(thiefProfile, victimProfile, slotIndex)
			end)
			if not ok2 then
				warn("[BrainrotCarnival] applySteal error: " .. tostring(result))
				notifyPlayer(player, "Steal failed. Try again.", Color3.fromRGB(255, 120, 120))
				return
			end
			if result == false then
				notifyPlayer(player, "Steal failed.", Color3.fromRGB(255, 120, 120))
				return
			end
			if type(slot) == "number" then
				thiefSlot = slot
			elseif type(result) == "number" then
				thiefSlot = result
			end
		end
		if type(thiefSlot) ~= "number" then
			thiefSlot = findProfileSlotForCharacter(thiefProfile, victimCharId, victimMutation, player)
		end
		if type(thiefSlot) ~= "number" then
			thiefSlot = findFreePedestalSlot(player)
		end
		-- Give the thief the stolen brainrot to carry to their own booth.
		local stolenModel = nil
		do
			local ok2, built = pcall(function()
				return CharacterModels.buildCharacterModel(victimCharId, victimMutation)
			end)
			if ok2 and built ~= nil then
				stolenModel = built
			end
		end
		if stolenModel == nil then
			warn("[BrainrotCarnival] Stolen model build failed.")
			notifyPlayer(player, "Steal failed to load the brainrot.", Color3.fromRGB(255, 120, 120))
			return
		end
		local weld = attachCarriedModel(player, stolenModel)
		if weld == nil then
			pcall(function()
				stolenModel:Destroy()
			end)
			return
		end
		carrying[player] = {
			charId = victimCharId,
			mutation = victimMutation,
			model = stolenModel,
			weld = weld,
			slotIndex = thiefSlot,
		}
		sendProfile(player)
		sendProfile(victim)
		local charName = tostring(victimCharId)
		do
			local ok3, ch = pcall(function()
				return BrainrotData.getCharacter(victimCharId)
			end)
			if ok3 and type(ch) == "table" then
				charName = ch.name or ch.Name or charName
			end
		end
		notifyPlayer(player, "You stole " .. charName .. "! Run it to your booth and deposit it.", Color3.fromRGB(255, 200, 60))
		notifyPlayer(victim, player.Name .. " stole your " .. charName .. "!", Color3.fromRGB(255, 120, 120))
	end)
	if not ok then
		warn("[BrainrotCarnival] Steal prompt handler failed: " .. tostring(err))
	end
end

-- (j) Shop / shield / lock / rebirth --------------------------------------
BuyShopItem.OnServerEvent:Connect(function(player, itemId)
	local ok, err = pcall(function()
		local profile = profiles[player]
		if profile == nil or itemId == nil then
			return
		end
		local bought = false
		do
			local ok2, result = pcall(function()
				return Economy.buyShopItem(profile, itemId)
			end)
			if ok2 then
				bought = result
			else
				warn("[BrainrotCarnival] buyShopItem error: " .. tostring(result))
			end
		end
		if bought == false or bought == nil then
			notifyPlayer(player, "Could not buy that shop item (not enough money, or max level).", Color3.fromRGB(255, 120, 120))
			return
		end
		-- Walk speed applies immediately from the shop speed level.
		if itemId == "speed" or itemId == "walkspeed" or itemId == "walk_speed" then
			local character = player.Character
			if character ~= nil then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid ~= nil then
					humanoid.WalkSpeed = getWalkSpeed(profile)
				end
			end
		end
		sendProfile(player)
		notifyPlayer(player, "Bought shop item: " .. tostring(itemId) .. ".", Color3.fromRGB(80, 220, 120))
	end)
	if not ok then
		warn("[BrainrotCarnival] BuyShopItem handler failed: " .. tostring(err))
	end
end)

UseShield.OnServerEvent:Connect(function(player)
	local ok, err = pcall(function()
		local profile = profiles[player]
		if profile == nil then
			return
		end
		local bought = false
		do
			local ok2, result = pcall(function()
				return Economy.buyShopItem(profile, "shield")
			end)
			if ok2 then
				bought = result
			else
				warn("[BrainrotCarnival] shield buy error: " .. tostring(result))
			end
		end
		if bought == false or bought == nil then
			notifyPlayer(player, "Could not buy a shield (not enough money).", Color3.fromRGB(255, 120, 120))
			return
		end
		sendProfile(player)
		notifyPlayer(player, "Shield up! Your booth cannot be stolen from while it lasts.", Color3.fromRGB(80, 180, 255))
	end)
	if not ok then
		warn("[BrainrotCarnival] UseShield handler failed: " .. tostring(err))
	end
end)

ToggleLock.OnServerEvent:Connect(function(player)
	local ok, err = pcall(function()
		local profile = profiles[player]
		if profile == nil then
			return
		end
		local now = os.time()
		local locked = false
		pcall(function()
			locked = BoothLogic.isLocked(profile, now)
		end)
		if locked then
			-- Unlock: clear the lock timer on the profile.
			profile.lockUntil = 0
			if profile.lockedUntil ~= nil then
				profile.lockedUntil = 0
			end
			sendProfile(player)
			notifyPlayer(player, "Booth unlocked.", Color3.fromRGB(255, 200, 60))
			return
		end
		local bought = false
		do
			local ok2, result = pcall(function()
				return Economy.buyShopItem(profile, "lock")
			end)
			if ok2 then
				bought = result
			else
				warn("[BrainrotCarnival] lock buy error: " .. tostring(result))
			end
		end
		if bought == false or bought == nil then
			notifyPlayer(player, "Could not buy a lock (not enough money).", Color3.fromRGB(255, 120, 120))
			return
		end
		sendProfile(player)
		notifyPlayer(player, "Booth locked! Nobody can steal from you while it lasts.", Color3.fromRGB(80, 180, 255))
	end)
	if not ok then
		warn("[BrainrotCarnival] ToggleLock handler failed: " .. tostring(err))
	end
end)

Rebirth.OnServerEvent:Connect(function(player)
	local ok, err = pcall(function()
		local profile = profiles[player]
		if profile == nil then
			return
		end
		local can = false
		do
			local ok2, result = pcall(function()
				return Economy.canRebirth(profile)
			end)
			if ok2 then
				can = result
			else
				warn("[BrainrotCarnival] canRebirth error: " .. tostring(result))
			end
		end
		if can == false or can == nil then
			notifyPlayer(player, "You cannot rebirth yet. Earn more first.", Color3.fromRGB(255, 200, 60))
			return
		end
		local ok2, result = pcall(function()
			return Economy.rebirth(profile)
		end)
		if not ok2 then
			warn("[BrainrotCarnival] rebirth error: " .. tostring(result))
			notifyPlayer(player, "Rebirth failed. Try again.", Color3.fromRGB(255, 120, 120))
			return
		end
		-- Rebirth clears the booth: remove every pedestal model and anything
		-- the player is carrying, then reset walk speed.
		clearPedestalModels(player)
		destroyCarrying(player)
		local character = player.Character
		if character ~= nil then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid ~= nil then
				humanoid.WalkSpeed = getWalkSpeed(profile)
			end
		end
		sendProfile(player)
		notifyPlayer(player, "Rebirth complete! Permanent income multiplier increased.", Color3.fromRGB(255, 215, 0))
	end)
	if not ok then
		warn("[BrainrotCarnival] Rebirth handler failed: " .. tostring(err))
	end
end)

GetProfile.OnServerInvoke = function(player)
	local profile = profiles[player]
	if profile == nil then
		profile = Economy.newProfile()
		profiles[player] = profile
	end
	return profile
end

-- (k) Income loop: every 1 s, tick income for every player. --------------
task.spawn(function()
	while true do
		task.wait(1)
		local ok, err = pcall(function()
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = profiles[player]
				if profile ~= nil then
					pcall(function()
						Economy.tickIncome(profile, 1)
					end)
					sendProfile(player)
				end
			end
		end)
		if not ok then
			warn("[BrainrotCarnival] Income loop failed: " .. tostring(err))
		end
	end
end)

-- (l) Ferris Wheel event: every 180 s, warning 10 s, active 20 s. ---------
task.spawn(function()
	while true do
		task.wait(180)
		local ok, err = pcall(function()
			-- Warning phase: 10 s to run home.
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(function()
					EventWarning:FireClient(player, { phase = "warning", secondsLeft = 10 })
				end)
			end
			notifyPlayerAll("The Runaway Ferris Wheel is coming! Run back to your booth in 10 seconds!")
			task.wait(10)
			-- Active phase: 20 s. Anyone outside their safe zone drops what
			-- they carry (it returns to the parade start) and is stunned 2 s.
			ferrisActive = true
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(function()
					EventWarning:FireClient(player, { phase = "active", secondsLeft = 20 })
				end)
			end
			local activeEnd = os.clock() + 20
			while os.clock() < activeEnd do
				for _, player in ipairs(Players:GetPlayers()) do
					pcall(function()
						local carried = carrying[player]
						if carried == nil then
							return
						end
						local booth = getBooth(player)
						if booth == nil then
							return
						end
						local character = player.Character
						if character == nil then
							return
						end
						local hrp = character:FindFirstChild("HumanoidRootPart")
						if hrp == nil then
							return
						end
						local safeCenter = booth.safeCenter or booth.position
						local safeRadius = booth.safeRadius or 12
						local distance = (hrp.Position - safeCenter).Magnitude
						if distance <= safeRadius then
							return
						end
						-- Outside the safe zone: drop the carried brainrot.
						local profile = profiles[player]
						local dropCharId = carried.charId
						local dropMutation = carried.mutation
						local dropSlot = carried.slotIndex
						destroyCarrying(player)
						if profile ~= nil and type(dropSlot) == "number" then
							-- Remove it from the profile with no refund.
							local list = getBrainrotList(profile)
							if list[dropSlot] ~= nil then
								list[dropSlot] = nil
							end
						end
						-- It returns to the parade start at its normal cost.
						spawnParadeBrainrot(dropCharId, dropMutation, world.conveyor.start)
						sendProfile(player)
						notifyPlayer(player, "The Ferris Wheel scared you! You dropped your brainrot - it ran back to the parade.", Color3.fromRGB(255, 120, 120))
						-- 2 s stun, then restore the shop walk speed.
						local humanoid = character:FindFirstChildOfClass("Humanoid")
						if humanoid ~= nil then
							local restoreSpeed = 16
							if profile ~= nil then
								restoreSpeed = getWalkSpeed(profile)
							end
							humanoid.WalkSpeed = 0
							stunnedUntil[player] = os.clock() + 2
							task.delay(2, function()
								local stillHumanoid = nil
								if player.Character ~= nil then
									stillHumanoid = player.Character:FindFirstChildOfClass("Humanoid")
								end
								if stillHumanoid ~= nil then
									stillHumanoid.WalkSpeed = restoreSpeed
								end
							end)
						end
					end)
				end
				task.wait(1)
			end
			ferrisActive = false
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(function()
					EventWarning:FireClient(player, { phase = "clear", secondsLeft = 0 })
				end)
			end
		end)
		if not ok then
			ferrisActive = false
			warn("[BrainrotCarnival] Ferris Wheel event failed: " .. tostring(err))
		end
	end
end)

-- Helper used by the Ferris Wheel warning above (kept separate so the
-- warning loop above stays readable).
function notifyPlayerAll(text)
	for _, player in ipairs(Players:GetPlayers()) do
		notifyPlayer(player, text, Color3.fromRGB(255, 200, 60))
	end
end

-- (m) Leaderboard: every 10 s, top 10 by totalEarned. ----------------------
task.spawn(function()
	while true do
		task.wait(10)
		local ok, err = pcall(function()
			local entries = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = profiles[player]
				if profile ~= nil then
					table.insert(entries, { name = player.Name, totalEarned = getTotalEarned(profile) })
				end
			end
			table.sort(entries, function(a, b)
				return a.totalEarned > b.totalEarned
			end)
			local top = {}
			for i = 1, math.min(10, #entries) do
				top[i] = entries[i]
			end
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(function()
					LeaderboardUpdate:FireClient(player, top)
				end)
			end
		end)
		if not ok then
			warn("[BrainrotCarnival] Leaderboard loop failed: " .. tostring(err))
		end
	end
end)

-- Seed the parade so the first player sees brainrots immediately.
task.spawn(function()
	task.wait(1)
	local ok, err = pcall(function()
		for _ = 1, 3 do
			if #parade < 10 then
				spawnParadeBrainrot(nil, nil, nil)
			end
		end
	end)
	if not ok then
		warn("[BrainrotCarnival] Parade seed failed: " .. tostring(err))
	end
end)

print("[BrainrotCarnival] Main server started. Booths: " .. tostring(#world.booths))
