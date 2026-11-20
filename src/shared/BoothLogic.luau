-- BoothLogic.luau
-- Shared booth steal / defend rules for Brainrot Carnival.
-- Pure Luau: no Roblox API calls, only math / string / table / os.
-- Requires the sibling BrainrotData module (Roblox `script.Parent` path, with
-- a relative-path fallback so the module also runs headlessly under the
-- Luau CLI for tests). Booths hold at most 8 brainrots (Economy.BOOTH_SLOTS).

local BrainrotData
if script ~= nil then
	-- Roblox: sibling ModuleScript.
	BrainrotData = require(script.Parent.BrainrotData)
else
	-- Luau CLI headless tests: relative file path.
	BrainrotData = require("./BrainrotData")
end

local BoothLogic = {}

-- Booth capacity, kept in sync with Economy.BOOTH_SLOTS.
local BOOTH_SLOTS = 8

-- True while the profile's shield timer is still running.
-- `now` defaults to os.time() when omitted.
function BoothLogic.isShielded(profile, now)
	local current = now or os.time()
	return current < profile.upgrades.shieldUntil
end

-- True while the profile's booth-lock timer is still running.
-- `now` defaults to os.time() when omitted.
function BoothLogic.isLocked(profile, now)
	local current = now or os.time()
	return current < profile.upgrades.lockUntil
end

-- Checks whether the thief may steal from the victim right now.
-- Returns (true), or (false, reason):
-- "Booth is locked" (victim locked), "Shielded" (victim shielded),
-- "Victim booth is empty", "Your booth is full" (thief has 8 brainrots).
function BoothLogic.canSteal(thiefProfile, victimProfile, now)
	local current = now or os.time()
	if BoothLogic.isLocked(victimProfile, current) then
		return false, "Booth is locked"
	end
	if BoothLogic.isShielded(victimProfile, current) then
		return false, "Shielded"
	end
	if #victimProfile.brainrots == 0 then
		return false, "Victim booth is empty"
	end
	if #thiefProfile.brainrots >= BOOTH_SLOTS then
		return false, "Your booth is full"
	end
	return true
end

-- Lowest free booth slot number (1..BOOTH_SLOTS), or nil when full.
local function firstFreeSlot(profile)
	local used = {}
	for _, owned in ipairs(profile.brainrots) do
		used[owned.slot] = true
	end
	for slot = 1, BOOTH_SLOTS do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

-- Moves the brainrot in the victim's slot into the thief's booth, at the
-- thief's first free slot. Returns (true, stolenCharId) on success, or
-- (false, reason): "Empty slot" (nothing in that victim slot),
-- "Your booth is full", "Unknown brainrot", plus the canSteal refusals
-- ("Booth is locked", "Shielded", "Victim booth is empty").
-- applySteal re-checks canSteal() itself first, so a locked/shielded
-- victim can never be stolen from even if a caller skips the guard.
function BoothLogic.applySteal(thiefProfile, victimProfile, slotIndex, now)
	local allowed, reason = BoothLogic.canSteal(thiefProfile, victimProfile, now)
	if not allowed then
		return false, reason
	end
	for index, owned in ipairs(victimProfile.brainrots) do
		if owned.slot == slotIndex then
			if BrainrotData.getCharacter(owned.charId) == nil then
				return false, "Unknown brainrot"
			end
			local slot = firstFreeSlot(thiefProfile)
			if slot == nil then
				return false, "Your booth is full"
			end
			local stolen = table.remove(victimProfile.brainrots, index)
			stolen.slot = slot
			table.insert(thiefProfile.brainrots, stolen)
			return true, stolen.charId
		end
	end
	return false, "Empty slot"
end

return BoothLogic
