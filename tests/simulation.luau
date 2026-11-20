-- tests/simulation.luau
-- SCRIPTED FULL-LOOP WALKTHROUGH: one player session, end to end, at the
-- pure-logic level, using ONLY BrainrotData / Economy / BoothLogic.
-- Time is accelerated by ticking large dt in a loop -- cash is never
-- edited to reach a goal (the only direct cash writes are test setup
-- for a fresh rival profile's starting wallet, which the game itself
-- grants at 100).
--
-- Out of scope here (cannot run headlessly): the Ferris Wheel sweep and
-- the Roblox-side steal prompt / carry wiring. Those are covered by the
-- user's Studio play-test, which is the final gate.
--
-- Run with: node scripts/run-tests.mjs   (from the repo root)

local BrainrotData = require("../src/shared/BrainrotData")
local Economy = require("../src/shared/Economy")
local BoothLogic = require("../src/shared/BoothLogic")

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

local function countBrainrots(profile)
	local n = 0
	for _ in pairs(profile.brainrots) do
		n += 1
	end
	return n
end

local function hasChar(profile, charId)
	for _, entry in pairs(profile.brainrots) do
		if entry.charId == charId then
			return true
		end
	end
	return false
end

-- A phase passes iff it added no failures.
local phaseMark = 0
local function phaseBegin()
	phaseMark = failed
end
local function phaseDone(name)
	check("PHASE " .. name, failed == phaseMark, (failed - phaseMark) .. " failure(s) in phase")
end

-- The steal flow as the server runs it: guard first, move second.
local function trySteal(thief, victim, slotIndex, now)
	local ok, reason = BoothLogic.canSteal(thief, victim, now)
	if not ok then
		return false, reason
	end
	return BoothLogic.applySteal(thief, victim, slotIndex)
end

-- ============================================================
-- Phase 1: a fresh player starts with 100 cash, empty booth.
-- ============================================================
phaseBegin()
local player = Economy.newProfile()
checkEq("1 start: cash 100", player.cash, 100)
checkEq("1 start: totalEarned 0", player.totalEarned, 0)
checkEq("1 start: rebirthLevel 0", player.rebirthLevel, 0)
checkEq("1 start: booth empty", countBrainrots(player), 0)
phaseDone("1 start profile")

-- ============================================================
-- Phase 2: buy Tung Tung Tung Sahur (Common, $25, 1/s).
-- ============================================================
phaseBegin()
local ok, reason = Economy.buyBrainrot(player, "tung_tung_sahur", "None")
check("2 buy tung: ok", ok == true, tostring(reason))
checkEq("2 buy tung: cash 100-25", player.cash, 75)
checkEq("2 buy tung: 1 brainrot", countBrainrots(player), 1)
checkEq("2 buy tung: slot 1 charId", player.brainrots[1].charId, "tung_tung_sahur")
phaseDone("2 buy Tung Tung Tung Sahur")

-- ============================================================
-- Phase 3: tick 120 s at 1/s -> +120 cash, +120 earned.
-- ============================================================
phaseBegin()
Economy.tickIncome(player, 120)
checkEq("3 tick 120s: cash 75+120", player.cash, 195)
checkEq("3 tick 120s: totalEarned 120", player.totalEarned, 120)
checkEq("3 tick 120s: income still 1/s", Economy.totalIncomePerSecond(player), 1)
phaseDone("3 tick 120s")

-- ============================================================
-- Phase 4: a Rare is still out of reach, then affordable.
-- ============================================================
phaseBegin()
local okRare, reasonRare = Economy.buyBrainrot(player, "tralalero_tralala", "None")
check("4 buy rare early: fails", okRare == false)
checkEq("4 buy rare early: reason", reasonRare, "Not enough cash")
Economy.tickIncome(player, 60) -- cash 195 + 60 = 255
checkEq("4 tick 60s: cash 255", player.cash, 255)
local okRare2, _ = Economy.buyBrainrot(player, "tralalero_tralala", "None")
check("4 buy rare: ok", okRare2 == true)
checkEq("4 buy rare: cash 255-250", player.cash, 5)
checkEq("4 buy rare: income 1+8 = 9/s", Economy.totalIncomePerSecond(player), 9)
phaseDone("4 buy a Rare")

-- ============================================================
-- Phase 5: tick 300 s at 9/s -> +2700.
-- ============================================================
phaseBegin()
Economy.tickIncome(player, 300)
checkEq("5 tick 300s: cash 5+2700", player.cash, 2705)
checkEq("5 tick 300s: totalEarned 120+60+2700", player.totalEarned, 2880)
phaseDone("5 tick 300s")

