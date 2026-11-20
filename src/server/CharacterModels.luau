-- CharacterModels.luau
-- ModuleScript (Server). Builds cute brainrot character models ENTIRELY from
-- parts. No meshes, no assets, no decals. Used by Main.server.luau for the
-- parade, carrying, and pedestal display.
-- Shared contract: BrainrotData lives at ReplicatedStorage.Shared.BrainrotData.
--
-- Every character gets its OWN silhouette built from primitives, so the
-- model reads as its name (a wooden log for Tung Tung Tung Sahur, a shark
-- for Tralalero Tralala, a cat for Meowl, ...) instead of the same generic
-- ball. The colour plumbing is fixed too: BrainrotData stores colours as
-- {r, g, b} 0-1 tables and RARITIES is an array looked up by name, so the
-- old lookups always fell through to gold and every character rendered as
-- a yellow ball.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotData = require(Shared:WaitForChild("BrainrotData"))

local CharacterModels = {}

-- Converts a {r, g, b} 0-1 table (the shape BrainrotData uses) to Color3.
local function tableToColor3(t, fallback)
	if type(t) == "table" and type(t.r) == "number" and type(t.g) == "number" and type(t.b) == "number" then
		return Color3.new(t.r, t.g, t.b)
	end
	return fallback
end

-- Rarity colour: RARITIES is an ARRAY of {name, color, mult} entries, so
-- the entry must be found by name (indexing the array with the name always
-- returned nil and made every character gold).
local function getRarityColor(rarityName)
	if BrainrotData.RARITIES ~= nil and rarityName ~= nil then
		for _, entry in ipairs(BrainrotData.RARITIES) do
			if entry.name == rarityName then
				return tableToColor3(entry.color, Color3.fromRGB(255, 215, 0))
			end
		end
	end
	return Color3.fromRGB(255, 215, 0)
end

local function getCharacterColor(char)
	if char == nil then
		return Color3.fromRGB(255, 170, 0)
	end
	if typeof(char.color) == "Color3" then
		return char.color
	elseif typeof(char.Color) == "Color3" then
		return char.Color
	elseif typeof(char.colour) == "Color3" then
		return char.colour
	elseif type(char.color) == "table" then
		-- BrainrotData stores colour as an {r, g, b} 0-1 table.
		return tableToColor3(char.color, Color3.fromRGB(255, 170, 0))
	elseif type(char.color) == "string" then
		-- A few named colours, otherwise fall back to rarity colour.
		local named = {
			red = Color3.fromRGB(255, 80, 80),
			orange = Color3.fromRGB(255, 165, 0),
			yellow = Color3.fromRGB(255, 220, 0),
			green = Color3.fromRGB(80, 220, 100),
			blue = Color3.fromRGB(80, 160, 255),
			purple = Color3.fromRGB(180, 100, 255),
			pink = Color3.fromRGB(255, 120, 200),
		}
		if named[string.lower(char.color)] ~= nil then
			return named[string.lower(char.color)]
		end
	end
	if char.rarity ~= nil then
		return getRarityColor(char.rarity)
	end
	return Color3.fromRGB(255, 170, 0)
end

-- `rot` is an optional Vector3 of radians (CFrame.Angles). The part's
-- Position is set first, then the rotated CFrame; without `rot` the part
-- stays axis-aligned exactly like before.
local function newPart(name, shape, size, color, position, parent, material, rot)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Position = position
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	if rot ~= nil then
		part.CFrame = CFrame.new(position) * CFrame.Angles(rot.X, rot.Y, rot.Z)
	end
	return part
end

local function setModelParts(model, anchored)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
			descendant.CanCollide = false
		end
	end
end

-- A cylinder lying along Z (a cylinder part's axis is X by default).
local function zCylinder(name, length, diameter, color, position, parent, material)
	return newPart(name, Enum.PartType.Cylinder, Vector3.new(length, diameter, diameter), color, position, parent, material, Vector3.new(0, math.pi / 2, 0))
end

-- A cylinder standing upright (axis along Y).
local function yCylinder(name, height, diameter, color, position, parent, material)
	return newPart(name, Enum.PartType.Cylinder, Vector3.new(height, diameter, diameter), color, position, parent, material, Vector3.new(0, 0, math.pi / 2))
end

-- Face on the +Z front of a head centred at (cx, cy, cz) with radius r:
-- two white eyes with dark pupils and a small dark mouth. `surfaceZ`
-- overrides the z of the face plane (for flat fronts such as a log or a
-- cup, pass the cylinder radius); otherwise the face sits on the ball's
-- curve at 0.82 * r.
local function addFace(model, cx, cy, cz, r, surfaceZ)
	local zFace = surfaceZ or (cz + 0.82 * r)
	local eyeD = 0.45 * r
	local eyeX = 0.45 * r
	local eyeY = 0.20 * r
	newPart("EyeLeft", Enum.PartType.Ball, Vector3.new(eyeD, eyeD, eyeD), Color3.fromRGB(255, 255, 255), Vector3.new(cx - eyeX, cy + eyeY, zFace), model)
	newPart("EyeRight", Enum.PartType.Ball, Vector3.new(eyeD, eyeD, eyeD), Color3.fromRGB(255, 255, 255), Vector3.new(cx + eyeX, cy + eyeY, zFace), model)
	local pupilD = 0.22 * r
	newPart("PupilLeft", Enum.PartType.Ball, Vector3.new(pupilD, pupilD, pupilD), Color3.fromRGB(20, 20, 20), Vector3.new(cx - eyeX, cy + eyeY, zFace + 0.16 * r), model)
	newPart("PupilRight", Enum.PartType.Ball, Vector3.new(pupilD, pupilD, pupilD), Color3.fromRGB(20, 20, 20), Vector3.new(cx + eyeX, cy + eyeY, zFace + 0.16 * r), model)
	newPart("Mouth", Enum.PartType.Block, Vector3.new(0.75 * r, 0.13 * r, 0.1), Color3.fromRGB(40, 20, 20), Vector3.new(cx, cy - 0.33 * r, zFace + 0.12 * r), model)
end

-- A small shark (body along Z, dorsal fin, tail, eyes). (cx, cy, cz) is the
-- body centre; len/diameter set the size. `bowColor` adds a little bow on
-- the head (the shark sisters). Used by Tralalero Tralala and the trios.
local function addShark(model, cx, cy, cz, len, dia, color, bowColor)
	zCylinder("SharkBody", len, dia, color, Vector3.new(cx, cy, cz), model)
	zCylinder("SharkSnout", len * 0.35, dia * 0.8, color, Vector3.new(cx, cy - dia * 0.05, cz + len * 0.55), model)
	newPart("SharkFin", Enum.PartType.Block, Vector3.new(0.12, dia * 0.55, dia * 0.5), color, Vector3.new(cx, cy + dia * 0.55, cz - len * 0.1), model, nil, Vector3.new(-0.5, 0, 0))
	newPart("SharkTailUp", Enum.PartType.Block, Vector3.new(0.12, dia * 0.6, dia * 0.35), color, Vector3.new(cx, cy + dia * 0.3, cz - len * 0.62), model, nil, Vector3.new(0.6, 0, 0))
	newPart("SharkTailDown", Enum.PartType.Block, Vector3.new(0.12, dia * 0.6, dia * 0.35), color, Vector3.new(cx, cy - dia * 0.3, cz - len * 0.62), model, nil, Vector3.new(-0.6, 0, 0))
	local eyeR = dia * 0.16
	newPart("SharkEyeLeft", Enum.PartType.Ball, Vector3.new(eyeR, eyeR, eyeR), Color3.fromRGB(255, 255, 255), Vector3.new(cx - dia * 0.3, cy + dia * 0.18, cz + len * 0.42), model)
	newPart("SharkEyeRight", Enum.PartType.Ball, Vector3.new(eyeR, eyeR, eyeR), Color3.fromRGB(255, 255, 255), Vector3.new(cx + dia * 0.3, cy + dia * 0.18, cz + len * 0.42), model)
	if bowColor ~= nil then
		newPart("SharkBowLeft", Enum.PartType.Block, Vector3.new(dia * 0.3, dia * 0.22, 0.1), bowColor, Vector3.new(cx - dia * 0.25, cy + dia * 0.5, cz + len * 0.3), model, nil, Vector3.new(0, 0, 0.5))
		newPart("SharkBowRight", Enum.PartType.Block, Vector3.new(dia * 0.3, dia * 0.22, 0.1), bowColor, Vector3.new(cx + dia * 0.25, cy + dia * 0.5, cz + len * 0.3), model, nil, Vector3.new(0, 0, -0.5))
	end
end

-- A small crocodile (long flat snout, teeth, stalk eyes, tail).
local function addCroc(model, cx, cy, cz, len, dia, color)
	zCylinder("CrocBody", len, dia, color, Vector3.new(cx, cy, cz), model)
	newPart("CrocSnout", Enum.PartType.Block, Vector3.new(dia * 0.75, dia * 0.32, len * 0.5), color, Vector3.new(cx, cy - dia * 0.05, cz + len * 0.6), model)
	for i = -1, 1 do
		newPart("CrocTooth" .. tostring(i + 2), Enum.PartType.Block, Vector3.new(0.12, 0.16, 0.12), Color3.fromRGB(255, 255, 255), Vector3.new(cx + i * dia * 0.28, cy - dia * 0.18, cz + len * 0.72), model)
	end
	newPart("CrocEyeLeft", Enum.PartType.Ball, Vector3.new(dia * 0.2, dia * 0.2, dia * 0.2), Color3.fromRGB(255, 255, 255), Vector3.new(cx - dia * 0.25, cy + dia * 0.55, cz + len * 0.35), model)
	newPart("CrocEyeRight", Enum.PartType.Ball, Vector3.new(dia * 0.2, dia * 0.2, dia * 0.2), Color3.fromRGB(255, 255, 255), Vector3.new(cx + dia * 0.25, cy + dia * 0.55, cz + len * 0.35), model)
	newPart("CrocTail", Enum.PartType.Block, Vector3.new(dia * 0.5, dia * 0.18, len * 0.45), color, Vector3.new(cx, cy, cz - len * 0.65), model, nil, Vector3.new(0.15, 0, 0))
end

-- A small fish (body along Z, tail, top fin, eyes).
local function addFish(model, cx, cy, cz, len, dia, color)
	zCylinder("FishBody", len, dia, color, Vector3.new(cx, cy, cz), model)
	newPart("FishTail", Enum.PartType.Block, Vector3.new(0.1, dia * 0.7, dia * 0.4), color, Vector3.new(cx, cy, cz - len * 0.6), model)
	newPart("FishFin", Enum.PartType.Block, Vector3.new(0.1, dia * 0.4, dia * 0.4), color, Vector3.new(cx, cy + dia * 0.5, cz), model, nil, Vector3.new(-0.4, 0, 0))
	local eyeR = dia * 0.16
	newPart("FishEyeLeft", Enum.PartType.Ball, Vector3.new(eyeR, eyeR, eyeR), Color3.fromRGB(255, 255, 255), Vector3.new(cx - dia * 0.28, cy + dia * 0.15, cz + len * 0.35), model)
	newPart("FishEyeRight", Enum.PartType.Ball, Vector3.new(eyeR, eyeR, eyeR), Color3.fromRGB(255, 255, 255), Vector3.new(cx + dia * 0.28, cy + dia * 0.15, cz + len * 0.35), model)
end

-- ============================================================================
-- Per-character silhouettes.
-- Every builder takes (model, c) with c the character's data colour and
-- returns the PrimaryPart ("Body"). INVARIANT: Body is always an UNROTATED
-- ball centred at (0, 1.7, 0) — the pedestal / conveyor code places the
-- model by that pivot, so the Body must never be rotated and must stay at
-- that height. For characters whose torso is a rotated cylinder, the Body
-- is a smaller ball hidden inside it. All models stay inside ~3.6 studs
-- wide (pedestals sit 4 apart) and ~5.8 tall (the overhead tag floats at
-- body + 4.6).
-- ============================================================================

local function buildDefault(model, c)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(2.2, 2.2, 2.2), c, Vector3.new(0, 1.7, 0), model)
	newPart("Head", Enum.PartType.Ball, Vector3.new(1.8, 1.8, 1.8), c, Vector3.new(0, 3.3, 0), model)
	addFace(model, 0, 3.3, 0, 0.9)
	newPart("ArmLeft", Enum.PartType.Ball, Vector3.new(0.55, 0.55, 0.55), c, Vector3.new(-1.25, 1.8, 0), model)
	newPart("ArmRight", Enum.PartType.Ball, Vector3.new(0.55, 0.55, 0.55), c, Vector3.new(1.25, 1.8, 0), model)
	newPart("LegLeft", Enum.PartType.Block, Vector3.new(0.45, 0.6, 0.45), Color3.fromRGB(60, 60, 90), Vector3.new(-0.5, 0.35, 0), model)
	newPart("LegRight", Enum.PartType.Block, Vector3.new(0.45, 0.6, 0.45), Color3.fromRGB(60, 60, 90), Vector3.new(0.5, 0.35, 0), model)
	return body
