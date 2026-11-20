-- Economy.luau
-- Shared player economy for Brainrot Carnival: profiles, income, shop, rebirth.
-- Pure Luau: no Roblox API calls, only math / string / table / os.
-- Requires the sibling BrainrotData module (Roblox `script.Parent` path, with
-- a relative-path fallback so the module also runs headlessly under the
-- Luau CLI for tests).

local BrainrotData
if script ~= nil then
	-- Roblox: sibling ModuleScript.
	BrainrotData = require(script.Parent.BrainrotData)
else
	-- Luau CLI headless tests: relative file path.
	BrainrotData = require("./BrainrotData")
end

local Economy = {}

-- A booth holds at most this many brainrots.
Economy.BOOTH_SLOTS = 8

-- Fresh player profile: $100 starting cash, empty booth, no upgrades.
function Economy.newProfile()
	return {
		cash = 100,
		totalEarned = 0,
		rebirthLevel = 0,
		brainrots = {}, -- array of { charId, mutation, slot }
		upgrades = {
			walkSpeed = 0,
			incomeBoostUntil = 0,
			shieldUntil = 0,
			lockUntil = 0,
		},
		playTime = 0,
	}
end

function Economy.canAfford(profile, cost)
	return profile.cash >= cost
end

-- Permanent rebirth multiplier: +50% income per rebirth level.
function Economy.incomeMultiplier(profile)
	return 1 + 0.5 * profile.rebirthLevel
end

-- Sum of every owned brainrot's income per second.
-- Doubled while the Income Boost timer is still running.
function Economy.totalIncomePerSecond(profile)
	local total = 0
	for _, owned in ipairs(profile.brainrots) do
		total += BrainrotData.incomePerSecond(owned.charId, owned.mutation, profile.rebirthLevel)
	end
	if os.time() < profile.upgrades.incomeBoostUntil then
		total *= 2
	end
	return total
end

-- Lowest free booth slot number (1..BOOTH_SLOTS), or nil when full.
local function firstFreeSlot(profile)
	local used = {}
	for _, owned in ipairs(profile.brainrots) do
		used[owned.slot] = true
	end
	for slot = 1, Economy.BOOTH_SLOTS do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

-- Buys a brainrot: deducts its cost and places it in the first free slot.
-- Returns (true) on success, or (false, reason) when the booth is full
-- ("Booth is full"), the player cannot afford it ("Not enough cash"), or
-- the character id is unknown ("Unknown brainrot").
function Economy.buyBrainrot(profile, charId, mutation)
	local cost = BrainrotData.costOf(charId)
	if cost == nil then
		return false, "Unknown brainrot"
	end
	if #profile.brainrots >= Economy.BOOTH_SLOTS then
		return false, "Booth is full"
	end
	if not Economy.canAfford(profile, cost) then
		return false, "Not enough cash"
	end
	local slot = firstFreeSlot(profile)
	if slot == nil then
		return false, "Booth is full"
	end
	profile.cash -= cost
	table.insert(profile.brainrots, {
		charId = charId,
		mutation = mutation or "None",
		slot = slot,
	})
	return true
end

-- Sells the brainrot in a booth slot, refunding 50% of its cost.
-- Returns (true, refund) on success, or (false, "Empty slot").
function Economy.sellBrainrot(profile, slotIndex)
	for index, owned in ipairs(profile.brainrots) do
		if owned.slot == slotIndex then
			local cost = BrainrotData.costOf(owned.charId) or 0
			local refund = cost * 0.5
			table.remove(profile.brainrots, index)
			profile.cash += refund
			return true, refund
		end
	end
	return false, "Empty slot"
end

-- Adds totalIncomePerSecond * dtSeconds to cash and totalEarned.
function Economy.tickIncome(profile, dtSeconds)
	local earned = Economy.totalIncomePerSecond(profile) * dtSeconds
	profile.cash += earned
	profile.totalEarned += earned
end

-- Rebirth needs $50,000 cash on hand.
function Economy.canRebirth(profile)
	return profile.cash >= 50000
end

-- Rebirth: resets cash to the starting cash ($100) and empties the booth,
-- +1 rebirth level. The player can buy again immediately (cheapest
-- brainrot is $25) instead of being stuck at $0 with an empty booth.
-- Keeps totalEarned, playTime, and the walkSpeed upgrade level; the timed
-- boost / shield / lock upgrades are cleared.
-- Returns (true) on success, or (false, "Need $50,000 cash to rebirth").
function Economy.rebirth(profile)
	if not Economy.canRebirth(profile) then
		return false, "Need $50,000 cash to rebirth"
	end
	profile.cash = 100
	profile.brainrots = {}
	profile.rebirthLevel += 1
	profile.upgrades.incomeBoostUntil = 0
	profile.upgrades.shieldUntil = 0
	profile.upgrades.lockUntil = 0
	return true
end

