-- tests/boothlogic.luau
-- Unit tests for BoothLogic (stealing: guards + the move itself).
-- Written from the API contract only. No Roblox services used.
-- Run with: node scripts/run-tests.mjs   (from the repo root)
--
-- NOTE on guard placement: canSteal is the guard. It rejects locked,
-- shielded, empty-victim and full-thief steals. applySteal ALSO
-- re-checks canSteal first (defence in depth), so a locked/shielded
-- victim can never be stolen from even if a caller skips the guard.

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

local function checkEq(name, got, want)
	check(name, got == want, tostring(got) .. " ~= " .. tostring(want))
end

local function countBrainrots(profile)
	local n = 0
	for _ in pairs(profile.brainrots) do
		n += 1
	end
	return n
end

-- now is a fake clock: all guard checks take an explicit timestamp,
-- so these tests never depend on wall-clock time.
local NOW = 5000

local function freshVictimWithTung(mutation)
	local v = Economy.newProfile()
	v.cash = 100000
	Economy.buyBrainrot(v, "tung_tung_sahur", mutation or "None")
	return v
end

local function fillThief()
	local t = Economy.newProfile()
	t.cash = 1000000
	for _ = 1, 8 do
		Economy.buyBrainrot(t, "tung_tung_sahur", "None")
	end
	return t
end

-- ============================================================
-- canSteal: the happy path
-- ============================================================

do
	local thief = Economy.newProfile()
	local victim = freshVictimWithTung("None")
	local ok, reason = BoothLogic.canSteal(thief, victim, NOW)
	check("canSteal true case: ok", ok == true, tostring(reason))
	check("canSteal true case: no reason", reason == nil)
end

-- ============================================================
-- canSteal: each refusal + its exact reason
-- ============================================================

do
	local thief = Economy.newProfile()
	local victim = freshVictimWithTung("None")
	victim.upgrades.lockUntil = NOW + 60
	local ok, reason = BoothLogic.canSteal(thief, victim, NOW)
	check("canSteal locked victim: fails", ok == false)
	checkEq("canSteal locked victim: reason", reason, "Booth is locked")
end

do
	local thief = Economy.newProfile()
	local victim = freshVictimWithTung("None")
	victim.upgrades.shieldUntil = NOW + 15
	local ok, reason = BoothLogic.canSteal(thief, victim, NOW)
	check("canSteal shielded victim: fails", ok == false)
	checkEq("canSteal shielded victim: reason", reason, "Shielded")
end

do
	local thief = Economy.newProfile()
	local victim = Economy.newProfile() -- empty booth
	local ok, reason = BoothLogic.canSteal(thief, victim, NOW)
	check("canSteal empty victim: fails", ok == false)
	checkEq("canSteal empty victim: reason", reason, "Victim booth is empty")
end

do
	local thief = fillThief()
	local victim = freshVictimWithTung("None")
	local ok, reason = BoothLogic.canSteal(thief, victim, NOW)
	check("canSteal full thief: fails", ok == false)
	checkEq("canSteal full thief: reason", reason, "Your booth is full")
end

-- ============================================================
-- canSteal: guard precedence (which refusal wins)
-- ============================================================

do
	-- Locked beats empty: a locked booth is refused as locked even with nothing in it.
	local thief = Economy.newProfile()
	local victim = Economy.newProfile()
	victim.upgrades.lockUntil = NOW + 60
	local ok, reason = BoothLogic.canSteal(thief, victim, NOW)
	check("precedence locked+empty: fails", ok == false)
	checkEq("precedence locked+empty: reason", reason, "Booth is locked")
end

do
	-- Shielded beats empty.
	local thief = Economy.newProfile()
	local victim = Economy.newProfile()
	victim.upgrades.shieldUntil = NOW + 15
	local ok, reason = BoothLogic.canSteal(thief, victim, NOW)
	check("precedence shielded+empty: fails", ok == false)
	checkEq("precedence shielded+empty: reason", reason, "Shielded")
end

do
	-- Empty victim beats full thief: nothing to steal is reported first.
	local thief = fillThief()
	local victim = Economy.newProfile()
	local ok, reason = BoothLogic.canSteal(thief, victim, NOW)
	check("precedence full-thief+empty-victim: fails", ok == false)
	checkEq("precedence full-thief+empty-victim: reason", reason, "Victim booth is empty")
end

-- ============================================================
-- isShielded / isLocked: boundary is strict (until > now)
-- ============================================================

do
	local p = Economy.newProfile()
	p.upgrades.shieldUntil = 1015
	p.upgrades.lockUntil = 2015
	check("isShielded 1s before expiry: true", BoothLogic.isShielded(p, 1014) == true)
	check("isShielded exactly at expiry: false", BoothLogic.isShielded(p, 1015) == false)
	check("isShielded 1s after expiry: false", BoothLogic.isShielded(p, 1016) == false)
	check("isLocked 1s before expiry: true", BoothLogic.isLocked(p, 2014) == true)
	check("isLocked exactly at expiry: false", BoothLogic.isLocked(p, 2015) == false)
	check("isLocked 1s after expiry: false", BoothLogic.isLocked(p, 2016) == false)
	check("isShielded fresh profile: false", BoothLogic.isShielded(Economy.newProfile(), NOW) == false)
	check("isLocked fresh profile: false", BoothLogic.isLocked(Economy.newProfile(), NOW) == false)