end

-- Tung Tung Tung Sahur: an upright WOODEN LOG with a face, holding a bat.
local function buildTungTung(model, c)
	local wood = Color3.fromRGB(140, 89, 51)
	local woodDark = Color3.fromRGB(110, 68, 34)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.7, 1.7, 1.7), wood, Vector3.new(0, 1.7, 0), model)
	yCylinder("Log", 3.0, 1.7, wood, Vector3.new(0, 1.7, 0), model, Enum.Material.Wood)
	yCylinder("LogTop", 0.12, 1.7, woodDark, Vector3.new(0, 3.22, 0), model, Enum.Material.Wood)
	addFace(model, 0, 2.5, 0, 0.85, 0.85)
	newPart("ArmLeft", Enum.PartType.Cylinder, Vector3.new(1.0, 0.3, 0.3), woodDark, Vector3.new(-1.15, 1.9, 0), model, Enum.Material.Wood)
	newPart("ArmRight", Enum.PartType.Cylinder, Vector3.new(1.0, 0.3, 0.3), woodDark, Vector3.new(1.15, 1.9, 0), model, Enum.Material.Wood)
	newPart("Bat", Enum.PartType.Cylinder, Vector3.new(2.3, 0.34, 0.34), Color3.fromRGB(205, 170, 110), Vector3.new(1.55, 2.6, 0.25), model, Enum.Material.Wood, Vector3.new(0.5, 0, -0.55))
	newPart("LegLeft", Enum.PartType.Block, Vector3.new(0.45, 0.5, 0.6), woodDark, Vector3.new(-0.45, 0.25, 0.1), model)
	newPart("LegRight", Enum.PartType.Block, Vector3.new(0.45, 0.5, 0.6), woodDark, Vector3.new(0.45, 0.25, 0.1), model)
	return body
end

-- Chimpanzini Bananini: a yellow banana body with a chimp head, ears, tail.
local function buildChimpanzini(model, c)
	local brown = Color3.fromRGB(115, 77, 46)
	local tan = Color3.fromRGB(210, 170, 120)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.3, 2.6, 1.3), c, Vector3.new(0, 1.7, 0), model)
	newPart("BananaTip", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), brown, Vector3.new(0, 3.15, 0), model)
	newPart("Head", Enum.PartType.Ball, Vector3.new(1.2, 1.2, 1.2), brown, Vector3.new(0, 3.1, 0.25), model)
	newPart("EarLeft", Enum.PartType.Ball, Vector3.new(0.45, 0.45, 0.45), brown, Vector3.new(-0.65, 3.15, 0.2), model)
	newPart("EarRight", Enum.PartType.Ball, Vector3.new(0.45, 0.45, 0.45), brown, Vector3.new(0.65, 3.15, 0.2), model)
	newPart("FacePatch", Enum.PartType.Ball, Vector3.new(0.9, 0.7, 0.4), tan, Vector3.new(0, 3.0, 0.75), model)
	newPart("EyeLeft", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), Color3.fromRGB(255, 255, 255), Vector3.new(-0.22, 3.25, 0.95), model)
	newPart("EyeRight", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), Color3.fromRGB(255, 255, 255), Vector3.new(0.22, 3.25, 0.95), model)
	newPart("PupilLeft", Enum.PartType.Ball, Vector3.new(0.1, 0.1, 0.1), Color3.fromRGB(20, 20, 20), Vector3.new(-0.22, 3.25, 1.03), model)
	newPart("PupilRight", Enum.PartType.Ball, Vector3.new(0.1, 0.1, 0.1), Color3.fromRGB(20, 20, 20), Vector3.new(0.22, 3.25, 1.03), model)
	newPart("Mouth", Enum.PartType.Block, Vector3.new(0.4, 0.08, 0.06), Color3.fromRGB(40, 20, 20), Vector3.new(0, 2.9, 0.97), model)
	newPart("ArmLeft", Enum.PartType.Cylinder, Vector3.new(0.9, 0.28, 0.28), brown, Vector3.new(-1.0, 1.9, 0), model)
	newPart("ArmRight", Enum.PartType.Cylinder, Vector3.new(0.9, 0.28, 0.28), brown, Vector3.new(1.0, 1.9, 0), model)
	newPart("LegLeft", Enum.PartType.Block, Vector3.new(0.4, 0.5, 0.4), brown, Vector3.new(-0.4, 0.25, 0), model)
	newPart("LegRight", Enum.PartType.Block, Vector3.new(0.4, 0.5, 0.4), brown, Vector3.new(0.4, 0.25, 0), model)
	newPart("Tail", Enum.PartType.Cylinder, Vector3.new(1.2, 0.22, 0.22), brown, Vector3.new(0, 1.9, -0.9), model, nil, Vector3.new(0.7, 0, 0))
	return body
