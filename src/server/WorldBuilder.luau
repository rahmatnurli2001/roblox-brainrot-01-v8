--!strict
-- WorldBuilder.luau
-- "Brainrot Carnival" — bright sunny 3D Steal-a-Brainrot style carnival world.
-- Builds the ENTIRE 3D world in code (parts only, no meshes / assets).
-- Lighting is BRIGHT and sunny everywhere: no dark or moody lighting.
--
-- FERRIS WHEEL NOTE: every part in this world is anchored = true, INCLUDING
-- the Ferris wheel. The server Main loop rotates the wheel by setting CFrame
-- on the anchored wheel model each tick (CFrame rotation of an anchored model
-- is safe and deterministic). Nothing here is left unanchored.

local WorldBuilder = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function newPart(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material,
	anchored: boolean,
	canCollide: boolean
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.Anchored = anchored
	part.CanCollide = canCollide
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Text on a sign board, legible from BOTH large faces. A single SurfaceGui
-- on Front is invisible from the player's viewpoint: the booth boards are
-- thin in X (0.6 wide), so Front is a 0.6-wide edge, and the entrance board
-- faces the spawn with its Back (+Z) side. The label is therefore drawn on
-- the two large faces of the board (Left/Right when thin in X, Front/Back
-- when thin in Z, Top/Bottom when thin in Y). Same text, colours and sizing
-- as before; only the faces change. (textSize is kept for the call sites;
-- the label scales to fill the face, so it is unused.)
local function addTextLabel(part: BasePart, text: string, textColor: Color3, bgColor: Color3, textSize: number)
	local size = part.Size
	local faces: { Enum.NormalId } = {}
	if size.X <= size.Y and size.X <= size.Z then
		-- Thin in X: the large faces are Left and Right.
		faces = { Enum.NormalId.Left, Enum.NormalId.Right }
	elseif size.Z <= size.X and size.Z <= size.Y then
		-- Thin in Z: the large faces are Front and Back.
		faces = { Enum.NormalId.Front, Enum.NormalId.Back }
	else
		-- Thin in Y: the large faces are Top and Bottom.
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

-- Vivid saturated palette
local COLORS = {
	Grass = Color3.fromRGB(58, 214, 74), -- vivid bright green
	Walkway = Color3.fromRGB(255, 236, 179), -- light tan / cream
	WalkRed = Color3.fromRGB(255, 59, 59),
	WalkWhite = Color3.fromRGB(255, 255, 255),
	Belt = Color3.fromRGB(64, 64, 72), -- dark grey belt top
	BeltEdge = Color3.fromRGB(255, 214, 0), -- bright yellow edge stripe
	White = Color3.fromRGB(255, 255, 255),
	Red = Color3.fromRGB(255, 45, 45),
	Orange = Color3.fromRGB(255, 140, 0),
	Yellow = Color3.fromRGB(255, 214, 0),
	Green = Color3.fromRGB(0, 200, 83),
	Blue = Color3.fromRGB(0, 140, 255),
	Purple = Color3.fromRGB(160, 60, 255),
	Pink = Color3.fromRGB(255, 80, 200),
	Cyan = Color3.fromRGB(0, 220, 230),
	Post = Color3.fromRGB(120, 72, 20),
	Metal = Color3.fromRGB(200, 200, 210),
}

local BOOTH_COLORS = {
	COLORS.Red,
	COLORS.Orange,
	COLORS.Yellow,
	COLORS.Green,
	COLORS.Blue,
	COLORS.Purple,
	COLORS.Pink,
	COLORS.Cyan,
}

-- ---------------------------------------------------------------------------
-- Lighting — NOT set in code. Lighting lives in the place file
-- (default.project.json) now. A live server thread cannot write the
-- Lighting service's Technology property at runtime: that write errors
-- and kills the whole world build before a single part is created, so
-- the player spawns into a world with no baseplate and no SpawnLocation
-- and falls through the void. Never write any Lighting property from
-- server code again.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- buildWorld()
-- ---------------------------------------------------------------------------

function WorldBuilder.buildWorld()
	local world = Instance.new("Model")
	world.Name = "BrainrotCarnivalWorld"
	world.Parent = workspace

	-- ------------------------------------------------------------------
	-- Baseplate: huge bright-green grass plate (512 x 4 x 512)
	-- Top surface at y = 2 (part centered at y = 0).
	-- ------------------------------------------------------------------
	local baseplate = newPart("Baseplate", Vector3.new(512, 4, 512), Vector3.new(0, 0, 0), COLORS.Grass, Enum.Material.Grass, true, true)
	baseplate.Parent = world

	-- ------------------------------------------------------------------
	-- Midway: wide bright walkway down the center (20 wide, 200 long)
	-- Runs along Z from z = -100 to z = +100. Top at y = 2.2.
	-- Colorful red/white alternating side strips along both edges.
	-- ------------------------------------------------------------------
	local walkway = newPart("MidwayWalkway", Vector3.new(20, 0.4, 200), Vector3.new(0, 2.2, 0), COLORS.Walkway, Enum.Material.SmoothPlastic, true, true)
	walkway.Parent = world

	-- Side strips: 20 segments per side, each 10 studs long, alternating red/white.
	for side = -1, 1, 2 do
		for i = 0, 19 do
			local z = -95 + i * 10
			local stripColor = COLORS.WalkRed
			if i % 2 == 1 then
				stripColor = COLORS.WalkWhite
			end
			local strip = newPart(
				"MidwayStrip",
				Vector3.new(1.5, 0.5, 10),
				Vector3.new(side * 10.75, 2.25, z),
				stripColor,
				Enum.Material.SmoothPlastic,
				true,
				true
			)
			strip.Parent = world
		end
	end

	-- ------------------------------------------------------------------
	-- Parade conveyor: long straight belt across the middle (120 x 1 x 6),
	-- along X at z = 0, top at y = 3. Dark grey top, bright yellow edges.
	-- Waypoints run from one end to the other at height y = 3.5.
	-- Small colorful arches over the belt every 20 studs.
	-- ------------------------------------------------------------------
	local conveyorStart = Vector3.new(-58, 3.5, 0)
	local conveyorFinish = Vector3.new(58, 3.5, 0)

	local belt = newPart("ConveyorBelt", Vector3.new(120, 1, 6), Vector3.new(0, 2.5, 0), COLORS.Belt, Enum.Material.SmoothPlastic, true, true)
	belt.Parent = world

	for edge = -1, 1, 2 do
		local stripe = newPart(
			"ConveyorEdge",
			Vector3.new(120, 1.1, 0.8),
			Vector3.new(0, 2.5, edge * 3),
			COLORS.BeltEdge,
			Enum.Material.Neon,
			true,
			true
		)
		stripe.Parent = world
	end

	-- Waypoints every 10 studs along the belt.
	local waypoints = {}
	for x = -58, 58, 10 do
		table.insert(waypoints, Vector3.new(x, 3.5, 0))
	end

	-- Arches over the belt every 20 studs: two posts + a red/yellow top bar.
	local archXs = { -50, -30, -10, 10, 30, 50 }
	for index, x in ipairs(archXs) do
		local archColor = COLORS.Red
		if index % 2 == 0 then
			archColor = COLORS.Yellow
		end
		local postA = newPart("ArchPost", Vector3.new(1, 6, 1), Vector3.new(x, 5, -3.5), archColor, Enum.Material.SmoothPlastic, true, true)
		postA.Parent = world
		local postB = newPart("ArchPost", Vector3.new(1, 6, 1), Vector3.new(x, 5, 3.5), archColor, Enum.Material.SmoothPlastic, true, true)
		postB.Parent = world
		local topBar = newPart("ArchTop", Vector3.new(1, 1, 8), Vector3.new(x, 8.5, 0), archColor, Enum.Material.SmoothPlastic, true, true)
		topBar.Parent = world
		-- Small neon ball on top of each arch for extra carnival pop.
		local ball = Instance.new("Part")
		ball.Name = "ArchBall"
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(2, 2, 2)
		ball.Position = Vector3.new(x, 9.8, 0)
		ball.Color = COLORS.Yellow
		ball.Material = Enum.Material.Neon
		ball.Anchored = true
		ball.CanCollide = false
		ball.Parent = world
	end

	-- ------------------------------------------------------------------
	-- Booths: 8 booths in two rows of 4, flanking the midway, facing the
	-- conveyor. Row west x = -22, row east x = +22; z = -80, -40, 40, 80.
	-- Each booth: vivid floor pad 12x12, 4 low white walls (2 high) with
	-- colored trim, a sign post "BOOTH 1".."BOOTH 8", 8 pedestals in a
	-- 2x4 grid (white cylinders with a Neon glowing ring).
	-- Safe zone = the booth floor: safeCenter = booth center, safeRadius = 8.
	-- ------------------------------------------------------------------
	local booths = {}
	local boothZs = { -80, -40, 40, 80 }
	local boothXs = { -22, 22 }
	local boothIndex = 0

	for _, bx in ipairs(boothXs) do
		for _, bz in ipairs(boothZs) do
			boothIndex += 1
			local boothColor = BOOTH_COLORS[boothIndex]
			local center = Vector3.new(bx, 2, bz)

			local boothModel = Instance.new("Model")
			boothModel.Name = "Booth" .. tostring(boothIndex)
			boothModel.Parent = world

			-- Floor pad 12 x 12 (top at y = 3).
			local pad = newPart("BoothPad", Vector3.new(12, 1, 12), Vector3.new(bx, 2.5, bz), boothColor, Enum.Material.SmoothPlastic, true, true)
			pad.Parent = boothModel

			-- 4 low walls, 2 studs high, white with colored trim on top.
			-- Walls sit on the pad edge; the side facing the midway/conveyor
			-- (the inner side, toward x = 0) is left OPEN as the entrance.
			local wallY = 4 -- wall center: pad top 3 + 1
			local trimY = 5.1
			local wallDefs = {
				{ size = Vector3.new(12, 2, 0.6), pos = Vector3.new(bx, wallY, bz - 5.7) }, -- back (z-)
				{ size = Vector3.new(12, 2, 0.6), pos = Vector3.new(bx, wallY, bz + 5.7) }, -- front (z+)
				{ size = Vector3.new(0.6, 2, 12), pos = Vector3.new(bx - 5.7 * math.sign(bx), wallY, bz) }, -- outer (x away from center)
			}
			for _, def in ipairs(wallDefs) do
				local wall = newPart("BoothWall", def.size, def.pos, COLORS.White, Enum.Material.SmoothPlastic, true, true)
				wall.Parent = boothModel
				-- Colored trim strip along the top of the wall.
				local trimSize = Vector3.new(def.size.X, 0.3, def.size.Z)
				if def.size.X < def.size.Z then
					trimSize = Vector3.new(0.7, 0.3, def.size.Z)
				end
				local trim = newPart("BoothTrim", trimSize, Vector3.new(def.pos.X, trimY, def.pos.Z), boothColor, Enum.Material.Neon, true, true)
				trim.Parent = boothModel
			end

			-- Sign post at the open (inner) side of the booth, facing the midway.
			local signX = bx - 6.5 * math.sign(bx)
			local post = newPart("BoothSignPost", Vector3.new(0.8, 5, 0.8), Vector3.new(signX, 5.5, bz), COLORS.Post, Enum.Material.Wood, true, true)
			post.Parent = boothModel
			local board = newPart("BoothSignBoard", Vector3.new(0.6, 3, 6), Vector3.new(signX, 9, bz), boothColor, Enum.Material.SmoothPlastic, true, true)
			board.Parent = boothModel
			-- Face the board toward the midway (rotate so Front faces x = 0).
			if bx > 0 then
				board.CFrame = CFrame.new(board.Position) * CFrame.Angles(0, math.rad(90), 0)
			else
				board.CFrame = CFrame.new(board.Position) * CFrame.Angles(0, math.rad(-90), 0)
			end
			addTextLabel(board, "BOOTH " .. tostring(boothIndex), COLORS.White, boothColor, 48)
			local signPosition = Vector3.new(signX, 9, bz)

			-- 8 pedestals in a 2x4 grid on the floor: 2 columns (x) x 4 rows (z).
			-- Pedestal: white cylinder, 2 studs diameter, 1 stud tall, top at y = 4.
			-- Neon glowing ring (flat cylinder) on top of each pedestal.
			local pedestals = {}
			local colOffsets = { -2.5, 2.5 }
			local rowOffsets = { -4.5, -1.5, 1.5, 4.5 }
			for _, cx in ipairs(colOffsets) do
				for _, rz in ipairs(rowOffsets) do
					local px = bx + cx
					local pz = bz + rz
					local pedestal = Instance.new("Part")
					pedestal.Name = "Pedestal"
					pedestal.Shape = Enum.PartType.Cylinder
					pedestal.Size = Vector3.new(1, 2, 2)
					pedestal.CFrame = CFrame.new(px, 3.5, pz) * CFrame.Angles(0, 0, math.rad(90))
					pedestal.Color = COLORS.White
					pedestal.Material = Enum.Material.SmoothPlastic
					pedestal.Anchored = true
					pedestal.CanCollide = true
					pedestal.TopSurface = Enum.SurfaceType.Smooth
					pedestal.BottomSurface = Enum.SurfaceType.Smooth
					pedestal.Parent = boothModel

					-- Glowing Neon ring on top of the pedestal.
					local ring = Instance.new("Part")
					ring.Name = "PedestalRing"
					ring.Shape = Enum.PartType.Cylinder
					ring.Size = Vector3.new(0.3, 2.4, 2.4)
					ring.CFrame = CFrame.new(px, 4.1, pz) * CFrame.Angles(0, 0, math.rad(90))
					ring.Color = boothColor
					ring.Material = Enum.Material.Neon
					ring.Anchored = true
					ring.CanCollide = false
					ring.Parent = boothModel

					table.insert(pedestals, Vector3.new(px, 4, pz))
				end
			end

			table.insert(booths, {
				position = center,
				pedestals = pedestals,
				signPosition = signPosition,
				safeCenter = center,
				safeRadius = 8,
			})
		end
	end

	-- ------------------------------------------------------------------
	-- Ferris wheel: at the far end of the midway (z = +95), hub at y = 33,
	-- radius 25. Hub raised to 33 (not 30) so the lowest gondola's bottom
	-- (33 - 25 - 3.5 - 2 = 2.5) clears the baseplate top (y = 2).
	-- colors, on two support legs. The whole wheel model is ANCHORED; the
	-- server Main loop rotates it by setting CFrame on the model each tick.
	-- ------------------------------------------------------------------
	local ferrisWheelPosition = Vector3.new(0, 33, 95)
	local wheelModel = Instance.new("Model")
	wheelModel.Name = "FerrisWheel"
	wheelModel.Parent = world

	-- Two support legs (A-frame) from the ground to the hub.
	for _, legX in ipairs({ -6, 6 }) do
		local leg = newPart("FerrisLeg", Vector3.new(2, 34, 2), Vector3.new(legX, 17, 95), COLORS.Metal, Enum.Material.Metal, true, true)
		leg.Parent = wheelModel
	end
	-- Hub (center axle).
	local hub = Instance.new("Part")
	hub.Name = "FerrisHub"
	hub.Shape = Enum.PartType.Ball
	hub.Size = Vector3.new(6, 6, 6)
	hub.Position = ferrisWheelPosition
	hub.Color = COLORS.Yellow
	hub.Material = Enum.Material.Neon
	hub.Anchored = true
	hub.CanCollide = true
	hub.Parent = wheelModel

	-- Rim: 16 bright segments forming a ring of radius 25 in the X-Y plane
	-- (wheel faces the midway, rotating around the Z axis).
	local rimColors = { COLORS.Red, COLORS.Yellow, COLORS.Blue, COLORS.Green, COLORS.Pink, COLORS.Cyan, COLORS.Orange, COLORS.Purple }
	for i = 0, 15 do
		local angle = (i / 16) * math.pi * 2
		local x = math.cos(angle) * 25
		local y = 33 + math.sin(angle) * 25
		local seg = newPart(
			"FerrisRim",
			Vector3.new(3, 3, 2),
			Vector3.new(x, y, 95),
			rimColors[(i % 8) + 1],
			Enum.Material.Neon,
			true,
			true
		)
		seg.CFrame = CFrame.new(seg.Position) * CFrame.Angles(0, 0, angle)
		seg.Parent = wheelModel
	end

	-- Spokes: 8 bars from hub to rim.
	for i = 0, 7 do
		local angle = (i / 8) * math.pi * 2
		local midX = math.cos(angle) * 12.5
		local midY = 33 + math.sin(angle) * 12.5
		local spoke = newPart("FerrisSpoke", Vector3.new(25, 1, 1), Vector3.new(midX, midY, 95), COLORS.White, Enum.Material.Metal, true, true)
		spoke.CFrame = CFrame.new(spoke.Position) * CFrame.Angles(0, 0, angle)
		spoke.Parent = wheelModel
	end

	-- 8 gondolas in vivid colors, hanging at the rim.
	local gondolaColors = { COLORS.Red, COLORS.Orange, COLORS.Yellow, COLORS.Green, COLORS.Blue, COLORS.Purple, COLORS.Pink, COLORS.Cyan }
	for i = 0, 7 do
		local angle = (i / 8) * math.pi * 2
		local gx = math.cos(angle) * 25
		local gy = 33 + math.sin(angle) * 25
		local gondola = newPart(
			"FerrisGondola",
			Vector3.new(5, 4, 5),
			Vector3.new(gx, gy - 3.5, 95),
			gondolaColors[i + 1],
			Enum.Material.SmoothPlastic,
			true,
			true
		)
		gondola.Parent = wheelModel
		-- Hanger bar connecting gondola to rim.
		local hanger = newPart("FerrisHanger", Vector3.new(0.8, 2.5, 0.8), Vector3.new(gx, gy - 0.8, 95), COLORS.Metal, Enum.Material.Metal, true, true)
		hanger.Parent = wheelModel
	end

	-- ------------------------------------------------------------------
	-- Decorations
	-- ------------------------------------------------------------------

	-- 12 balloon bunches (bright spheres on thin poles) around the midway.
	local balloonColors = { COLORS.Red, COLORS.Yellow, COLORS.Blue, COLORS.Pink, COLORS.Green, COLORS.Cyan, COLORS.Orange, COLORS.Purple }
	for i = 1, 12 do
		local side = 1
		if i % 2 == 0 then
			side = -1
		end
		local z = -88 + (i - 1) * 16
		local bx = side * 14
		local pole = newPart("BalloonPole", Vector3.new(0.3, 7, 0.3), Vector3.new(bx, 5.5, z), COLORS.White, Enum.Material.SmoothPlastic, true, false)
		pole.Parent = world
		-- Bunch of 3 spheres at the top of the pole.
		local bunchOffsets = {
			Vector3.new(0, 0, 0),
			Vector3.new(-1.2, 0.8, 0.5),
			Vector3.new(1.2, 0.8, -0.5),
		}
		for j, off in ipairs(bunchOffsets) do
			local balloon = Instance.new("Part")
			balloon.Name = "Balloon"
			balloon.Shape = Enum.PartType.Ball
			balloon.Size = Vector3.new(2.4, 2.4, 2.4)
			balloon.Position = Vector3.new(bx, 10, z) + off
			balloon.Color = balloonColors[((i + j - 2) % 8) + 1]
			balloon.Material = Enum.Material.SmoothPlastic
			balloon.Anchored = true
			balloon.CanCollide = false
			balloon.Parent = world
		end
	end

	-- 8 striped carnival stalls (small tents: 4 poles + pyramid roof in
	-- red/white) along the edges, x = +/-40.
	local stallZs = { -70, -25, 25, 70 }
	for _, sx in ipairs({ -40, 40 }) do
		for _, sz in ipairs(stallZs) do
			local stall = Instance.new("Model")
			stall.Name = "CarnivalStall"
			stall.Parent = world
			for _, px in ipairs({ -3, 3 }) do
				for _, pz in ipairs({ -3, 3 }) do
					local pole = newPart("StallPole", Vector3.new(0.6, 5, 0.6), Vector3.new(sx + px, 4.5, sz + pz), COLORS.White, Enum.Material.SmoothPlastic, true, true)
					pole.Parent = stall
				end
			end
			-- Pyramid roof: 4 sloped panels meeting at a peak (parts only).
			local roofPeak = Vector3.new(sx, 10, sz)
			for _, dir in ipairs({ Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }) do
				local panel = newPart(
					"StallRoof",
					Vector3.new(7.5, 0.4, 3.8),
					Vector3.new(sx + dir.X * 1.9, 8.4, sz + dir.Z * 1.9),
					COLORS.Red,
					Enum.Material.SmoothPlastic,
					true,
					true
				)
				-- Tilt the panel up toward the peak: the outer edge stays low,
				-- the inner edge rises. (X panels rotate -tilt*dir.X about Z;
				-- Z panels rotate +tilt*dir.Z about X — the signs matter.)
				local tilt = math.atan2(1.6, 1.9)
				if dir.X ~= 0 then
					panel.CFrame = CFrame.new(panel.Position) * CFrame.Angles(0, 0, -tilt * dir.X)
				else
					panel.CFrame = CFrame.new(panel.Position) * CFrame.Angles(tilt * dir.Z, 0, 0)
				end
				panel.Parent = stall
			end
			-- White tip ball on the peak.
			local tip = Instance.new("Part")
			tip.Name = "StallTip"
			tip.Shape = Enum.PartType.Ball
			tip.Size = Vector3.new(1.5, 1.5, 1.5)
			tip.Position = roofPeak
			tip.Color = COLORS.White
			tip.Material = Enum.Material.Neon
			tip.Anchored = true
			tip.CanCollide = false
			tip.Parent = stall
			-- Counter box under the roof.
			local counter = newPart("StallCounter", Vector3.new(6, 2, 1), Vector3.new(sx, 3, sz + 3), COLORS.Yellow, Enum.Material.SmoothPlastic, true, true)
			counter.Parent = stall
		end
	end

	-- Bright "BRAINROT CARNIVAL" entrance sign at the spawn end (z = -105):
	-- two tall posts + a board, big yellow letters on red.
	local signBoard = newPart("EntranceSignBoard", Vector3.new(30, 6, 1), Vector3.new(0, 9, -105), COLORS.Red, Enum.Material.SmoothPlastic, true, true)
	signBoard.Parent = world
	for _, px in ipairs({ -13, 13 }) do
		local post = newPart("EntranceSignPost", Vector3.new(2, 12, 2), Vector3.new(px, 6, -105), COLORS.Yellow, Enum.Material.SmoothPlastic, true, true)
		post.Parent = world
	end
	addTextLabel(signBoard, "BRAINROT CARNIVAL", COLORS.Yellow, COLORS.Red, 64)

	-- String lights: small Neon spheres along both midway edges, y = 6,
	-- every 10 studs, alternating warm yellow / pink / cyan. Slim poles
	-- every 40 studs on each edge hold the "string" up (lights would
	-- otherwise float in mid-air with nothing supporting them).
	local lightColors = { COLORS.Yellow, COLORS.Pink, COLORS.Cyan }
	for side = -1, 1, 2 do
		for _, pz in ipairs({ -80, -40, 0, 40, 80 }) do
			local pole = newPart("StringLightPole", Vector3.new(0.4, 6, 0.4), Vector3.new(side * 11.5, 5, pz), COLORS.White, Enum.Material.SmoothPlastic, true, false)
			pole.Parent = world
		end
		for i = 0, 19 do
			local z = -95 + i * 10
			local light = Instance.new("Part")
			light.Name = "StringLight"
			light.Shape = Enum.PartType.Ball
			light.Size = Vector3.new(0.8, 0.8, 0.8)
			light.Position = Vector3.new(side * 11.5, 6, z)
			light.Color = lightColors[(i % 3) + 1]
			light.Material = Enum.Material.Neon
			light.Anchored = true
			light.CanCollide = false
			light.Parent = world
		end
	end

	-- ------------------------------------------------------------------
	-- SpawnLocation: one pad near the entrance sign, neutral, plain bright.
	-- WHITE on purpose: the pad must NOT look like a booth pad. It used to
	-- be green, and a player standing on it (in front of the entrance sign)
	-- pressed E expecting a Deposit prompt that only exists at their booth.
	-- Booth #4 is the green one; spawn stays neutral white.
	-- ------------------------------------------------------------------
	local spawnPosition = Vector3.new(0, 3, -95)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 2.5, -95)
	spawn.Color = COLORS.White
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = world

	-- ------------------------------------------------------------------
	-- Boundary fence: the baseplate is 512x512 but the play area (booths,
	-- conveyor, stalls, shop, spawn, Ferris wheel) only fills the middle,
	-- so the rest reads as empty unfinished grass. A bright red/white
	-- carnival fence rings the whole play area, tall enough (14) that the
	-- empty grass outside cannot be seen from inside, and an invisible
	-- 20-high barrier just outside it stops any player walking out.
	-- The fence encloses x in [-70, 70], z in [-115, 130]; no booth,
	-- conveyor, stall, spawn or wheel position is moved.
	-- ------------------------------------------------------------------
	local fenceX0, fenceX1 = -70, 70
	local fenceZ0, fenceZ1 = -115, 130
	local fenceHeight = 14
	local fenceY = 2 + fenceHeight / 2 -- baseplate top y = 2
	do
		local panelColors = { COLORS.Red, COLORS.White }
		local function fenceRun(x0, z0, x1, z1)
			local dx, dz = x1 - x0, z1 - z0
			local length = math.max(math.abs(dx), math.abs(dz))
			local count = math.ceil(length / 10)
			local step = length / count
			for i = 1, count do
				local t = (i - 0.5) / count
				local px = x0 + dx * t
				local pz = z0 + dz * t
				local size: Vector3
				if math.abs(dx) >= math.abs(dz) then
					size = Vector3.new(step, fenceHeight, 1)
				else
					size = Vector3.new(1, fenceHeight, step)
				end
				local panel = newPart(
					"FencePanel",
					size,
					Vector3.new(px, fenceY, pz),
					panelColors[((i - 1) % 2) + 1],
					Enum.Material.SmoothPlastic,
					true,
					true
				)
				panel.Parent = world
			end
		end
		fenceRun(fenceX0, fenceZ0, fenceX1, fenceZ0) -- north (entrance side)
		fenceRun(fenceX0, fenceZ1, fenceX1, fenceZ1) -- south (wheel side)
		fenceRun(fenceX0, fenceZ0, fenceX0, fenceZ1) -- west
		fenceRun(fenceX1, fenceZ0, fenceX1, fenceZ1) -- east
		-- Yellow corner posts.
		for _, cx in ipairs({ fenceX0, fenceX1 }) do
			for _, cz in ipairs({ fenceZ0, fenceZ1 }) do
				local post = newPart("FencePost", Vector3.new(2, 16, 2), Vector3.new(cx, 10, cz), COLORS.Yellow, Enum.Material.SmoothPlastic, true, true)
				post.Parent = world
			end
		end
		-- Invisible barrier: same rectangle, 1.5 studs outside the visible
		-- fence, 20 high, so no player can ever walk out to the empty grass.
		local function invisibleWall(name: string, size: Vector3, position: Vector3)
			local wall = Instance.new("Part")
			wall.Name = name
			wall.Size = size
			wall.Position = position
			wall.Color = COLORS.White
			wall.Transparency = 1
			wall.Material = Enum.Material.SmoothPlastic
			wall.Anchored = true
			wall.CanCollide = true
			wall.CanTouch = false
			wall.CanQuery = false
			wall.TopSurface = Enum.SurfaceType.Smooth
			wall.BottomSurface = Enum.SurfaceType.Smooth
			wall.Parent = world
		end
		invisibleWall("FenceBarrierNorth", Vector3.new(144, 20, 1), Vector3.new(0, 12, fenceZ0 - 1.5))
		invisibleWall("FenceBarrierSouth", Vector3.new(144, 20, 1), Vector3.new(0, 12, fenceZ1 + 1.5))
		invisibleWall("FenceBarrierWest", Vector3.new(1, 20, 249), Vector3.new(fenceX0 - 1.5, 12, 7.5))
		invisibleWall("FenceBarrierEast", Vector3.new(1, 20, 249), Vector3.new(fenceX1 + 1.5, 12, 7.5))
	end

	-- ------------------------------------------------------------------
	-- Return table
	-- ------------------------------------------------------------------
	return {
		booths = booths,
		conveyor = {
			start = conveyorStart,
			finish = conveyorFinish,
			waypoints = waypoints,
		},
		spawnPosition = spawnPosition,
		ferrisWheelPosition = ferrisWheelPosition,
		ferrisWheelModel = wheelModel,
	}
end

return WorldBuilder