-- ============================================================
-- Phase 6: buy Speed Boots ($500) + Shield ($250).
-- ============================================================
phaseBegin()
local okBoots, _ = Economy.buyShopItem(player, "walkspeed")
check("6 buy speed boots: ok", okBoots == true)
local okShield, _ = Economy.buyShopItem(player, "shield")
check("6 buy shield: ok", okShield == true)
checkEq("6 shop: cash 2705-500-250", player.cash, 1955)
checkEq("6 shop: walkSpeed level 1", player.upgrades.walkSpeed, 1)
check("6 shop: shield active now", BoothLogic.isShielded(player, os.time()) == true)
phaseDone("6 buy Speed Boots + Shield")

-- ============================================================
-- Phase 7: a rival appears; steal one brainrot (success).
-- ============================================================
phaseBegin()
local rival = Economy.newProfile()
Economy.buyBrainrot(rival, "tung_tung_sahur", "None") -- slot 1
Economy.buyBrainrot(rival, "tung_tung_sahur", "None") -- slot 2, cash 50
checkEq("7 rival: 2 tungs, cash 50", rival.cash, 50)
local okSteal, stolen = trySteal(player, rival, 1, os.time())
check("7 steal: ok", okSteal == true, tostring(stolen))
checkEq("7 steal: stole tung_tung_sahur", stolen, "tung_tung_sahur")
checkEq("7 steal: player now 3 brainrots", countBrainrots(player), 3)
checkEq("7 steal: rival has 1 left", countBrainrots(rival), 1)
checkEq("7 steal: stolen entry mutation kept", player.brainrots[3].mutation, "None")
checkEq("7 steal: player income 1+8+1 = 10/s", Economy.totalIncomePerSecond(player), 10)
phaseDone("7 steal one brainrot (success)")

-- ============================================================
-- Phase 8: steal again with the rival's booth locked, then shielded.
-- ============================================================
phaseBegin()
-- Rival earns the lock: 1 tung left = 1/s, 500 s of ticks -> cash 550.
Economy.tickIncome(rival, 500)
checkEq("8 rival ticks 500s: cash 550", rival.cash, 550)
local okLock, _ = Economy.buyShopItem(rival, "lock")
check("8 rival buys lock: ok", okLock == true)
checkEq("8 rival buys lock: cash 50", rival.cash, 50)
local okStealLocked, reasonLocked = trySteal(player, rival, 1, os.time())
check("8 steal vs locked booth: fails", okStealLocked == false)
checkEq("8 steal vs locked booth: reason", reasonLocked, "Booth is locked")
checkEq("8 steal vs locked: rival keeps brainrot", countBrainrots(rival), 1)
checkEq("8 steal vs locked: player still 3", countBrainrots(player), 3)
-- The lock expires (simulated by clearing its expiry); rival shields instead.
rival.upgrades.lockUntil = 0
Economy.tickIncome(rival, 200) -- cash 50 + 200 = 250
local okShieldRival, _ = Economy.buyShopItem(rival, "shield")
check("8 rival buys shield: ok", okShieldRival == true)
checkEq("8 rival buys shield: cash 0", rival.cash, 0)
local okStealShield, reasonShield = trySteal(player, rival, 1, os.time())
check("8 steal vs shielded booth: fails", okStealShield == false)
checkEq("8 steal vs shielded booth: reason", reasonShield, "Shielded")
checkEq("8 steal vs shielded: rival keeps brainrot", countBrainrots(rival), 1)
checkEq("8 steal vs shielded: player still 3", countBrainrots(player), 3)
phaseDone("8 steal blocked by lock, then by shield")

-- ============================================================
-- Phase 9: grind to $50,000 by ticking 60 s at a time (10/s).
-- 1955 + 81 * 600 = 50555. Never by editing cash.
-- ============================================================
phaseBegin()
local grindTicks = 0
while player.cash < 50000 and grindTicks < 200 do
	Economy.tickIncome(player, 60)
	grindTicks += 1
end
checkEq("9 grind: 81 ticks of 60s", grindTicks, 81)
checkEq("9 grind: cash 50555", player.cash, 50555)
checkEq("9 grind: totalEarned 51480", player.totalEarned, 51480)
check("9 grind: canRebirth true", Economy.canRebirth(player) == true)
phaseDone("9 reach $50,000 via ticks")

-- ============================================================
-- Phase 10: rebirth resets cash to starting cash ($100) + booth, keeps
-- earnings + boots. (Starting cash, not 0, so the player can buy again.)
-- ============================================================
phaseBegin()
local okRebirth = Economy.rebirth(player)
check("10 rebirth: ok", okRebirth == true)
checkEq("10 rebirth: cash is starting cash", player.cash, 100)
checkEq("10 rebirth: booth emptied", countBrainrots(player), 0)
checkEq("10 rebirth: level 1", player.rebirthLevel, 1)
checkEq("10 rebirth: totalEarned kept 51480", player.totalEarned, 51480)
checkEq("10 rebirth: walkSpeed kept", player.upgrades.walkSpeed, 1)
check("10 rebirth: canRebirth now false", Economy.canRebirth(player) == false)
phaseDone("10 rebirth")