end

-- Lirili Larila: a cactus-elephant — big ears, trunk, cactus spines on top.
local function buildLirili(model, c)
	local green = Color3.fromRGB(50, 180, 80)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(2.2, 2.2, 2.2), c, Vector3.new(0, 1.7, 0), model)
	newPart("Head", Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5), c, Vector3.new(0, 2.9, 0.85), model)
	addFace(model, 0, 2.9, 0.85, 0.75)
	newPart("EarLeft", Enum.PartType.Cylinder, Vector3.new(0.18, 1.1, 1.1), c, Vector3.new(-0.95, 3.0, 0.7), model, nil, Vector3.new(0, 0, math.pi / 2))
	newPart("EarRight", Enum.PartType.Cylinder, Vector3.new(0.18, 1.1, 1.1), c, Vector3.new(0.95, 3.0, 0.7), model, nil, Vector3.new(0, 0, math.pi / 2))
	yCylinder("TrunkUpper", 0.9, 0.5, c, Vector3.new(0, 2.3, 1.55), model)
	yCylinder("TrunkLower", 0.8, 0.38, c, Vector3.new(0, 1.65, 1.6), model)
	newPart("Spine1", Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3), green, Vector3.new(-0.6, 3.0, -0.6), model)
	newPart("Spine2", Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3), green, Vector3.new(0.2, 3.2, -0.7), model)
	newPart("Spine3", Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3), green, Vector3.new(0.8, 2.9, -0.5), model)
	yCylinder("LegFL", 0.9, 0.5, c, Vector3.new(-0.6, 0.45, 0.6), model)
	yCylinder("LegFR", 0.9, 0.5, c, Vector3.new(0.6, 0.45, 0.6), model)
	yCylinder("LegBL", 0.9, 0.5, c, Vector3.new(-0.6, 0.45, -0.6), model)
	yCylinder("LegBR", 0.9, 0.5, c, Vector3.new(0.6, 0.45, -0.6), model)
	return body
end

-- Boneca Ambalabu: a pink doll in a dress with big hair and buns.
local function buildBoneca(model, c)
	local pinkDark = Color3.fromRGB(217, 102, 140)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.3, 1.3, 1.3), c, Vector3.new(0, 1.7, 0), model)
	yCylinder("Torso", 1.4, 1.3, c, Vector3.new(0, 1.7, 0), model)
	yCylinder("Dress", 0.35, 3.0, pinkDark, Vector3.new(0, 0.75, 0), model)
	newPart("Head", Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4), c, Vector3.new(0, 3.0, 0), model)
	addFace(model, 0, 3.0, 0, 0.7)
	newPart("Hair", Enum.PartType.Ball, Vector3.new(1.9, 1.9, 1.9), pinkDark, Vector3.new(0, 3.5, -0.4), model)
	newPart("BunLeft", Enum.PartType.Ball, Vector3.new(0.6, 0.6, 0.6), pinkDark, Vector3.new(-0.95, 3.7, -0.1), model)
	newPart("BunRight", Enum.PartType.Ball, Vector3.new(0.6, 0.6, 0.6), pinkDark, Vector3.new(0.95, 3.7, -0.1), model)
	newPart("ArmLeft", Enum.PartType.Cylinder, Vector3.new(1.0, 0.25, 0.25), c, Vector3.new(-1.0, 2.0, 0), model, nil, Vector3.new(0, 0, 0.5))
	newPart("ArmRight", Enum.PartType.Cylinder, Vector3.new(1.0, 0.25, 0.25), c, Vector3.new(1.0, 2.0, 0), model, nil, Vector3.new(0, 0, -0.5))
	newPart("ShoeLeft", Enum.PartType.Ball, Vector3.new(0.4, 0.4, 0.4), pinkDark, Vector3.new(-0.4, 0.2, 0.3), model)
	newPart("ShoeRight", Enum.PartType.Ball, Vector3.new(0.4, 0.4, 0.4), pinkDark, Vector3.new(0.4, 0.2, 0.3), model)
	return body
end

-- Tralalero Tralala: a blue shark in white sneakers.
local function buildTralalero(model, c)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4), c, Vector3.new(0, 1.7, 0), model)
	addShark(model, 0, 1.7, 0, 2.6, 1.5, c)
	newPart("Belly", Enum.PartType.Ball, Vector3.new(1.1, 0.6, 1.9), Color3.fromRGB(255, 255, 255), Vector3.new(0, 1.3, 0.2), model)
	newPart("SneakerLeft", Enum.PartType.Block, Vector3.new(0.6, 0.35, 0.9), Color3.fromRGB(255, 255, 255), Vector3.new(-0.45, 0.25, 0.7), model)
	newPart("SneakerRight", Enum.PartType.Block, Vector3.new(0.6, 0.35, 0.9), Color3.fromRGB(255, 255, 255), Vector3.new(0.45, 0.25, 0.7), model)
	newPart("SoleLeft", Enum.PartType.Block, Vector3.new(0.62, 0.12, 0.92), c, Vector3.new(-0.45, 0.08, 0.7), model)
	newPart("SoleRight", Enum.PartType.Block, Vector3.new(0.62, 0.12, 0.92), c, Vector3.new(0.45, 0.08, 0.7), model)
	newPart("FinLeft", Enum.PartType.Block, Vector3.new(0.7, 0.1, 0.5), c, Vector3.new(-1.0, 1.4, 0.3), model, nil, Vector3.new(0, 0, 0.4))
	newPart("FinRight", Enum.PartType.Block, Vector3.new(0.7, 0.1, 0.5), c, Vector3.new(1.0, 1.4, 0.3), model, nil, Vector3.new(0, 0, -0.4))
	return body
end

-- Brr Brr Patapim: a monkey whose long nose is a little tree, with a tree
-- growing on his head too.
local function buildPatapim(model, c)
	local brown = Color3.fromRGB(115, 82, 51)
	local green = Color3.fromRGB(64, 153, 64)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(2.0, 2.0, 2.0), c, Vector3.new(0, 1.7, 0), model)
	newPart("Head", Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5), c, Vector3.new(0, 3.0, 0), model)
	addFace(model, 0, 3.0, 0, 0.75)
	yCylinder("Nose", 1.1, 0.3, brown, Vector3.new(0, 2.35, 0.8), model)
	newPart("NoseLeaf", Enum.PartType.Ball, Vector3.new(0.35, 0.35, 0.35), green, Vector3.new(0, 1.75, 0.8), model)
	yCylinder("TreeTrunk", 0.5, 0.22, brown, Vector3.new(0, 3.95, 0), model)
	newPart("TreeTop", Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), green, Vector3.new(0, 4.35, 0), model)
	newPart("EarLeft", Enum.PartType.Ball, Vector3.new(0.4, 0.4, 0.4), brown, Vector3.new(-0.8, 3.1, 0), model)
	newPart("EarRight", Enum.PartType.Ball, Vector3.new(0.4, 0.4, 0.4), brown, Vector3.new(0.8, 3.1, 0), model)
	yCylinder("ArmLeft", 1.6, 0.28, c, Vector3.new(-1.15, 1.3, 0), model)
	yCylinder("ArmRight", 1.6, 0.28, c, Vector3.new(1.15, 1.3, 0), model)
	newPart("LegLeft", Enum.PartType.Block, Vector3.new(0.4, 0.5, 0.4), brown, Vector3.new(-0.45, 0.25, 0), model)
	newPart("LegRight", Enum.PartType.Block, Vector3.new(0.4, 0.5, 0.4), brown, Vector3.new(0.45, 0.25, 0), model)
	return body
end

