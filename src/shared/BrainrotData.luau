-- BrainrotData.luau
-- Shared static data for Brainrot Carnival: rarities, characters, mutations.
-- Pure Luau: no Roblox API calls, only math / string / table.
-- Used by the server and client through require(); see Economy.luau and
-- BoothLogic.luau for the gameplay rules built on top of this data.

local BrainrotData = {}

-- Ordered rarities, weakest first. `mult` is the rarity income multiplier
-- (currently 1 for every rarity; income differences come from baseIncome).
BrainrotData.RARITIES = {
	{ name = "Common", color = { r = 0.7, g = 0.7, b = 0.7 }, mult = 1 },
	{ name = "Rare", color = { r = 0.2, g = 0.5, b = 1 }, mult = 1 },
	{ name = "Epic", color = { r = 0.6, g = 0.2, b = 0.9 }, mult = 1 },
	{ name = "Legendary", color = { r = 1, g = 0.55, b = 0 }, mult = 1 },
	{ name = "Mythic", color = { r = 1, g = 0.1, b = 0.1 }, mult = 1 },
	{ name = "Brainrot God", color = { r = 1, g = 0.85, b = 0 }, mult = 1 },
	{ name = "Secret", color = { r = 1, g = 0.3, b = 0.7 }, mult = 1 },
}

-- Exactly 24 characters across the 7-rarity ladder.
-- color is RGB 0-1, used for the character's booth / conveyor tint.
BrainrotData.CHARACTERS = {
	-- Common
	{ id = "tung_tung_sahur", name = "Tung Tung Tung Sahur", rarity = "Common", baseIncome = 1, cost = 25, color = { r = 0.55, g = 0.35, b = 0.2 }, blurb = "He knocks three times. You answer. You pay." },
	{ id = "chimpanzini_bananini", name = "Chimpanzini Bananini", rarity = "Common", baseIncome = 2, cost = 50, color = { r = 1, g = 0.85, b = 0.2 }, blurb = "Part chimp, part banana, all potassium." },
	{ id = "lirili_larila", name = "Lirili Larila", rarity = "Common", baseIncome = 3, cost = 75, color = { r = 0.4, g = 0.8, b = 0.9 }, blurb = "Sings in the desert. Nobody knows why." },
	{ id = "boneca_ambalabu", name = "Boneca Ambalabu", rarity = "Common", baseIncome = 5, cost = 100, color = { r = 0.95, g = 0.6, b = 0.7 }, blurb = "A doll with big dreams and bigger hair." },
	-- Rare
	{ id = "tralalero_tralala", name = "Tralalero Tralala", rarity = "Rare", baseIncome = 8, cost = 250, color = { r = 0.2, g = 0.6, b = 1 }, blurb = "A shark in sneakers. Do not ask how." },
	{ id = "brr_brr_patapim", name = "Brr Brr Patapim", rarity = "Rare", baseIncome = 12, cost = 400, color = { r = 0.5, g = 0.7, b = 0.4 }, blurb = "His nose is a tree. His vibe is unmatched." },
	{ id = "la_vaca_saturno_saturnita", name = "La Vaca Saturno Saturnita", rarity = "Rare", baseIncome = 15, cost = 600, color = { r = 0.9, g = 0.85, b = 0.6 }, blurb = "A cow with a ring. Saturn is jealous." },
	{ id = "frigo_camelo", name = "Frigo Camelo", rarity = "Rare", baseIncome = 20, cost = 800, color = { r = 0.7, g = 0.85, b = 1 }, blurb = "A camel that is also a fridge. Cool either way." },
	-- Epic
	{ id = "bombardiro_crocodilo", name = "Bombardiro Crocodilo", rarity = "Epic", baseIncome = 30, cost = 2000, color = { r = 0.3, g = 0.6, b = 0.3 }, blurb = "A bomber crocodile. The sky is not safe." },
	{ id = "ballerina_cappuccina", name = "Ballerina Cappuccina", rarity = "Epic", baseIncome = 45, cost = 3500, color = { r = 0.95, g = 0.75, b = 0.6 }, blurb = "She dances. The coffee never spills." },
	{ id = "trippi_troppi", name = "Trippi Troppi", rarity = "Epic", baseIncome = 60, cost = 5000, color = { r = 0.6, g = 0.8, b = 0.4 }, blurb = "Three fish, one dream, zero regrets." },
	{ id = "cappuccino_assassino", name = "Cappuccino Assassino", rarity = "Epic", baseIncome = 80, cost = 6000, color = { r = 0.4, g = 0.25, b = 0.15 }, blurb = "Silent. Steamy. Deadly before breakfast." },
	-- Legendary
	{ id = "giraffa_celeste", name = "Giraffa Celeste", rarity = "Legendary", baseIncome = 150, cost = 15000, color = { r = 1, g = 0.85, b = 0.4 }, blurb = "A giraffe from the stars. Neck goals." },
	{ id = "los_tralaleritos", name = "Los Tralaleritos", rarity = "Legendary", baseIncome = 220, cost = 22000, color = { r = 0.3, g = 0.7, b = 1 }, blurb = "Three little sharks, triple the trouble." },
	{ id = "las_tralaleritas", name = "Las Tralaleritas", rarity = "Legendary", baseIncome = 300, cost = 30000, color = { r = 1, g = 0.5, b = 0.7 }, blurb = "The shark sisters run this carnival." },
	{ id = "matteo", name = "Matteo", rarity = "Legendary", baseIncome = 400, cost = 40000, color = { r = 0.8, g = 0.5, b = 0.9 }, blurb = "Just Matteo. That is the whole joke." },
	-- Mythic
	{ id = "pot_hotspot", name = "Pot Hotspot", rarity = "Mythic", baseIncome = 800, cost = 100000, color = { r = 1, g = 0.4, b = 0.2 }, blurb = "A pot so hot it cooks the economy." },
	{ id = "graipuss_medussi", name = "Graipuss Medussi", rarity = "Mythic", baseIncome = 1200, cost = 150000, color = { r = 0.5, g = 0.9, b = 0.5 }, blurb = "One look and your wallet turns to stone." },
	{ id = "la_grande_combinazione", name = "La Grande Combinazione", rarity = "Mythic", baseIncome = 1600, cost = 200000, color = { r = 1, g = 0.8, b = 0.2 }, blurb = "The grand combination. Nobody knows of what." },
	{ id = "nuclearo_dinossauro", name = "Nuclearo Dinossauro", rarity = "Mythic", baseIncome = 2000, cost = 250000, color = { r = 0.4, g = 1, b = 0.3 }, blurb = "A radioactive dino. Glows. Earns. Repeats." },
	-- Brainrot God
	{ id = "garamararam", name = "Garamararam", rarity = "Brainrot God", baseIncome = 5000, cost = 500000, color = { r = 1, g = 0.85, b = 0 }, blurb = "The ancient one hums. Money appears." },
	{ id = "los_crocodilitios", name = "Los Crocodilitios", rarity = "Brainrot God", baseIncome = 10000, cost = 1000000, color = { r = 0.2, g = 0.8, b = 0.4 }, blurb = "Tiny crocs, godly income. Do not feed them." },
	-- Secret
	{ id = "meowl", name = "Meowl", rarity = "Secret", baseIncome = 25000, cost = 2500000, color = { r = 1, g = 0.6, b = 0.9 }, blurb = "A cat. A secret. A money printer." },
	{ id = "dragon_cannelloni", name = "Dragon Cannelloni", rarity = "Secret", baseIncome = 50000, cost = 5000000, color = { r = 1, g = 0.5, b = 0.2 }, blurb = "A pasta dragon. Rare, spicy, priceless." },
}