end

-- ============================================================
-- applySteal: moves the brainrot, mutation preserved
-- ============================================================

do
	local thief = Economy.newProfile()
	local victim = freshVictimWithTung("Gold")
	local thiefCashBefore = thief.cash
	local victimCashBefore = victim.cash
	local ok, stolen = BoothLogic.applySteal(thief, victim, 1)
	check("applySteal: ok", ok == true, tostring(stolen))
	checkEq("applySteal: returns stolen charId", stolen, "tung_tung_sahur")
	check("applySteal: thief now has it", thief.brainrots[1] ~= nil)
	checkEq("applySteal: thief entry charId", thief.brainrots[1].charId, "tung_tung_sahur")
	checkEq("applySteal: mutation preserved (Gold)", thief.brainrots[1].mutation, "Gold")
	checkEq("applySteal: thief entry slot", thief.brainrots[1].slot, 1)
	check("applySteal: victim slot freed", victim.brainrots[1] == nil)
	checkEq("applySteal: victim booth now empty", countBrainrots(victim), 0)
	checkEq("applySteal: thief cash untouched", thief.cash, thiefCashBefore)
	checkEq("applySteal: victim cash untouched", victim.cash, victimCashBefore)
end

do
	-- Stealing one of two leaves the other in place.
	local thief = Economy.newProfile()
	local victim = Economy.newProfile()
	victim.cash = 100000
	Economy.buyBrainrot(victim, "tung_tung_sahur", "None")
	Economy.buyBrainrot(victim, "chimpanzini_bananini", "Rainbow")
	local ok, stolen = BoothLogic.applySteal(thief, victim, 2)
	check("applySteal slot 2: ok", ok == true, tostring(stolen))
	checkEq("applySteal slot 2: returns chimp", stolen, "chimpanzini_bananini")
	checkEq("applySteal slot 2: thief got Rainbow", thief.brainrots[1].mutation, "Rainbow")
	check("applySteal slot 2: victim slot 1 kept", victim.brainrots[1] ~= nil and victim.brainrots[1].charId == "tung_tung_sahur")
	check("applySteal slot 2: victim slot 2 freed", victim.brainrots[2] == nil)
end

do
	-- A stolen brainrot lands in the thief's first free slot.
	local thief = Economy.newProfile()
	thief.cash = 100000
	Economy.buyBrainrot(thief, "lirili_larila", "None") -- occupies slot 1
	local victim = freshVictimWithTung("Diamond")
	local ok, _ = BoothLogic.applySteal(thief, victim, 1)
	check("applySteal into occupied slot 1: ok", ok == true)
	checkEq("applySteal: lands in slot 2", thief.brainrots[2].charId, "tung_tung_sahur")
	checkEq("applySteal: slot 2 mutation kept", thief.brainrots[2].mutation, "Diamond")
	checkEq("applySteal: slot 1 untouched", thief.brainrots[1].charId, "lirili_larila")
end

-- ============================================================
-- applySteal: failures
-- ============================================================

do
	local thief = Economy.newProfile()
	local victim = freshVictimWithTung("None")
	local ok, reason = BoothLogic.applySteal(thief, victim, 3)
	check("applySteal empty slot: fails", ok == false)
	checkEq("applySteal empty slot: reason", reason, "Empty slot")
	checkEq("applySteal empty slot: victim keeps brainrot", countBrainrots(victim), 1)
	checkEq("applySteal empty slot: thief still empty", countBrainrots(thief), 0)
end

do
	local thief = Economy.newProfile()
	local victim = freshVictimWithTung("None")
	local ok, reason = BoothLogic.applySteal(thief, victim, 9)
	check("applySteal slot 9: fails", ok == false)
	checkEq("applySteal slot 9: reason", reason, "Empty slot")
	checkEq("applySteal slot 9: victim keeps brainrot", countBrainrots(victim), 1)
end

do
	local thief = fillThief()
	local victim = freshVictimWithTung("None")
	local ok, reason = BoothLogic.applySteal(thief, victim, 1)
	check("applySteal into full booth: fails", ok == false)
	checkEq("applySteal into full booth: reason", reason, "Your booth is full")
	check("applySteal into full booth: victim keeps brainrot", victim.brainrots[1] ~= nil)
	checkEq("applySteal into full booth: thief still 8", countBrainrots(thief), 8)
end

-- ============================================================
-- Summary
-- ============================================================

print(string.format("TOTAL: %d passed, %d failed", passed, failed))
if failed > 0 then
	error(failed .. " test(s) failed in tests/boothlogic.luau")
end