-- La Vaca Saturno Saturnita: a cream cow wearing Saturn's ring.
local function buildVaca(model, c)
	local pink = Color3.fromRGB(255, 179, 191)
	local gold = Color3.fromRGB(255, 220, 130)
	local black = Color3.fromRGB(30, 30, 30)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4), c, Vector3.new(0, 1.7, 0), model)
	zCylinder("CowBody", 2.2, 1.5, c, Vector3.new(0, 1.7, 0), model)
	newPart("Spot1", Enum.PartType.Ball, Vector3.new(0.5, 0.3, 0.7), black, Vector3.new(-0.4, 2.35, -0.4), model)
	newPart("Spot2", Enum.PartType.Ball, Vector3.new(0.5, 0.3, 0.7), black, Vector3.new(0.5, 2.3, 0.5), model)
	newPart("Spot3", Enum.PartType.Ball, Vector3.new(0.45, 0.3, 0.6), black, Vector3.new(0, 2.4, -0.7), model)
	newPart("Head", Enum.PartType.Ball, Vector3.new(1.3, 1.3, 1.3), c, Vector3.new(0, 2.2, 1.3), model)
	addFace(model, 0, 2.2, 1.3, 0.65)
	newPart("Muzzle", Enum.PartType.Block, Vector3.new(0.8, 0.45, 0.4), pink, Vector3.new(0, 1.95, 1.9), model)
	yCylinder("HornLeft", 0.5, 0.18, Color3.fromRGB(255, 255, 255), Vector3.new(-0.45, 3.0, 1.3), model, nil, Vector3.new(0, 0, 0.3))
	yCylinder("HornRight", 0.5, 0.18, Color3.fromRGB(255, 255, 255), Vector3.new(0.45, 3.0, 1.3), model, nil, Vector3.new(0, 0, -0.3))
	newPart("EarLeft", Enum.PartType.Ball, Vector3.new(0.5, 0.35, 0.2), c, Vector3.new(-0.7, 2.4, 1.3), model)
	newPart("EarRight", Enum.PartType.Ball, Vector3.new(0.5, 0.35, 0.2), c, Vector3.new(0.7, 2.4, 1.3), model)
	yCylinder("LegFL", 0.9, 0.45, c, Vector3.new(-0.55, 0.45, 0.6), model)
	yCylinder("LegFR", 0.9, 0.45, c, Vector3.new(0.55, 0.45, 0.6), model)
	yCylinder("LegBL", 0.9, 0.45, c, Vector3.new(-0.55, 0.45, -0.6), model)
	yCylinder("LegBR", 0.9, 0.45, c, Vector3.new(0.55, 0.45, -0.6), model)
	newPart("Udder", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), pink, Vector3.new(0, 1.0, -0.4), model)
	local ring = yCylinder("SaturnRing", 0.1, 3.4, gold, Vector3.new(0, 1.7, 0), model)
	ring.CFrame = CFrame.new(0, 1.7, 0) * CFrame.Angles(0.35, 0, 0.15)
	ring.Transparency = 0.15
	return body
end

-- Frigo Camelo: a camel that is also a fridge — humps, long neck, and a
-- white fridge door with a handle on its side.
local function buildFrigo(model, c)
	local white = Color3.fromRGB(255, 255, 255)
	local grey = Color3.fromRGB(150, 150, 150)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4), c, Vector3.new(0, 1.7, 0), model)
	zCylinder("CamelBody", 2.2, 1.5, c, Vector3.new(0, 1.7, 0), model)
	newPart("HumpBack", Enum.PartType.Ball, Vector3.new(1.0, 1.0, 1.0), c, Vector3.new(0, 2.55, -0.5), model)
	newPart("HumpFront", Enum.PartType.Ball, Vector3.new(1.0, 1.0, 1.0), c, Vector3.new(0, 2.55, 0.5), model)
	newPart("Neck", Enum.PartType.Cylinder, Vector3.new(1.4, 0.6, 0.6), c, Vector3.new(0, 2.5, 1.2), model, nil, Vector3.new(-0.6, 0, 0))
	newPart("Head", Enum.PartType.Ball, Vector3.new(1.1, 1.1, 1.1), c, Vector3.new(0, 3.15, 1.75), model)
	addFace(model, 0, 3.15, 1.75, 0.55)
	yCylinder("LegFL", 1.1, 0.4, c, Vector3.new(-0.55, 0.55, 0.6), model)
	yCylinder("LegFR", 1.1, 0.4, c, Vector3.new(0.55, 0.55, 0.6), model)
	yCylinder("LegBL", 1.1, 0.4, c, Vector3.new(-0.55, 0.55, -0.6), model)
	yCylinder("LegBR", 1.1, 0.4, c, Vector3.new(0.55, 0.55, -0.6), model)
	newPart("FridgeDoor", Enum.PartType.Block, Vector3.new(0.12, 1.3, 1.5), white, Vector3.new(-0.78, 1.7, 0), model)
	newPart("FridgeHandle", Enum.PartType.Block, Vector3.new(0.1, 0.7, 0.12), grey, Vector3.new(-0.86, 1.7, 0.6), model)
	newPart("Tail", Enum.PartType.Cylinder, Vector3.new(0.9, 0.2, 0.2), c, Vector3.new(0, 1.9, -1.3), model, nil, Vector3.new(0.5, 0, 0))
	return body
end

-- Bombardiro Crocodilo: a bomber crocodile — long snout, teeth, wings.
local function buildBombardiro(model, c)
	local wing = Color3.fromRGB(128, 153, 128)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.3, 1.3, 1.3), c, Vector3.new(0, 1.7, 0), model)
	addCroc(model, 0, 1.7, 0, 2.6, 1.3, c)
	newPart("WingLeft", Enum.PartType.Block, Vector3.new(1.2, 0.1, 0.9), wing, Vector3.new(-1.25, 1.95, -0.2), model, nil, Vector3.new(0, 0, 0.12))
	newPart("WingRight", Enum.PartType.Block, Vector3.new(1.2, 0.1, 0.9), wing, Vector3.new(1.25, 1.95, -0.2), model, nil, Vector3.new(0, 0, -0.12))
	newPart("LegFL", Enum.PartType.Block, Vector3.new(0.35, 0.5, 0.35), c, Vector3.new(-0.5, 0.3, 0.6), model)
	newPart("LegFR", Enum.PartType.Block, Vector3.new(0.35, 0.5, 0.35), c, Vector3.new(0.5, 0.3, 0.6), model)
	newPart("LegBL", Enum.PartType.Block, Vector3.new(0.35, 0.5, 0.35), c, Vector3.new(-0.5, 0.3, -0.6), model)
	newPart("LegBR", Enum.PartType.Block, Vector3.new(0.35, 0.5, 0.35), c, Vector3.new(0.5, 0.3, -0.6), model)
	return body
end

-- Ballerina Cappuccina: a ballerina whose head is a cappuccino cup.
local function buildBallerina(model, c)
	local white = Color3.fromRGB(255, 255, 255)
	local pink = Color3.fromRGB(255, 179, 204)
	local tan = Color3.fromRGB(217, 166, 115)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.3, 1.3, 1.3), c, Vector3.new(0, 1.7, 0), model)
	yCylinder("Torso", 1.6, 1.3, c, Vector3.new(0, 1.7, 0), model)
	yCylinder("Tutu", 0.22, 3.0, pink, Vector3.new(0, 1.15, 0), model)
	yCylinder("LegLeft", 0.9, 0.3, c, Vector3.new(-0.35, 0.45, 0), model)
	yCylinder("LegRight", 0.9, 0.3, c, Vector3.new(0.35, 0.45, 0), model)
	newPart("ArmLeft", Enum.PartType.Cylinder, Vector3.new(1.1, 0.25, 0.25), c, Vector3.new(-0.95, 2.7, 0), model, nil, Vector3.new(0, 0, 0.9))
	newPart("ArmRight", Enum.PartType.Cylinder, Vector3.new(1.1, 0.25, 0.25), c, Vector3.new(0.95, 2.7, 0), model, nil, Vector3.new(0, 0, -0.9))
	yCylinder("Cup", 1.0, 1.3, tan, Vector3.new(0, 3.0, 0), model)
	newPart("Foam", Enum.PartType.Ball, Vector3.new(1.2, 0.45, 1.2), white, Vector3.new(0, 3.55, 0), model)
	newPart("CupHandle", Enum.PartType.Block, Vector3.new(0.25, 0.5, 0.15), white, Vector3.new(0.72, 3.0, 0), model)
	newPart("Cherry", Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3), pink, Vector3.new(0.4, 3.8, 0.2), model)
	addFace(model, 0, 3.0, 0, 0.65, 0.65)
	return body
end

-- Trippi Troppi: three little fish swimming in a row.
local function buildTrippi(model, c)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.0, 1.0, 1.0), c, Vector3.new(0, 1.7, 0), model)
	addFish(model, 0, 1.7, 0, 1.6, 1.0, c)
	addFish(model, -1.1, 1.55, -0.35, 1.1, 0.7, c)
	addFish(model, 1.1, 1.55, -0.35, 1.1, 0.7, c)
	return body
end