-- Mutations multiply income. `chance` is the roll probability; the four
-- chances sum to 1 (None takes the remaining 0.86).
BrainrotData.MUTATIONS = {
	Gold = { mult = 2, chance = 0.10 },
	Diamond = { mult = 5, chance = 0.03 },
	Rainbow = { mult = 10, chance = 0.01 },
	None = { mult = 1, chance = 0.86 },
}

-- Returns the character entry for an id, or nil when unknown.
function BrainrotData.getCharacter(id)
	for _, char in ipairs(BrainrotData.CHARACTERS) do
		if char.id == id then
			return char
		end
	end
	return nil
end

-- Returns the buy cost of a character id, or nil when unknown.
function BrainrotData.costOf(id)
	local char = BrainrotData.getCharacter(id)
	if char == nil then
		return nil
	end
	return char.cost
end

-- Income per second for one owned brainrot:
-- baseIncome * mutation multiplier * (1 + 0.5 * rebirthLevel).
-- Unknown character id earns 0; unknown/nil mutation counts as "None".
function BrainrotData.incomePerSecond(charId, mutation, rebirthLevel)
	local char = BrainrotData.getCharacter(charId)
	if char == nil then
		return 0
	end
	local mutationData = BrainrotData.MUTATIONS[mutation or "None"]
	local mutationMult = 1
	if mutationData ~= nil then
		mutationMult = mutationData.mult
	end
	local level = rebirthLevel or 0
	return char.baseIncome * mutationMult * (1 + 0.5 * level)
end

-- Rolls a mutation by the chances in MUTATIONS.
-- Roll order: Rainbow first, then Diamond, then Gold, else None.
function BrainrotData.rollMutation()
	local roll = math.random()
	if roll < 0.01 then
		return "Rainbow"
	elseif roll < 0.04 then -- 0.01 + 0.03 Diamond
		return "Diamond"
	elseif roll < 0.14 then -- + 0.10 Gold
		return "Gold"
	else
		return "None"
	end
end

return BrainrotData