-- Shop catalogue. walkspeed cost scales per level (500 * (level + 1));
-- the other items have a fixed cost.
Economy.SHOP = {
	{ id = "walkspeed", name = "Speed Boots", cost = 500, max = 3, desc = "Walk 15% faster per level" },
	{ id = "boost", name = "Income Boost", cost = 1000, desc = "Double income for 60 seconds" },
	{ id = "shield", name = "Shield", cost = 250, desc = "Protect your brainrots for 15 seconds" },
	{ id = "lock", name = "Booth Lock", cost = 500, desc = "Lock your booth for 60 seconds" },
}

-- Buys a shop item. Returns (true) on success, or (false, reason):
-- "Not enough cash", "Already max level" (walkspeed at 3),
-- "Boost already active", "Booth already locked", "Unknown shop item".
function Economy.buyShopItem(profile, itemId)
	local now = os.time()
	if itemId == "walkspeed" then
		if profile.upgrades.walkSpeed >= 3 then
			return false, "Already max level"
		end
		local cost = 500 * (profile.upgrades.walkSpeed + 1)
		if not Economy.canAfford(profile, cost) then
			return false, "Not enough cash"
		end
		profile.cash -= cost
		profile.upgrades.walkSpeed += 1
		return true
	elseif itemId == "boost" then
		if now < profile.upgrades.incomeBoostUntil then
			return false, "Boost already active"
		end
		if not Economy.canAfford(profile, 1000) then
			return false, "Not enough cash"
		end
		profile.cash -= 1000
		profile.upgrades.incomeBoostUntil = now + 60
		return true
	elseif itemId == "shield" then
		if not Economy.canAfford(profile, 250) then
			return false, "Not enough cash"
		end
		profile.cash -= 250
		profile.upgrades.shieldUntil = now + 15
		return true
	elseif itemId == "lock" then
		if now < profile.upgrades.lockUntil then
			return false, "Booth already locked"
		end
		if not Economy.canAfford(profile, 500) then
			return false, "Not enough cash"
		end
		profile.cash -= 500
		profile.upgrades.lockUntil = now + 60
		return true
	end
	return false, "Unknown shop item"
end

-- Returns a plain table copy of the profile, safe to store in a DataStore.
function Economy.serialize(profile)
	local brainrotsCopy = {}
	for _, owned in ipairs(profile.brainrots) do
		table.insert(brainrotsCopy, {
			charId = owned.charId,
			mutation = owned.mutation,
			slot = owned.slot,
		})
	end
	return {
		cash = profile.cash,
		totalEarned = profile.totalEarned,
		rebirthLevel = profile.rebirthLevel,
		brainrots = brainrotsCopy,
		upgrades = {
			walkSpeed = profile.upgrades.walkSpeed,
			incomeBoostUntil = profile.upgrades.incomeBoostUntil,
			shieldUntil = profile.upgrades.shieldUntil,
			lockUntil = profile.upgrades.lockUntil,
		},
		playTime = profile.playTime,
	}
end

local function numberOr(value, fallback)
	if type(value) == "number" then
		return value
	end
	return fallback
end

-- Rebuilds a valid profile from stored data. Never errors on nil or
-- partial data: any missing field falls back to the newProfile() default.
function Economy.deserialize(data)
	local profile = Economy.newProfile()
	if type(data) ~= "table" then
		return profile
	end
	profile.cash = numberOr(data.cash, profile.cash)
	profile.totalEarned = numberOr(data.totalEarned, profile.totalEarned)
	profile.rebirthLevel = numberOr(data.rebirthLevel, profile.rebirthLevel)
	profile.playTime = numberOr(data.playTime, profile.playTime)
	if type(data.brainrots) == "table" then
		profile.brainrots = {}
		local usedSlots = {}
		for _, owned in ipairs(data.brainrots) do
			if type(owned) == "table" and type(owned.charId) == "string" then
				-- Stored slots can be stale or duplicated (old saves, bad
				-- data): out-of-range or taken slots fall back to the
				-- first free slot, and anything past the 8-slot cap is
				-- dropped instead of corrupting the booth.
				local slot = numberOr(owned.slot, 0)
				if slot < 1 or slot > Economy.BOOTH_SLOTS or usedSlots[slot] then
					slot = firstFreeSlot(profile)
				end
				if slot ~= nil then
					usedSlots[slot] = true
					table.insert(profile.brainrots, {
						charId = owned.charId,
						mutation = owned.mutation or "None",
						slot = slot,
					})
				end
			end
		end
	end
	if type(data.upgrades) == "table" then
		profile.upgrades.walkSpeed = numberOr(data.upgrades.walkSpeed, profile.upgrades.walkSpeed)
		profile.upgrades.incomeBoostUntil = numberOr(data.upgrades.incomeBoostUntil, profile.upgrades.incomeBoostUntil)
		profile.upgrades.shieldUntil = numberOr(data.upgrades.shieldUntil, profile.upgrades.shieldUntil)
		profile.upgrades.lockUntil = numberOr(data.upgrades.lockUntil, profile.upgrades.lockUntil)
	end
	return profile
end

return Economy