-- Cappuccino Assassino: a dark coffee cup in a ninja headband, katana on
-- its back.
local function buildAssassino(model, c)
	local cream = Color3.fromRGB(245, 230, 200)
	local red = Color3.fromRGB(204, 26, 38)
	local grey = Color3.fromRGB(180, 180, 190)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), c, Vector3.new(0, 1.7, 0), model)
	yCylinder("Cup", 2.2, 1.7, c, Vector3.new(0, 1.7, 0), model)
	newPart("Foam", Enum.PartType.Ball, Vector3.new(1.5, 0.45, 1.5), cream, Vector3.new(0, 2.85, 0), model)
	newPart("CupHandle", Enum.PartType.Block, Vector3.new(0.25, 0.6, 0.15), c, Vector3.new(0.92, 1.9, 0), model)
	newPart("Headband", Enum.PartType.Block, Vector3.new(1.75, 0.28, 0.12), red, Vector3.new(0, 2.35, 0.82), model)
	newPart("BandTail1", Enum.PartType.Block, Vector3.new(0.8, 0.18, 0.08), red, Vector3.new(-0.9, 2.3, -0.3), model, nil, Vector3.new(0, 0.5, 0.2))
	newPart("BandTail2", Enum.PartType.Block, Vector3.new(0.8, 0.18, 0.08), red, Vector3.new(-1.0, 2.15, -0.5), model, nil, Vector3.new(0, 0.7, -0.1))
	newPart("EyeLeft", Enum.PartType.Block, Vector3.new(0.35, 0.12, 0.08), Color3.fromRGB(255, 255, 255), Vector3.new(-0.3, 2.6, 0.85), model)
	newPart("EyeRight", Enum.PartType.Block, Vector3.new(0.35, 0.12, 0.08), Color3.fromRGB(255, 255, 255), Vector3.new(0.3, 2.6, 0.85), model)
	newPart("Katana", Enum.PartType.Block, Vector3.new(0.1, 2.2, 0.14), grey, Vector3.new(0.6, 2.4, -0.95), model, nil, Vector3.new(0, 0, -0.4))
	yCylinder("ArmLeft", 1.0, 0.28, c, Vector3.new(-1.0, 1.8, 0), model)
	yCylinder("ArmRight", 1.0, 0.28, c, Vector3.new(1.0, 1.8, 0), model)
	return body
end

-- Giraffa Celeste: a long-necked yellow space giraffe with star sparkles.
local function buildGiraffa(model, c)
	local brown = Color3.fromRGB(128, 82, 38)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.3, 1.3, 1.3), c, Vector3.new(0, 1.7, 0), model)
	zCylinder("GiraffeBody", 1.8, 1.3, c, Vector3.new(0, 1.7, 0), model)
	newPart("Spot1", Enum.PartType.Ball, Vector3.new(0.35, 0.35, 0.35), brown, Vector3.new(-0.5, 2.3, 0.3), model)
	newPart("Spot2", Enum.PartType.Ball, Vector3.new(0.35, 0.35, 0.35), brown, Vector3.new(0.4, 2.35, -0.4), model)
	newPart("Spot3", Enum.PartType.Ball, Vector3.new(0.35, 0.35, 0.35), brown, Vector3.new(0, 2.2, 0.8), model)
	newPart("Spot4", Enum.PartType.Ball, Vector3.new(0.35, 0.35, 0.35), brown, Vector3.new(-0.3, 2.25, -0.8), model)
	yCylinder("Neck", 2.6, 0.6, c, Vector3.new(0, 3.6, 0.9), model)
	newPart("Head", Enum.PartType.Ball, Vector3.new(0.9, 0.9, 0.9), c, Vector3.new(0, 5.1, 0.9), model)
	addFace(model, 0, 5.1, 0.9, 0.45)
	yCylinder("OssiconeLeft", 0.4, 0.14, c, Vector3.new(-0.25, 5.6, 0.9), model)
	yCylinder("OssiconeRight", 0.4, 0.14, c, Vector3.new(0.25, 5.6, 0.9), model)
	newPart("OssiconeTipLeft", Enum.PartType.Ball, Vector3.new(0.16, 0.16, 0.16), brown, Vector3.new(-0.25, 5.85, 0.9), model)
	newPart("OssiconeTipRight", Enum.PartType.Ball, Vector3.new(0.16, 0.16, 0.16), brown, Vector3.new(0.25, 5.85, 0.9), model)
	yCylinder("LegFL", 1.1, 0.35, c, Vector3.new(-0.5, 0.55, 0.55), model)
	yCylinder("LegFR", 1.1, 0.35, c, Vector3.new(0.5, 0.55, 0.55), model)
	yCylinder("LegBL", 1.1, 0.35, c, Vector3.new(-0.5, 0.55, -0.55), model)
	yCylinder("LegBR", 1.1, 0.35, c, Vector3.new(0.5, 0.55, -0.55), model)
	newPart("Star1", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), Color3.fromRGB(255, 255, 255), Vector3.new(0.9, 4.2, 1.3), model, Enum.Material.Neon)
	newPart("Star2", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), Color3.fromRGB(150, 200, 255), Vector3.new(-0.8, 3.6, 0.6), model, Enum.Material.Neon)
	newPart("Star3", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), Color3.fromRGB(255, 255, 255), Vector3.new(0.6, 4.7, 0.5), model, Enum.Material.Neon)
	return body
end

-- Los Tralaleritos: three little blue sharks in a row.
local function buildTralaleritos(model, c)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(0.85, 0.85, 0.85), c, Vector3.new(0, 1.7, 0), model)
	addShark(model, 0, 1.7, 0, 1.5, 0.9, c)
	addShark(model, -1.05, 1.6, -0.2, 1.3, 0.8, c)
	addShark(model, 1.05, 1.6, -0.2, 1.3, 0.8, c)
	return body
end

-- Las Tralaleritas: three little pink sharks, each with a bow.
local function buildTralaleritas(model, c)
	local bow = Color3.fromRGB(255, 77, 153)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(0.85, 0.85, 0.85), c, Vector3.new(0, 1.7, 0), model)
	addShark(model, 0, 1.7, 0, 1.5, 0.9, c, bow)
	addShark(model, -1.05, 1.6, -0.2, 1.3, 0.8, c, bow)
	addShark(model, 1.05, 1.6, -0.2, 1.3, 0.8, c, bow)
	return body
end

-- Matteo: just a guy — purple hoodie, cap, plain and confident.
local function buildMatteo(model, c)
	local skin = Color3.fromRGB(242, 191, 140)
	local dark = Color3.fromRGB(40, 40, 60)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5), c, Vector3.new(0, 1.7, 0), model)
	yCylinder("Hoodie", 1.8, 1.5, c, Vector3.new(0, 1.7, 0), model)
	newPart("Head", Enum.PartType.Ball, Vector3.new(1.3, 1.3, 1.3), skin, Vector3.new(0, 3.0, 0), model)
	addFace(model, 0, 3.0, 0, 0.65)
	yCylinder("Cap", 0.22, 1.5, c, Vector3.new(0, 3.62, 0), model)
	newPart("CapBrim", Enum.PartType.Block, Vector3.new(1.0, 0.1, 0.6), c, Vector3.new(0, 3.58, 0.7), model)
	yCylinder("ArmLeft", 1.2, 0.3, c, Vector3.new(-0.95, 1.8, 0), model)
	yCylinder("ArmRight", 1.2, 0.3, c, Vector3.new(0.95, 1.8, 0), model)
	newPart("LegLeft", Enum.PartType.Block, Vector3.new(0.45, 0.9, 0.45), dark, Vector3.new(-0.4, 0.45, 0), model)
	newPart("LegRight", Enum.PartType.Block, Vector3.new(0.45, 0.9, 0.45), dark, Vector3.new(0.4, 0.45, 0), model)
	return body
end

-- Pot Hotspot: a steaming hot pot with a face.
local function buildPotHotspot(model, c)
	local darkRed = Color3.fromRGB(179, 51, 26)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.8, 1.8, 1.8), c, Vector3.new(0, 1.7, 0), model)
	yCylinder("Pot", 1.6, 2.0, c, Vector3.new(0, 1.7, 0), model)
	yCylinder("Rim", 0.25, 2.2, darkRed, Vector3.new(0, 2.55, 0), model)
	newPart("HandleLeft", Enum.PartType.Block, Vector3.new(0.3, 0.3, 0.5), darkRed, Vector3.new(-1.1, 2.1, 0), model)
	newPart("HandleRight", Enum.PartType.Block, Vector3.new(0.3, 0.3, 0.5), darkRed, Vector3.new(1.1, 2.1, 0), model)
	local steam1 = newPart("Steam1", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(255, 255, 255), Vector3.new(-0.4, 3.2, 0), model)
	steam1.Transparency = 0.5
	local steam2 = newPart("Steam2", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(255, 255, 255), Vector3.new(0.3, 3.5, 0.1), model)
	steam2.Transparency = 0.5
	local steam3 = newPart("Steam3", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(255, 255, 255), Vector3.new(0, 3.8, -0.1), model)
	steam3.Transparency = 0.5
	addFace(model, 0, 2.0, 0, 0.8, 1.0)
	newPart("Leg1", Enum.PartType.Block, Vector3.new(0.35, 0.4, 0.35), darkRed, Vector3.new(0, 0.2, 0.7), model)
	newPart("Leg2", Enum.PartType.Block, Vector3.new(0.35, 0.4, 0.35), darkRed, Vector3.new(-0.6, 0.2, -0.4), model)
	newPart("Leg3", Enum.PartType.Block, Vector3.new(0.35, 0.4, 0.35), darkRed, Vector3.new(0.6, 0.2, -0.4), model)
	return body
end