-- ============================================================
-- Phase 11: the rebirth multiplier applies to subsequent income.
-- A fresh rival's tung is stolen; 60 s at 1 * 1.5 = 1.5/s -> +90.
-- ============================================================
phaseBegin()
checkEq("11 multiplier: ips tung None r1 = 1.5", BrainrotData.incomePerSecond("tung_tung_sahur", "None", 1), 1.5)
local rival2 = Economy.newProfile()
Economy.buyBrainrot(rival2, "tung_tung_sahur", "None")
local okSteal2, _ = trySteal(player, rival2, 1, os.time())
check("11 steal after rebirth: ok", okSteal2 == true)
checkEq("11 steal after rebirth: income 1.5/s", Economy.totalIncomePerSecond(player), 1.5)
Economy.tickIncome(player, 60)
checkEq("11 tick 60s at 1.5/s: cash 190", player.cash, 190)
checkEq("11 tick 60s at 1.5/s: earned 51570", player.totalEarned, 51570)
phaseDone("11 rebirth multiplier on subsequent income")

-- ============================================================
-- Phase 12: serialize -> deserialize into a fresh profile.
-- ============================================================
phaseBegin()
local snap = Economy.serialize(player)
local restored = Economy.deserialize(snap)
check("12 save/load: deep equal", deepEqual(player, restored))
checkEq("12 save/load: cash 190", restored.cash, 190)
checkEq("12 save/load: 1 brainrot", countBrainrots(restored), 1)
checkEq("12 save/load: brainrot charId", restored.brainrots[1].charId, "tung_tung_sahur")
checkEq("12 save/load: brainrot mutation", restored.brainrots[1].mutation, "None")
checkEq("12 save/load: rebirthLevel 1", restored.rebirthLevel, 1)
checkEq("12 save/load: walkSpeed 1", restored.upgrades.walkSpeed, 1)
checkEq("12 save/load: totalEarned 51570", restored.totalEarned, 51570)
phaseDone("12 serialize + deserialize")

-- ============================================================
-- Phase 13: a second player session climbs the ladder to a Secret.
-- Buy better brainrots as soon as they are affordable, then tick on.
-- ============================================================
phaseBegin()
local climber = Economy.newProfile()
local function tickUntil(profile, target)
	local n = 0
	while profile.cash < target and n < 10000 do
		Economy.tickIncome(profile, 60)
		n += 1
	end
	return n
end
local function buyOrFail(profile, charId)
	local bOk, bReason = Economy.buyBrainrot(profile, charId, "None")
	check("13 buy " .. charId .. ": ok", bOk == true, tostring(bReason))
end

buyOrFail(climber, "tung_tung_sahur") -- 1/s, cash 75
check("13 ladder: reached 250", tickUntil(climber, 250) > 0 and climber.cash >= 250)
buyOrFail(climber, "tralalero_tralala") -- 9/s
check("13 ladder: reached 2000", tickUntil(climber, 2000) > 0 and climber.cash >= 2000)
buyOrFail(climber, "bombardiro_crocodilo") -- 39/s
check("13 ladder: reached 15000", tickUntil(climber, 15000) > 0 and climber.cash >= 15000)
buyOrFail(climber, "giraffa_celeste") -- 189/s
check("13 ladder: reached 100000", tickUntil(climber, 100000) > 0 and climber.cash >= 100000)
buyOrFail(climber, "pot_hotspot") -- 989/s
check("13 ladder: reached 500000", tickUntil(climber, 500000) > 0 and climber.cash >= 500000)
buyOrFail(climber, "garamararam") -- 5989/s
check("13 ladder: reached 2500000", tickUntil(climber, 2500000) > 0 and climber.cash >= 2500000)
local cashBeforeMeowl = climber.cash -- capture AFTER the final ticks, just before the buy
local okMeowl, _ = Economy.buyBrainrot(climber, "meowl", "None")
check("13 buy meowl (Secret): ok", okMeowl == true)
checkEq("13 buy meowl: cash = before - 2500000", climber.cash, cashBeforeMeowl - 2500000)
check("13 buy meowl: meowl in booth", hasChar(climber, "meowl"))
checkEq("13 buy meowl: rarity Secret", BrainrotData.getCharacter("meowl").rarity, "Secret")
checkEq("13 buy meowl: 7 brainrots owned", countBrainrots(climber), 7)
check("13 buy meowl: earned over $2.5M", climber.totalEarned > 2500000)
checkEq("13 buy meowl: income 30989/s", Economy.totalIncomePerSecond(climber), 30989)
phaseDone("13 second session buys a Secret-tier brainrot")

-- ============================================================
-- Summary
-- ============================================================

print(string.format("TOTAL: %d passed, %d failed", passed, failed))
if failed > 0 then
	error(failed .. " test(s) failed in tests/simulation.luau")
end
