-- tests/economy.luau
-- Unit tests for Economy + BrainrotData (pure logic, headless).
-- Written from the API contract only. No Roblox services used.
-- Run with: node scripts/run-tests.mjs   (from the repo root)

local BrainrotData = require("../src/shared/BrainrotData")
local Economy = require("../src/shared/Economy")

local passed = 0
local failed = 0

local function check(name, cond, extra)
	if cond then
		passed += 1
		print("PASS: " .. name)
	else
		failed += 1
		print("FAIL: " .. name .. (extra ~= nil and (" | got: " .. tostring(extra)) or ""))
	end
end

local function numEq(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.000001
end

local function checkEq(name, got, want)
	check(name, numEq(got, want) or got == want, tostring(got) .. " ~= " .. tostring(want))
end

local function deepEqual(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k, _ in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function contains(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

local function countBrainrots(profile)
	local n = 0
	for _ in pairs(profile.brainrots) do
		n += 1
	end
	return n
end

-- ============================================================
-- A. BrainrotData: rarities, characters, mutations, income math
-- ============================================================

checkEq("rarities: 7 total", #BrainrotData.RARITIES, 7)
local rarityNames = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Brainrot God", "Secret" }
for i, name in ipairs(rarityNames) do
	checkEq("rarity order #" .. i .. " = " .. name, BrainrotData.RARITIES[i].name, name)
end

checkEq("characters: 24 total", #BrainrotData.CHARACTERS, 24)

-- Spot-check 8 characters across every rarity: id / rarity / cost / base income.
local spot = {
	{ id = "tung_tung_sahur", rarity = "Common", cost = 25, income = 1 },
	{ id = "tralalero_tralala", rarity = "Rare", cost = 250, income = 8 },
	{ id = "frigo_camelo", rarity = "Rare", cost = 800, income = 20 },
	{ id = "bombardiro_crocodilo", rarity = "Epic", cost = 2000, income = 30 },
	{ id = "giraffa_celeste", rarity = "Legendary", cost = 15000, income = 150 },
	{ id = "pot_hotspot", rarity = "Mythic", cost = 100000, income = 800 },
	{ id = "garamararam", rarity = "Brainrot God", cost = 500000, income = 5000 },
	{ id = "dragon_cannelloni", rarity = "Secret", cost = 5000000, income = 50000 },
}
for _, want in ipairs(spot) do
	local c = BrainrotData.getCharacter(want.id)
	check("spot " .. want.id .. ": exists", c ~= nil)
	if c then
		checkEq("spot " .. want.id .. ": rarity", c.rarity, want.rarity)
		checkEq("spot " .. want.id .. ": cost", c.cost, want.cost)
		checkEq("spot " .. want.id .. ": baseIncome", c.baseIncome, want.income)
		checkEq("spot " .. want.id .. ": costOf matches", BrainrotData.costOf(want.id), want.cost)
		check("spot " .. want.id .. ": has name", type(c.name) == "string" and c.name ~= "")
	end
end

-- Every character is well-formed: valid rarity, positive cost/income.
for _, c in ipairs(BrainrotData.CHARACTERS) do
	local ok = type(c.id) == "string" and c.id ~= ""
		and type(c.name) == "string" and c.name ~= ""
		and contains(rarityNames, c.rarity)
		and type(c.cost) == "number" and c.cost > 0
		and type(c.baseIncome) == "number" and c.baseIncome > 0
		and BrainrotData.costOf(c.id) == c.cost
	check("character well-formed: " .. tostring(c.id), ok)
end

check("getCharacter unknown id -> nil", BrainrotData.getCharacter("nope_not_a_char") == nil)
check("costOf unknown id -> nil", BrainrotData.costOf("nope_not_a_char") == nil)

-- Mutations: multiplier + chance per the contract.
checkEq("mutation None mult", BrainrotData.MUTATIONS.None.mult, 1)
checkEq("mutation None chance", BrainrotData.MUTATIONS.None.chance, 0.86)
checkEq("mutation Gold mult", BrainrotData.MUTATIONS.Gold.mult, 2)
checkEq("mutation Gold chance", BrainrotData.MUTATIONS.Gold.chance, 0.10)
checkEq("mutation Diamond mult", BrainrotData.MUTATIONS.Diamond.mult, 5)
checkEq("mutation Diamond chance", BrainrotData.MUTATIONS.Diamond.chance, 0.03)
checkEq("mutation Rainbow mult", BrainrotData.MUTATIONS.Rainbow.mult, 10)
checkEq("mutation Rainbow chance", BrainrotData.MUTATIONS.Rainbow.chance, 0.01)

-- incomePerSecond = baseIncome * mutationMult * (1 + 0.5 * rebirthLevel).
checkEq("ips tung None r0", BrainrotData.incomePerSecond("tung_tung_sahur", "None", 0), 1)
checkEq("ips tung Gold r0", BrainrotData.incomePerSecond("tung_tung_sahur", "Gold", 0), 2)
checkEq("ips tung Diamond r0", BrainrotData.incomePerSecond("tung_tung_sahur", "Diamond", 0), 5)
checkEq("ips tung Rainbow r0", BrainrotData.incomePerSecond("tung_tung_sahur", "Rainbow", 0), 10)
checkEq("ips tung None r1 (x1.5)", BrainrotData.incomePerSecond("tung_tung_sahur", "None", 1), 1.5)
checkEq("ips tung Gold r2 (x2)", BrainrotData.incomePerSecond("tung_tung_sahur", "Gold", 2), 4)
checkEq("ips tung Rainbow r1", BrainrotData.incomePerSecond("tung_tung_sahur", "Rainbow", 1), 15)
checkEq("ips unknown char -> 0", BrainrotData.incomePerSecond("nope_not_a_char", "None", 0), 0)

-- rollMutation: all four outcomes appear over 2000 rolls, in plausible ranges.
do
	local counts = { None = 0, Gold = 0, Diamond = 0, Rainbow = 0 }
	local total = 0
	local invalid = 0
	for _ = 1, 2000 do
		local m = BrainrotData.rollMutation()
		if counts[m] ~= nil then
			counts[m] += 1
			total += 1
		else
			invalid += 1
		end
	end
	checkEq("rollMutation: 0 invalid outcomes", invalid, 0)
	checkEq("rollMutation: 2000 rolls counted", total, 2000)
	check("rollMutation: None seen", counts.None > 0)
	check("rollMutation: Gold seen", counts.Gold > 0)
	check("rollMutation: Diamond seen", counts.Diamond > 0)
	check("rollMutation: Rainbow seen", counts.Rainbow > 0)
	check("rollMutation: None in range 1500-1900", counts.None >= 1500 and counts.None <= 1900, counts.None)
	check("rollMutation: Gold in range 120-300", counts.Gold >= 120 and counts.Gold <= 300, counts.Gold)
	check("rollMutation: Diamond in range 25-110", counts.Diamond >= 25 and counts.Diamond <= 110, counts.Diamond)
	check("rollMutation: Rainbow in range 1-60", counts.Rainbow >= 1 and counts.Rainbow <= 60, counts.Rainbow)
end

-- ============================================================
-- B. newProfile defaults + canAfford
-- ============================================================

do
	local p = Economy.newProfile()
	checkEq("newProfile cash", p.cash, 100)
	checkEq("newProfile totalEarned", p.totalEarned, 0)
	checkEq("newProfile rebirthLevel", p.rebirthLevel, 0)
	checkEq("newProfile playTime", p.playTime, 0)
	checkEq("newProfile brainrots empty", countBrainrots(p), 0)
	checkEq("newProfile walkSpeed", p.upgrades.walkSpeed, 0)
	checkEq("newProfile incomeBoostUntil", p.upgrades.incomeBoostUntil, 0)
	checkEq("newProfile shieldUntil", p.upgrades.shieldUntil, 0)
	checkEq("newProfile lockUntil", p.upgrades.lockUntil, 0)
	check("canAfford exact cash", Economy.canAfford(p, 100) == true)
	check("canAfford one over cash", Economy.canAfford(p, 101) == false)
	check("canAfford zero", Economy.canAfford(p, 0) == true)
end

-- ============================================================
-- C. buyBrainrot / sellBrainrot
-- ============================================================

do
	local p = Economy.newProfile()
	local ok, reason = Economy.buyBrainrot(p, "tung_tung_sahur", "None")
	check("buy tung: ok", ok == true, tostring(reason))
	check("buy tung: no reason", reason == nil)
	checkEq("buy tung: cash 100-25", p.cash, 75)
	checkEq("buy tung: 1 brainrot", countBrainrots(p), 1)
	checkEq("buy tung: slot 1 charId", p.brainrots[1].charId, "tung_tung_sahur")
	checkEq("buy tung: slot 1 mutation", p.brainrots[1].mutation, "None")
	checkEq("buy tung: slot 1 slot#", p.brainrots[1].slot, 1)
end

do
	-- Buy without a mutation argument defaults to "None".
	local p = Economy.newProfile()
	local ok, _ = Economy.buyBrainrot(p, "tung_tung_sahur")
	check("buy no-mutation arg: ok", ok == true)
	checkEq("buy no-mutation arg: mutation None", p.brainrots[1].mutation, "None")
end

do
	local p = Economy.newProfile()
	local ok, reason = Economy.buyBrainrot(p, "nope_not_a_char", "None")
	check("buy unknown brainrot: fails", ok == false)
	checkEq("buy unknown brainrot: reason", reason, "Unknown brainrot")
	checkEq("buy unknown brainrot: cash unchanged", p.cash, 100)
	checkEq("buy unknown brainrot: booth unchanged", countBrainrots(p), 0)
end

do
	local p = Economy.newProfile()
	local ok, reason = Economy.buyBrainrot(p, "dragon_cannelloni", "None")
	check("buy unaffordable: fails", ok == false)
	checkEq("buy unaffordable: reason", reason, "Not enough cash")
	checkEq("buy unaffordable: cash unchanged", p.cash, 100)
	checkEq("buy unaffordable: booth unchanged", countBrainrots(p), 0)
end

do
	-- Fill all 8 booth slots; the 9th buy fails with "Booth is full".
	local p = Economy.newProfile()
	p.cash = 100000
	for i = 1, 8 do
		local ok, reason = Economy.buyBrainrot(p, "tung_tung_sahur", "None")
		check("fill booth slot " .. i, ok == true, tostring(reason))
	end
	checkEq("booth full: 8 brainrots", countBrainrots(p), 8)
	checkEq("booth full: BOOTH_SLOTS is 8", Economy.BOOTH_SLOTS, 8)
	local cashBefore = p.cash
	local ok, reason = Economy.buyBrainrot(p, "tung_tung_sahur", "None")
	check("buy 9th: fails", ok == false)
	checkEq("buy 9th: reason", reason, "Booth is full")
	checkEq("buy 9th: cash unchanged", p.cash, cashBefore)
end

do
	-- Sell refunds exactly 50% of cost and frees only that slot.
	local p = Economy.newProfile()
	Economy.buyBrainrot(p, "tung_tung_sahur", "None") -- cash 75
	local okRare, _ = Economy.buyBrainrot(p, "tralalero_tralala", "None") -- costs 250, cash 75: must fail
	check("sell setup: rare unaffordable at cash 75", okRare == false)
	checkEq("sell setup: only tung bought", countBrainrots(p), 1)
	local ok, refund = Economy.sellBrainrot(p, 1)
	check("sell: ok", ok == true)
	checkEq("sell: refund exactly 50% of 25", refund, 12.5)
	checkEq("sell: cash 75 + 12.5", p.cash, 87.5)
	checkEq("sell: totalEarned untouched", p.totalEarned, 0)
	check("sell: slot freed", p.brainrots[1] == nil)
	local ok2, reason2 = Economy.sellBrainrot(p, 1)
	check("sell empty slot: fails", ok2 == false)
	checkEq("sell empty slot: reason", reason2, "Empty slot")
	local ok3, reason3 = Economy.sellBrainrot(p, 9)
	check("sell slot 9: fails", ok3 == false)
	checkEq("sell slot 9: reason", reason3, "Empty slot")
end

do
	-- Selling one slot leaves the other brainrot in place.
	local p = Economy.newProfile()
	p.cash = 100000
	Economy.buyBrainrot(p, "tung_tung_sahur", "None")
	Economy.buyBrainrot(p, "chimpanzini_bananini", "Gold")
	local ok, refund = Economy.sellBrainrot(p, 2)
	check("sell slot 2: ok", ok == true)
	checkEq("sell slot 2: refund 50% of 50", refund, 25)
	check("sell slot 2: slot 1 kept", p.brainrots[1] ~= nil and p.brainrots[1].charId == "tung_tung_sahur")
	check("sell slot 2: slot 2 freed", p.brainrots[2] == nil)
end

-- ============================================================
-- D. tickIncome / totalIncomePerSecond / incomeMultiplier
-- ============================================================

do
	local p = Economy.newProfile()
	Economy.buyBrainrot(p, "tung_tung_sahur", "None") -- 1/s, cash 75
	checkEq("tips: 1 tung = 1/s", Economy.totalIncomePerSecond(p), 1)
	Economy.tickIncome(p, 60)
	checkEq("tick 60s at 1/s: cash 75+60", p.cash, 135)
	checkEq("tick 60s at 1/s: totalEarned 60", p.totalEarned, 60)
	Economy.tickIncome(p, 0)
	checkEq("tick 0s: cash unchanged", p.cash, 135)
	Economy.tickIncome(p, 0.5)
	checkEq("tick 0.5s: cash +0.5", p.cash, 135.5)
end

do
	-- Rebirth x1.5: Gold tung at rebirth 1 earns 2 * 1.5 = 3/s.
	local p = Economy.newProfile()
	p.cash = 100000
	p.rebirthLevel = 1
	Economy.buyBrainrot(p, "tung_tung_sahur", "Gold")
	checkEq("tips rebirth1 Gold tung = 3/s", Economy.totalIncomePerSecond(p), 3)
	local cashBefore = p.cash
	Economy.tickIncome(p, 60)
	checkEq("tick 60s rebirth1 Gold: +180", p.cash - cashBefore, 180)
	checkEq("tick 60s rebirth1 Gold: earned 180", p.totalEarned, 180)
end

do
	-- Boost x2: plain tung 1/s -> 2/s while boosted.
	local p = Economy.newProfile()
	p.cash = 100000
	Economy.buyBrainrot(p, "tung_tung_sahur", "None")
	Economy.buyShopItem(p, "boost")
	checkEq("tips with boost = 2/s", Economy.totalIncomePerSecond(p), 2)
	local cashBefore = p.cash
	Economy.tickIncome(p, 10)
	checkEq("tick 10s with boost: +20", p.cash - cashBefore, 20)
end

do
	-- Rebirth x boost: Gold tung at rebirth 1 + boost = 2 * 1.5 * 2 = 6/s.
	local p = Economy.newProfile()
	p.cash = 100000
	p.rebirthLevel = 1
	Economy.buyBrainrot(p, "tung_tung_sahur", "Gold")
	Economy.buyShopItem(p, "boost")
	checkEq("tips rebirth1 Gold + boost = 6/s", Economy.totalIncomePerSecond(p), 6)
	local cashBefore = p.cash
	Economy.tickIncome(p, 10)
	checkEq("tick 10s rebirth1 Gold + boost: +60", p.cash - cashBefore, 60)
end

do
	-- incomeMultiplier is the rebirth multiplier: 1 + 0.5 * rebirthLevel.
	local p = Economy.newProfile()
	checkEq("incomeMultiplier rebirth 0", Economy.incomeMultiplier(p), 1)
	p.rebirthLevel = 1
	checkEq("incomeMultiplier rebirth 1", Economy.incomeMultiplier(p), 1.5)
	p.rebirthLevel = 2
	checkEq("incomeMultiplier rebirth 2", Economy.incomeMultiplier(p), 2)
end

do
	local p = Economy.newProfile()
	checkEq("tips empty booth = 0", Economy.totalIncomePerSecond(p), 0)
	p.cash = 100000
	Economy.buyBrainrot(p, "tung_tung_sahur", "None")
	Economy.buyBrainrot(p, "tung_tung_sahur", "Diamond")
	checkEq("tips 1 + 5 (Diamond tung) = 6/s", Economy.totalIncomePerSecond(p), 6)
end

-- ============================================================
-- E. Rebirth gate + reset behaviour
-- ============================================================

do
	local p = Economy.newProfile()
	p.cash = 49999
	check("canRebirth at 49,999: false", Economy.canRebirth(p) == false)
	p.cash = 50000
	check("canRebirth at 50,000: true", Economy.canRebirth(p) == true)
	p.cash = 0
	check("canRebirth at 0: false", Economy.canRebirth(p) == false)
end

do
	local p = Economy.newProfile()
	local ok = Economy.rebirth(p)
	check("rebirth when poor: fails", ok == false)
	checkEq("rebirth when poor: cash unchanged", p.cash, 100)
	checkEq("rebirth when poor: level unchanged", p.rebirthLevel, 0)
end

do
	local p = Economy.newProfile()
	p.cash = 60000
	p.totalEarned = 12345
	p.upgrades.walkSpeed = 2
	Economy.buyBrainrot(p, "tung_tung_sahur", "None")
	local ok = Economy.rebirth(p)
	check("rebirth: ok", ok == true)
	checkEq("rebirth: cash reset to starting cash", p.cash, 100)
	checkEq("rebirth: booth emptied", countBrainrots(p), 0)
	checkEq("rebirth: level +1", p.rebirthLevel, 1)
	checkEq("rebirth: totalEarned kept", p.totalEarned, 12345)
	checkEq("rebirth: walkSpeed kept", p.upgrades.walkSpeed, 2)
	checkEq("rebirth: ips after rebirth (None r1)", BrainrotData.incomePerSecond("tung_tung_sahur", "None", p.rebirthLevel), 1.5)
	checkEq("rebirth: tips empty booth = 0", Economy.totalIncomePerSecond(p), 0)
	check("rebirth: canRebirth now false", Economy.canRebirth(p) == false)
end

-- Rebirth softlock fix: after rebirth the player holds the $100 starting
-- cash, so they can immediately buy the cheapest brainrot (Tung Tung $25)
-- and earn again at the x1.5 multiplier instead of being stuck at $0.
do
	local p = Economy.newProfile()
	p.cash = 50000
	local ok = Economy.rebirth(p)
	check("rebirth softlock: ok", ok == true)
	checkEq("rebirth softlock: cash is starting cash", p.cash, 100)
	local bought = Economy.buyBrainrot(p, "tung_tung_sahur", "None")
	check("rebirth softlock: can buy Tung Tung after rebirth", bought == true)
	checkEq("rebirth softlock: cash after buy", p.cash, 75)
	checkEq("rebirth softlock: income 1.5/s at x1.5", Economy.totalIncomePerSecond(p), 1.5)
	local cashBefore = p.cash
	Economy.tickIncome(p, 60)
	checkEq("rebirth softlock: tick 60s +90", p.cash - cashBefore, 90)
end

-- ============================================================
-- F. Shop
-- ============================================================

do
	checkEq("shop: 4 items", #Economy.SHOP, 4)
	checkEq("shop item 1 id", Economy.SHOP[1].id, "walkspeed")
	checkEq("shop item 1 cost", Economy.SHOP[1].cost, 500)
	checkEq("shop item 1 max", Economy.SHOP[1].max, 3)
	checkEq("shop item 2 id", Economy.SHOP[2].id, "boost")
	checkEq("shop item 2 cost", Economy.SHOP[2].cost, 1000)
	checkEq("shop item 3 id", Economy.SHOP[3].id, "shield")
	checkEq("shop item 3 cost", Economy.SHOP[3].cost, 250)
	checkEq("shop item 4 id", Economy.SHOP[4].id, "lock")
	checkEq("shop item 4 cost", Economy.SHOP[4].cost, 500)
end

do
	-- Speed Boots: 500 -> 1000 -> 1500, max level 3, 4th buy refused.
	local p = Economy.newProfile()
	p.cash = 100000
	local expectedCosts = { 500, 1000, 1500 }
	for level, cost in ipairs(expectedCosts) do
		local cashBefore = p.cash
		local ok, reason = Economy.buyShopItem(p, "walkspeed")
		check("walkspeed level " .. level .. ": ok", ok == true, tostring(reason))
		checkEq("walkspeed level " .. level .. ": cost " .. cost, cashBefore - p.cash, cost)
		checkEq("walkspeed level " .. level .. ": level", p.upgrades.walkSpeed, level)
	end
	local cashBefore = p.cash
	local ok, reason = Economy.buyShopItem(p, "walkspeed")
	check("walkspeed level 4: refused", ok == false)
	checkEq("walkspeed level 4: reason", reason, "Already max level")
	checkEq("walkspeed level 4: cash unchanged", p.cash, cashBefore)
	checkEq("walkspeed level 4: still level 3", p.upgrades.walkSpeed, 3)
end

do
	local p = Economy.newProfile()
	p.cash = 100000
	local ok, reason = Economy.buyShopItem(p, "boost")
	check("boost buy 1: ok", ok == true, tostring(reason))
	check("boost buy 1: incomeBoostUntil set in future", p.upgrades.incomeBoostUntil > os.time())
	local ok2, reason2 = Economy.buyShopItem(p, "boost")
	check("boost buy 2: refused", ok2 == false)
	checkEq("boost buy 2: reason", reason2, "Boost already active")
end

do
	local p = Economy.newProfile()
	p.cash = 100000
	local ok, reason = Economy.buyShopItem(p, "lock")
	check("lock buy 1: ok", ok == true, tostring(reason))
	check("lock buy 1: lockUntil set in future", p.upgrades.lockUntil > os.time())
	local ok2, reason2 = Economy.buyShopItem(p, "lock")
	check("lock buy 2: refused", ok2 == false)
	checkEq("lock buy 2: reason", reason2, "Booth already locked")
end

do
	local p = Economy.newProfile()
	p.cash = 100000
	local ok, reason = Economy.buyShopItem(p, "shield")
	check("shield buy: ok", ok == true, tostring(reason))
	check("shield buy: shieldUntil set in future", p.upgrades.shieldUntil > os.time())
	-- Re-buying a shield while one is active refreshes it (observed: succeeds).
	local ok2, reason2 = Economy.buyShopItem(p, "shield")
	check("shield re-buy while active: ok", ok2 == true, tostring(reason2))
end

do
	local p = Economy.newProfile()
	p.cash = 100000
	local ok, reason = Economy.buyShopItem(p, "definitely_not_an_item")
	check("unknown shop item: fails", ok == false)
	checkEq("unknown shop item: reason", reason, "Unknown shop item")
	checkEq("unknown shop item: cash unchanged", p.cash, 100000)
end

do
	local p = Economy.newProfile() -- cash 100
	local ok, reason = Economy.buyShopItem(p, "walkspeed")
	check("shop buy when poor: fails", ok == false)
	checkEq("shop buy when poor: reason", reason, "Not enough cash")
	checkEq("shop buy when poor: cash unchanged", p.cash, 100)
end

-- ============================================================
-- G. serialize / deserialize
-- ============================================================

do
	-- Round-trip: everything survives (cash, earnings, rebirth, booth, upgrades).
	local p = Economy.newProfile()
	p.cash = 424242
	p.totalEarned = 777
	p.rebirthLevel = 2
	p.playTime = 3600
	p.upgrades.walkSpeed = 3
	p.upgrades.incomeBoostUntil = 1999999999
	p.upgrades.shieldUntil = 1888888888
	p.upgrades.lockUntil = 1777777777
	Economy.buyBrainrot(p, "tung_tung_sahur", "Gold")
	Economy.buyBrainrot(p, "tralalero_tralala", "Diamond")
	local snap = Economy.serialize(p)
	check("serialize: returns a table", type(snap) == "table")
	local q = Economy.deserialize(snap)
	check("deserialize round-trip: deep equal", deepEqual(p, q))
	checkEq("round-trip: cash", q.cash, 424242 - 25 - 250)
	checkEq("round-trip: totalEarned", q.totalEarned, 777)
	checkEq("round-trip: rebirthLevel", q.rebirthLevel, 2)
	checkEq("round-trip: walkSpeed", q.upgrades.walkSpeed, 3)
	checkEq("round-trip: incomeBoostUntil", q.upgrades.incomeBoostUntil, 1999999999)
	checkEq("round-trip: shieldUntil", q.upgrades.shieldUntil, 1888888888)
	checkEq("round-trip: lockUntil", q.upgrades.lockUntil, 1777777777)
	checkEq("round-trip: brainrot 1 charId", q.brainrots[1].charId, "tung_tung_sahur")
	checkEq("round-trip: brainrot 1 mutation", q.brainrots[1].mutation, "Gold")
	checkEq("round-trip: brainrot 2 charId", q.brainrots[2].charId, "tralalero_tralala")
	checkEq("round-trip: brainrot 2 mutation", q.brainrots[2].mutation, "Diamond")
end

do
	-- serialize is a snapshot: later edits to the live profile do not leak in.
	local p = Economy.newProfile()
	p.cash = 5000
	local snap = Economy.serialize(p)
	p.cash = 1
	checkEq("serialize snapshot: cash frozen at 5000", snap.cash, 5000)
end

do
	local fresh = Economy.newProfile()
	check("deserialize(nil): fresh profile", deepEqual(Economy.deserialize(nil), fresh))
	check("deserialize({}): fresh profile", deepEqual(Economy.deserialize({}), fresh))
	local partial = Economy.deserialize({ cash = 5 })
	checkEq("deserialize partial: cash kept", partial.cash, 5)
	checkEq("deserialize partial: totalEarned default", partial.totalEarned, 0)
	checkEq("deserialize partial: rebirthLevel default", partial.rebirthLevel, 0)
	checkEq("deserialize partial: brainrots default empty", countBrainrots(partial), 0)
	checkEq("deserialize partial: walkSpeed default", partial.upgrades.walkSpeed, 0)
end

do
	-- Bad-slot repair: out-of-range + duplicated slots are re-seated 1..8,
	-- entries past the 8th are dropped.
	local bad = {
		cash = 1000,
		brainrots = {
			{ charId = "tung_tung_sahur", mutation = "None", slot = 9 },
			{ charId = "tung_tung_sahur", mutation = "Gold", slot = 1 },
			{ charId = "tung_tung_sahur", mutation = "Diamond", slot = 1 },
			{ charId = "tung_tung_sahur", mutation = "Rainbow", slot = 2 },
			{ charId = "tung_tung_sahur", mutation = "None", slot = 3 },
			{ charId = "tung_tung_sahur", mutation = "None", slot = 4 },
			{ charId = "tung_tung_sahur", mutation = "None", slot = 5 },
			{ charId = "tung_tung_sahur", mutation = "None", slot = 6 },
			{ charId = "tung_tung_sahur", mutation = "None", slot = 7 },
			{ charId = "tung_tung_sahur", mutation = "None", slot = 8 },
			{ charId = "tung_tung_sahur", mutation = "None", slot = 8 },
		},
	}
	local fixed = Economy.deserialize(bad)
	checkEq("bad-slot repair: exactly 8 kept", countBrainrots(fixed), 8)
	local slotsOk = true
	for i = 1, 8 do
		if fixed.brainrots[i] == nil or fixed.brainrots[i].slot ~= i then
			slotsOk = false
		end
	end
	check("bad-slot repair: slots exactly 1..8", slotsOk)
	checkEq("bad-slot repair: slot 1 mutation (was slot 9)", fixed.brainrots[1].mutation, "None")
	checkEq("bad-slot repair: slot 2 mutation (was dup slot 1)", fixed.brainrots[2].mutation, "Gold")
	checkEq("bad-slot repair: slot 3 mutation (was dup slot 1)", fixed.brainrots[3].mutation, "Diamond")
	checkEq("bad-slot repair: slot 4 mutation (was slot 2)", fixed.brainrots[4].mutation, "Rainbow")
	check("bad-slot repair: no slot above 8", fixed.brainrots[9] == nil)
	checkEq("bad-slot repair: cash kept", fixed.cash, 1000)
end

-- ============================================================
-- Summary
-- ============================================================

print(string.format("TOTAL: %d passed, %d failed", passed, failed))
if failed > 0 then
	error(failed .. " test(s) failed in tests/economy.luau")
end