-- Graipuss Medussi: a cluster of grapes with snake hair.
local function buildGraipuss(model, c)
	local purple = Color3.fromRGB(153, 77, 204)
	local darkGreen = Color3.fromRGB(51, 128, 51)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.1, 1.1, 1.1), c, Vector3.new(0, 1.7, 0), model)
	newPart("GrapeBL", Enum.PartType.Ball, Vector3.new(1.0, 1.0, 1.0), purple, Vector3.new(-0.85, 1.35, 0.1), model)
	newPart("GrapeBR", Enum.PartType.Ball, Vector3.new(1.0, 1.0, 1.0), c, Vector3.new(0.85, 1.35, -0.1), model)
	newPart("GrapeML", Enum.PartType.Ball, Vector3.new(1.0, 1.0, 1.0), c, Vector3.new(-0.45, 2.35, 0.1), model)
	newPart("GrapeMR", Enum.PartType.Ball, Vector3.new(1.0, 1.0, 1.0), c, Vector3.new(0.45, 2.35, -0.1), model)
	newPart("GrapeTop", Enum.PartType.Ball, Vector3.new(1.0, 1.0, 1.0), c, Vector3.new(0, 2.9, 0), model)
	addFace(model, 0, 1.7, 0, 0.55)
	yCylinder("Snake1", 0.9, 0.18, darkGreen, Vector3.new(0, 3.4, 0), model)
	yCylinder("Snake2", 0.9, 0.18, darkGreen, Vector3.new(0.35, 3.35, 0.15), model, nil, Vector3.new(0, 0, -0.4))
	yCylinder("Snake3", 0.9, 0.18, darkGreen, Vector3.new(-0.35, 3.35, 0.15), model, nil, Vector3.new(0, 0, 0.4))
	yCylinder("Snake4", 0.9, 0.18, darkGreen, Vector3.new(0.3, 3.3, -0.2), model, nil, Vector3.new(0.4, 0, 0))
	yCylinder("Snake5", 0.9, 0.18, darkGreen, Vector3.new(-0.3, 3.3, -0.2), model, nil, Vector3.new(-0.4, 0, 0))
	newPart("SnakeHead1", Enum.PartType.Ball, Vector3.new(0.2, 0.2, 0.2), darkGreen, Vector3.new(0, 3.9, 0), model)
	newPart("SnakeHead2", Enum.PartType.Ball, Vector3.new(0.2, 0.2, 0.2), darkGreen, Vector3.new(0.52, 3.8, 0.15), model)
	newPart("SnakeHead3", Enum.PartType.Ball, Vector3.new(0.2, 0.2, 0.2), darkGreen, Vector3.new(-0.52, 3.8, 0.15), model)
	return body
end

-- La Grande Combinazione: a golden safe with a combination dial and crown.
local function buildCombinazione(model, c)
	local darkGold = Color3.fromRGB(153, 115, 26)
	local dark = Color3.fromRGB(40, 40, 40)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5), c, Vector3.new(0, 1.7, 0), model)
	newPart("Safe", Enum.PartType.Block, Vector3.new(2.2, 2.4, 1.6), c, Vector3.new(0, 1.7, 0), model)
	zCylinder("Dial", 0.15, 1.0, darkGold, Vector3.new(0, 2.0, 0.85), model)
	newPart("DialPointer", Enum.PartType.Block, Vector3.new(0.1, 0.4, 0.06), dark, Vector3.new(0, 2.35, 0.95), model)
	newPart("Handle", Enum.PartType.Cylinder, Vector3.new(0.7, 0.2, 0.2), darkGold, Vector3.new(0.75, 1.35, 0.88), model)
	newPart("FootFL", Enum.PartType.Block, Vector3.new(0.4, 0.3, 0.4), dark, Vector3.new(-0.85, 0.15, 0.55), model)
	newPart("FootFR", Enum.PartType.Block, Vector3.new(0.4, 0.3, 0.4), dark, Vector3.new(0.85, 0.15, 0.55), model)
	newPart("FootBL", Enum.PartType.Block, Vector3.new(0.4, 0.3, 0.4), dark, Vector3.new(-0.85, 0.15, -0.55), model)
	newPart("FootBR", Enum.PartType.Block, Vector3.new(0.4, 0.3, 0.4), dark, Vector3.new(0.85, 0.15, -0.55), model)
	newPart("EyeLeft", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), Color3.fromRGB(255, 220, 0), Vector3.new(-0.35, 2.85, 0.82), model, Enum.Material.Neon)
	newPart("EyeRight", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), Color3.fromRGB(255, 220, 0), Vector3.new(0.35, 2.85, 0.82), model, Enum.Material.Neon)
	newPart("CrownBase", Enum.PartType.Block, Vector3.new(1.0, 0.15, 0.5), c, Vector3.new(0, 2.95, 0), model)
	yCylinder("CrownLeft", 0.35, 0.16, c, Vector3.new(-0.4, 3.05, 0), model)
	yCylinder("CrownMid", 0.35, 0.16, c, Vector3.new(0, 3.12, 0), model)
	yCylinder("CrownRight", 0.35, 0.16, c, Vector3.new(0.4, 3.05, 0), model)
	return body
end

-- Nuclearo Dinossauro: a bright-green radioactive dino with glowing spikes.
local function buildNuclearo(model, c)
	local neonGreen = Color3.fromRGB(128, 255, 102)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.3, 1.3, 1.3), c, Vector3.new(0, 1.7, 0), model)
	zCylinder("DinoBody", 2.2, 1.4, c, Vector3.new(0, 1.7, 0), model)
	newPart("Head", Enum.PartType.Ball, Vector3.new(1.2, 1.2, 1.2), c, Vector3.new(0, 2.1, 1.3), model)
	newPart("Snout", Enum.PartType.Block, Vector3.new(0.8, 0.5, 0.7), c, Vector3.new(0, 1.95, 1.9), model)
	newPart("ToothLeft", Enum.PartType.Block, Vector3.new(0.15, 0.15, 0.1), Color3.fromRGB(255, 255, 255), Vector3.new(-0.25, 1.7, 2.15), model)
	newPart("ToothRight", Enum.PartType.Block, Vector3.new(0.15, 0.15, 0.1), Color3.fromRGB(255, 255, 255), Vector3.new(0.25, 1.7, 2.15), model)
	addFace(model, 0, 2.1, 1.3, 0.6)
	newPart("Tail", Enum.PartType.Block, Vector3.new(0.6, 0.4, 1.4), c, Vector3.new(0, 1.7, -1.6), model, nil, Vector3.new(0.15, 0, 0))
	newPart("Spike1", Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3), neonGreen, Vector3.new(0, 2.5, 0.6), model, Enum.Material.Neon)
	newPart("Spike2", Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3), neonGreen, Vector3.new(0, 2.55, 0), model, Enum.Material.Neon)
	newPart("Spike3", Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3), neonGreen, Vector3.new(0, 2.5, -0.6), model, Enum.Material.Neon)
	newPart("Spike4", Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3), neonGreen, Vector3.new(0, 2.4, -1.1), model, Enum.Material.Neon)
	yCylinder("LegFL", 0.9, 0.4, c, Vector3.new(-0.5, 0.45, 0.55), model)
	yCylinder("LegFR", 0.9, 0.4, c, Vector3.new(0.5, 0.45, 0.55), model)
	yCylinder("LegBL", 0.9, 0.4, c, Vector3.new(-0.5, 0.45, -0.55), model)
	yCylinder("LegBR", 0.9, 0.4, c, Vector3.new(0.5, 0.45, -0.55), model)
	yCylinder("ArmLeft", 0.6, 0.25, c, Vector3.new(-0.6, 1.5, 0.9), model)
	yCylinder("ArmRight", 0.6, 0.25, c, Vector3.new(0.6, 1.5, 0.9), model)
	return body
end

-- Garamararam: a golden robed ancient one with a glowing staff.
local function buildGaramararam(model, c)
	local brown = Color3.fromRGB(128, 89, 51)
	local dark = Color3.fromRGB(51, 38, 26)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), c, Vector3.new(0, 1.7, 0), model)
	yCylinder("Robe", 2.6, 1.8, c, Vector3.new(0, 1.7, 0), model)
	newPart("Hood", Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5), c, Vector3.new(0, 3.3, 0), model)
	newPart("FaceShadow", Enum.PartType.Ball, Vector3.new(1.0, 0.8, 0.5), dark, Vector3.new(0, 3.25, 0.55), model)
	newPart("EyeLeft", Enum.PartType.Ball, Vector3.new(0.2, 0.2, 0.2), Color3.fromRGB(255, 220, 0), Vector3.new(-0.25, 3.4, 0.85), model, Enum.Material.Neon)
	newPart("EyeRight", Enum.PartType.Ball, Vector3.new(0.2, 0.2, 0.2), Color3.fromRGB(255, 220, 0), Vector3.new(0.25, 3.4, 0.85), model, Enum.Material.Neon)
	newPart("Beard", Enum.PartType.Block, Vector3.new(0.5, 0.7, 0.2), Color3.fromRGB(240, 240, 240), Vector3.new(0, 2.7, 0.65), model, nil, Vector3.new(0.25, 0, 0))
	yCylinder("Staff", 3.4, 0.25, brown, Vector3.new(1.25, 2.0, 0.3), model)
	newPart("StaffOrb", Enum.PartType.Ball, Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(255, 215, 0), Vector3.new(1.25, 3.85, 0.3), model, Enum.Material.Neon)
	yCylinder("ArmLeft", 1.2, 0.28, c, Vector3.new(-1.0, 2.0, 0), model)
	yCylinder("ArmRight", 1.2, 0.28, c, Vector3.new(1.0, 2.0, 0), model)
	return body
end

-- Los Crocodilitios: three tiny green crocodiles in a row.
local function buildCrocodilitios(model, c)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(0.55, 0.55, 0.55), c, Vector3.new(0, 1.7, 0), model)
	addCroc(model, 0, 1.7, 0, 1.1, 0.55, c)
	addCroc(model, -1.0, 1.6, -0.15, 1.0, 0.5, c)
	addCroc(model, 1.0, 1.6, -0.15, 1.0, 0.5, c)
	return body
end

-- Meowl: a pink cat with triangle ears, whiskers and a curled tail.
local function buildMeowl(model, c)
	local pinkDark = Color3.fromRGB(230, 102, 179)
	local white = Color3.fromRGB(255, 255, 255)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.8, 1.6, 1.8), c, Vector3.new(0, 1.7, 0), model)
	newPart("Head", Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4), c, Vector3.new(0, 3.0, 0), model)
	addFace(model, 0, 3.0, 0, 0.7)
	newPart("EarLeft", Enum.PartType.Block, Vector3.new(0.5, 0.6, 0.15), c, Vector3.new(-0.55, 3.75, 0), model, nil, Vector3.new(0, 0, 0.25))
	newPart("EarRight", Enum.PartType.Block, Vector3.new(0.5, 0.6, 0.15), c, Vector3.new(0.55, 3.75, 0), model, nil, Vector3.new(0, 0, -0.25))
	newPart("EarInnerLeft", Enum.PartType.Block, Vector3.new(0.3, 0.35, 0.16), pinkDark, Vector3.new(-0.55, 3.72, 0.02), model, nil, Vector3.new(0, 0, 0.25))
	newPart("EarInnerRight", Enum.PartType.Block, Vector3.new(0.3, 0.35, 0.16), pinkDark, Vector3.new(0.55, 3.72, 0.02), model, nil, Vector3.new(0, 0, -0.25))
	newPart("Nose", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), pinkDark, Vector3.new(0, 2.85, 0.72), model)
	newPart("WhiskerL1", Enum.PartType.Cylinder, Vector3.new(0.7, 0.05, 0.05), white, Vector3.new(-0.7, 2.9, 0.65), model, nil, Vector3.new(0, 0.4, 0.15))
	newPart("WhiskerL2", Enum.PartType.Cylinder, Vector3.new(0.7, 0.05, 0.05), white, Vector3.new(-0.7, 2.78, 0.65), model, nil, Vector3.new(0, 0.4, -0.15))
	newPart("WhiskerR1", Enum.PartType.Cylinder, Vector3.new(0.7, 0.05, 0.05), white, Vector3.new(0.7, 2.9, 0.65), model, nil, Vector3.new(0, -0.4, -0.15))
	newPart("WhiskerR2", Enum.PartType.Cylinder, Vector3.new(0.7, 0.05, 0.05), white, Vector3.new(0.7, 2.78, 0.65), model, nil, Vector3.new(0, -0.4, 0.15))
	newPart("TailLower", Enum.PartType.Cylinder, Vector3.new(0.9, 0.3, 0.3), c, Vector3.new(0, 1.9, -1.1), model, nil, Vector3.new(0.6, 0, 0))
	newPart("TailUpper", Enum.PartType.Cylinder, Vector3.new(0.8, 0.28, 0.28), c, Vector3.new(0, 2.5, -1.4), model, nil, Vector3.new(1.0, 0, 0))
	newPart("LegLeft", Enum.PartType.Block, Vector3.new(0.35, 0.4, 0.35), c, Vector3.new(-0.45, 0.2, 0.2), model)
	newPart("LegRight", Enum.PartType.Block, Vector3.new(0.35, 0.4, 0.35), c, Vector3.new(0.45, 0.2, 0.2), model)
	return body
end

-- Dragon Cannelloni: an orange pasta dragon — segmented body, wings, horns.
local function buildDragon(model, c)
	local cream = Color3.fromRGB(255, 230, 179)
	local red = Color3.fromRGB(230, 64, 38)
	local body = newPart("Body", Enum.PartType.Ball, Vector3.new(1.2, 1.2, 1.2), c, Vector3.new(0, 1.7, 0), model)
	zCylinder("SegmentBack", 1.0, 1.2, c, Vector3.new(0, 1.7, -0.9), model)
	zCylinder("SegmentMid", 1.0, 1.2, c, Vector3.new(0, 1.7, 0), model)
	zCylinder("SegmentFront", 1.0, 1.2, c, Vector3.new(0, 1.7, 0.9), model)
	zCylinder("Ridge1", 0.12, 1.3, cream, Vector3.new(0, 1.7, -0.45), model)
	zCylinder("Ridge2", 0.12, 1.3, cream, Vector3.new(0, 1.7, 0.45), model)
	newPart("Head", Enum.PartType.Ball, Vector3.new(1.2, 1.2, 1.2), c, Vector3.new(0, 2.2, 1.6), model)
	newPart("Snout", Enum.PartType.Block, Vector3.new(0.7, 0.45, 0.6), c, Vector3.new(0, 2.05, 2.1), model)
	yCylinder("HornLeft", 0.5, 0.16, cream, Vector3.new(-0.35, 2.9, 1.6), model, nil, Vector3.new(0, 0, 0.3))
	yCylinder("HornRight", 0.5, 0.16, cream, Vector3.new(0.35, 2.9, 1.6), model, nil, Vector3.new(0, 0, -0.3))
	addFace(model, 0, 2.2, 1.6, 0.6)
	newPart("WingLeft", Enum.PartType.Block, Vector3.new(1.2, 0.08, 1.0), red, Vector3.new(-1.15, 2.7, -0.3), model, nil, Vector3.new(0, 0, 0.5))
	newPart("WingRight", Enum.PartType.Block, Vector3.new(1.2, 0.08, 1.0), red, Vector3.new(1.15, 2.7, -0.3), model, nil, Vector3.new(0, 0, -0.5))
	newPart("Tail", Enum.PartType.Block, Vector3.new(0.5, 0.4, 1.3), c, Vector3.new(0, 1.7, -1.7), model, nil, Vector3.new(0.15, 0, 0))
	newPart("LegFL", Enum.PartType.Block, Vector3.new(0.35, 0.5, 0.35), c, Vector3.new(-0.5, 0.25, 0.5), model)
	newPart("LegFR", Enum.PartType.Block, Vector3.new(0.35, 0.5, 0.35), c, Vector3.new(0.5, 0.25, 0.5), model)
	newPart("LegBL", Enum.PartType.Block, Vector3.new(0.35, 0.5, 0.35), c, Vector3.new(-0.5, 0.25, -0.5), model)
	newPart("LegBR", Enum.PartType.Block, Vector3.new(0.35, 0.5, 0.35), c, Vector3.new(0.5, 0.25, -0.5), model)
	return body
end

local SILHOUETTES = {
	tung_tung_sahur = buildTungTung,
	chimpanzini_bananini = buildChimpanzini,
	lirili_larila = buildLirili,
	boneca_ambalabu = buildBoneca,
	tralalero_tralala = buildTralalero,
	brr_brr_patapim = buildPatapim,
	la_vaca_saturno_saturnita = buildVaca,
	frigo_camelo = buildFrigo,
	bombardiro_crocodilo = buildBombardiro,
	ballerina_cappuccina = buildBallerina,
	trippi_troppi = buildTrippi,
	cappuccino_assassino = buildAssassino,
	giraffa_celeste = buildGiraffa,
	los_tralaleritos = buildTralaleritos,
	las_tralaleritas = buildTralaleritas,
	matteo = buildMatteo,
	pot_hotspot = buildPotHotspot,
	graipuss_medussi = buildGraipuss,
	la_grande_combinazione = buildCombinazione,
	nuclearo_dinossauro = buildNuclearo,
	garamararam = buildGaramararam,
	los_crocodilitios = buildCrocodilitios,
	meowl = buildMeowl,
	dragon_cannelloni = buildDragon,
}

-- Picks the per-character builder for an id (the old generic ball for any
-- unknown id) and returns the PrimaryPart it built.
local function buildSilhouette(model, charId, bodyColor)
	local builder = nil
	if charId ~= nil then
		builder = SILHOUETTES[charId]
	end
	if builder ~= nil then
		return builder(model, bodyColor)
	end
	return buildDefault(model, bodyColor)
end

-- Overhead tag: a BillboardGui above the model showing name, rarity (in the
-- rarity colour), income per second, and — on the parade only — the buy
-- price. BillboardGui always faces the camera, so the tag reads from the
-- midway at normal play distance. Numbers come from BrainrotData, never
-- invented here.
local function formatMoney(amount)
	local n = tonumber(amount) or 0
	if n == math.floor(n) then
		return "$" .. tostring(math.floor(n))
	end
	return string.format("$%.1f", n)
end

local function addOverheadTag(model, body, charName, rarityName, rarityColor, mutationName, income, priceOrNil)
	local lineCount = 3
	if priceOrNil ~= nil then
		lineCount = 4
	end
	-- Compact tag: narrow (150px) and short lines so tags of brainrots
	-- standing side by side on the conveyor or on neighbouring pedestals
	-- stay separately readable instead of running into each other.
	local lineHeight = 17
	local nameHeight = 20
	local totalHeight = nameHeight + (lineCount - 1) * lineHeight + (lineCount - 1) * 2

	local gui = Instance.new("BillboardGui")
	gui.Name = "OverheadTag"
	gui.Adornee = body
	gui.Size = UDim2.fromOffset(150, totalHeight)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
	-- Only nearby brainrots show a tag (50 studs): distant ones on the far
	-- end of the conveyor no longer pile their tags up at the screen edges
	-- or over the leaderboard area.
	gui.MaxDistance = 50
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Parent = model

	-- The chip is only a transparent layout container now: no filled box
	-- behind the text (user asked the black background gone). The lines
	-- keep a solid text outline so they stay readable on bright grass.
	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.Size = UDim2.fromScale(1, 1)
	chip.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	chip.BackgroundTransparency = 1
	chip.BorderSizePixel = 0
	chip.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 2)
	layout.Parent = chip

	local function addLine(text, color, height, textSize)
		local label = Instance.new("TextLabel")
		label.Name = "TagLine"
		label.Size = UDim2.new(1, 0, 0, height)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = color
		label.TextScaled = false
		label.TextSize = textSize
		label.Font = Enum.Font.FredokaOne
		label.TextStrokeTransparency = 0
		label.Parent = chip
		return label
	end

	addLine(charName, Color3.fromRGB(255, 255, 255), nameHeight, 16)
	local rarityText = rarityName or "Unknown"
	if type(mutationName) == "string" and mutationName ~= "" and string.lower(mutationName) ~= "none" then
		rarityText = rarityText .. " • " .. mutationName
	end
	addLine(rarityText, rarityColor, lineHeight, 13)
	addLine(formatMoney(income) .. "/sec", Color3.fromRGB(80, 220, 120), lineHeight, 13)
	if priceOrNil ~= nil then
		addLine("Price: " .. formatMoney(priceOrNil), Color3.fromRGB(255, 214, 0), lineHeight, 13)
	end
end

-- buildCharacterModel(charId, mutation, showPrice) -> Model with PrimaryPart set.
-- mutation is a string such as "Gold", "Diamond", "Rainbow", "None", or nil.
-- showPrice true adds the buy-price line to the overhead tag (parade only).
function CharacterModels.buildCharacterModel(charId, mutation, showPrice)
	local char = nil
	local ok, result = pcall(function()
		return BrainrotData.getCharacter(charId)
	end)
	if ok then
		char = result
	end

	local charName = "Brainrot"
	if char ~= nil then
		charName = char.name or char.Name or char.displayName or ("Brainrot " .. tostring(charId))
	else
		charName = "Brainrot " .. tostring(charId)
	end

	local rarityName = nil
	if char ~= nil then
		rarityName = char.rarity or char.Rarity
	end
	local bodyColor = getCharacterColor(char)
	local rarityColor = getRarityColor(rarityName)

	local model = Instance.new("Model")
	model.Name = charName

	-- Per-character silhouette (see the builders above): the model reads as
	-- its name instead of the same generic ball. Every builder returns the
	-- PrimaryPart ("Body"), an unrotated ball centred at (0, 1.7, 0) — the
	-- pedestal / conveyor code places the model by that pivot.
	local body = buildSilhouette(model, charId, bodyColor)

	-- Rarity base ring: a flat neon disc under the feet, in the rarity colour.
	local ring = newPart("BaseRing", Enum.PartType.Cylinder, Vector3.new(0.25, 2.9, 2.9), rarityColor, Vector3.new(0, 0.15, 0), model, Enum.Material.Neon)
	ring.CFrame = CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Transparency = 0.15

	-- Mutation markers (visible, part-only).
	local mutationName = ""
	if type(mutation) == "string" then
		mutationName = mutation
	elseif type(mutation) == "table" and mutation.name ~= nil then
		mutationName = tostring(mutation.name)
	end
	local lowerMutation = string.lower(mutationName)

	if lowerMutation == "gold" then
		-- Four small yellow sparkle balls around the head, plus a gold light.
		newPart("GoldSpark1", Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(255, 215, 0), Vector3.new(-1.1, 3.9, 0.4), model, Enum.Material.Neon)
		newPart("GoldSpark2", Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(255, 215, 0), Vector3.new(1.1, 3.9, 0.4), model, Enum.Material.Neon)
		newPart("GoldSpark3", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), Color3.fromRGB(255, 235, 120), Vector3.new(-0.9, 4.3, 0), model, Enum.Material.Neon)
		newPart("GoldSpark4", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), Color3.fromRGB(255, 235, 120), Vector3.new(0.9, 4.3, 0), model, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Name = "GoldLight"
		light.Color = Color3.fromRGB(255, 200, 0)
		light.Brightness = 1
		light.Range = 6
		light.Parent = body
	elseif lowerMutation == "diamond" then
		-- Light-blue transparent shell balls over the body, plus a cool light.
		local shell = newPart("DiamondShell", Enum.PartType.Ball, Vector3.new(2.5, 2.5, 2.5), Color3.fromRGB(170, 230, 255), Vector3.new(0, 1.7, 0), model, Enum.Material.Glass)
		shell.Transparency = 0.45
		local gem = newPart("DiamondGem", Enum.PartType.Ball, Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(200, 240, 255), Vector3.new(0, 4.4, 0), model, Enum.Material.Neon)
		gem.Transparency = 0.1
		local light = Instance.new("PointLight")
		light.Name = "DiamondLight"
		light.Color = Color3.fromRGB(170, 220, 255)
		light.Brightness = 1
		light.Range = 6
		light.Parent = body
	elseif lowerMutation == "rainbow" then
		-- A small ring of 6 coloured balls around the body.
		local rainbowColors = {
			Color3.fromRGB(255, 60, 60),
			Color3.fromRGB(255, 165, 0),
			Color3.fromRGB(255, 230, 0),
			Color3.fromRGB(80, 220, 100),
			Color3.fromRGB(80, 160, 255),
			Color3.fromRGB(180, 100, 255),
		}
		for i = 1, 6 do
			local angle = (i - 1) * (math.pi * 2 / 6)
			local x = math.cos(angle) * 1.35
			local z = math.sin(angle) * 1.35
			newPart("RainbowDot" .. tostring(i), Enum.PartType.Ball, Vector3.new(0.35, 0.35, 0.35), rainbowColors[i], Vector3.new(x, 2.6, z), model, Enum.Material.Neon)
		end
	end

	model.PrimaryPart = body
	setModelParts(model, false)

	-- Overhead tag: name, rarity, income/sec, and the buy price on the
	-- parade only. Income uses the same formula as the economy
	-- (baseIncome x mutation mult, rebirth 0); price is the buy cost.
	local tagIncome = 0
	do
		local ok, result = pcall(function()
			return BrainrotData.incomePerSecond(charId, mutationName, 0)
		end)
		if ok and type(result) == "number" then
			tagIncome = result
		elseif char ~= nil and type(char.baseIncome) == "number" then
			tagIncome = char.baseIncome
		end
	end
	local tagPrice = nil
	if showPrice then
		local ok, result = pcall(function()
			return BrainrotData.costOf(charId)
		end)
		if ok and type(result) == "number" then
			tagPrice = result
		end
	end
	addOverheadTag(model, body, charName, rarityName, rarityColor, mutationName, tagIncome, tagPrice)

	return model
end

-- buildPedestalMarker(color) -> a small glowing ring part for a pedestal.
-- The caller anchors/positions it; it is returned unparented.
function CharacterModels.buildPedestalMarker(color)
	local markerColor = Color3.fromRGB(255, 215, 0)
	if typeof(color) == "Color3" then
		markerColor = color
	end
	local marker = Instance.new("Part")
	marker.Name = "PedestalMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.2, 3.0, 3.0)
	marker.Color = markerColor
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.35
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.TopSurface = Enum.SurfaceType.Smooth
	marker.BottomSurface = Enum.SurfaceType.Smooth
	marker.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
	return marker
end

return CharacterModels
