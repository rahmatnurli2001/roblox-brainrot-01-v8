-- Brainrot Carnival — Client
-- Main.client.luau
-- Built entirely in code. All game text is in English.
-- The server owns the BrainrotRemotes, the shop catalog, prompts,
-- saving, income, steals and events. This client only renders the HUD,
-- the shop, notifications, the leaderboard and the event banner, and
-- fires the remotes the server exposes. It never invents a remote.

-- ============================================================================
-- (a) Services + wait for BrainrotRemotes + GetProfile
-- ============================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local LocalPlayer = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local BuyBrainrot = remotes:WaitForChild("BuyBrainrot")
local DepositBrainrot = remotes:WaitForChild("DepositBrainrot")
local SellBrainrot = remotes:WaitForChild("SellBrainrot")
local StealBrainrot = remotes:WaitForChild("StealBrainrot")
local BuyShopItem = remotes:WaitForChild("BuyShopItem")
local UseShield = remotes:WaitForChild("UseShield")
local ToggleLock = remotes:WaitForChild("ToggleLock")
local Rebirth = remotes:WaitForChild("Rebirth")
local ProfileUpdate = remotes:WaitForChild("ProfileUpdate")
local Notify = remotes:WaitForChild("Notify")
local EventWarning = remotes:WaitForChild("EventWarning")
local LeaderboardUpdate = remotes:WaitForChild("LeaderboardUpdate")
local GetProfile = remotes:WaitForChild("GetProfile")

-- Keep references to every remote so none is silently unused: the buy /
-- deposit / sell / steal remotes are driven by the server-created
-- ProximityPrompts, and this client watches those prompts (see the
-- carrying tracker at the bottom) instead of firing them blindly.
local _promptRemotes = { BuyBrainrot, DepositBrainrot, SellBrainrot, StealBrainrot }

-- ============================================================================
-- Helpers
-- ============================================================================
local REBIRTH_COST = 50000
local MAX_SLOTS = 8
local MAX_SPEED_LEVEL = 3

local function formatMoney(amount)
	amount = math.floor(tonumber(amount) or 0)
	local negative = amount < 0
	if negative then
		amount = -amount
	end
	local text = tostring(amount)
	local out = ""
	while #text > 3 do
		out = "," .. string.sub(text, -3) .. out
		text = string.sub(text, 1, -4)
	end
	out = text .. out
	if negative then
		return "-$" .. out
	end
	return "$" .. out
end

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	inst.Parent = parent or props.Parent
	return inst
end

-- Dark floating-panel palette, modelled on the top entries: near-black
-- navy panels with bright outlines, big white/green numbers, no
-- full-width bars and no yellow anywhere.
-- NOTE: these locals MUST stay above the style helpers below — Luau
-- locals are only visible to code written after their declaration, and
-- styleButton reads BTN / WHITE / LIGHT_GREY.
local NAVY = Color3.fromRGB(16, 22, 44)
local BTN = Color3.fromRGB(28, 36, 62)
local WHITE = Color3.fromRGB(255, 255, 255)
local CYAN = Color3.fromRGB(0, 200, 220)
local DARK = Color3.fromRGB(30, 30, 30)
local GREEN = Color3.fromRGB(0, 220, 120)
local MONEY_GREEN = Color3.fromRGB(80, 230, 130)
local LIGHT_GREY = Color3.fromRGB(200, 205, 220)
local ORANGE = Color3.fromRGB(255, 140, 0)
local RED = Color3.fromRGB(220, 40, 40)
local GREY = Color3.fromRGB(170, 170, 170)
-- Single outline colour shared by the whole bottom bar (bar frame,
-- all four buttons, both stat pills): one uniform look, no per-item hue.
local BAR_STROKE = Color3.fromRGB(70, 85, 130)

local function stylePanel(frame, color)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, frame)
end

-- Dark floating buttons, top-3 style: dark navy fill, white bold text,
-- and a bright coloured outline (the colour argument is the outline).
-- Returns the UIStroke so callers can recolour it later.
local function styleButton(button, strokeColor)
	button.BackgroundColor3 = BTN
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = WHITE
	button.TextSize = 16
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
	return create("UIStroke", {
		Color = strokeColor or LIGHT_GREY,
		Thickness = 2,
	}, button)
end

-- ============================================================================
-- Local state
-- ============================================================================
local currentCash = 0
local currentBrainrotCount = 0
local carryingName = nil
local lastShieldTime = 0
local notificationCount = 0

-- ============================================================================
-- (b) HUD — one ScreenGui "CarnivalHUD", built entirely in code
-- ============================================================================
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local screenGui = create("ScreenGui", {
	Name = "CarnivalHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
}, playerGui)

-- (Palette moved above the style helpers; see the NOTE there.)

-- Top HUD — floating dark money panel, top-3 style -------------------------
-- No full-width bar: the 3D world stays visible at the top. One dark
-- navy rounded panel, centred, with a bright green outline: big white
-- cash, green "+$X/sec" below, small rebirth multiplier line under
-- that. Nothing else floats under this panel: the booth count and
-- rebirth level live in the bottom bar (see below), so no HUD element
-- ever covers a brainrot's overhead tag in the play area.
local moneyPanel = create("Frame", {
	Name = "MoneyPanel",
	Size = UDim2.new(0, 300, 0, 108),
	Position = UDim2.new(0.5, -150, 0, 8),
	BackgroundColor3 = NAVY,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
}, screenGui)
create("UICorner", { CornerRadius = UDim.new(0, 14) }, moneyPanel)
create("UIStroke", {
	Color = GREEN,
	Thickness = 2,
}, moneyPanel)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 2),
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, moneyPanel)
create("UIPadding", {
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 8),
}, moneyPanel)

local cashLabel = create("TextLabel", {
	Name = "CashLabel",
	Size = UDim2.new(1, 0, 0, 42),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 32,
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "$0",
	LayoutOrder = 1,
}, moneyPanel)

local incomeLabel = create("TextLabel", {
	Name = "IncomeLabel",
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = MONEY_GREEN,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "+$0/sec",
	LayoutOrder = 2,
}, moneyPanel)

local multLabel = create("TextLabel", {
	Name = "RebirthMultLabel",
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = LIGHT_GREY,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "x1.0 MULT",
	LayoutOrder = 3,
}, moneyPanel)

-- Carrying label (hidden unless the player is carrying a brainrot).
-- Anchored to the right, just left of the leaderboard (10px gap), so it
-- can never slide under the leaderboard on narrow windows the way a
-- centred label would.
local carryingLabel = create("TextLabel", {
	Name = "CarryingLabel",
	Size = UDim2.new(0, 380, 0, 34),
	Position = UDim2.new(1, -260, 0, 64),
	BackgroundColor3 = CYAN,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = DARK,
	Text = "",
	Visible = false,
}, screenGui)
create("UICorner", { CornerRadius = UDim.new(0, 8) }, carryingLabel)

local function updateCarrying()
	if carryingName and carryingName ~= "" then
		carryingLabel.Text = "Carrying: " .. carryingName
		carryingLabel.Visible = true
	else
		carryingLabel.Text = ""
		carryingLabel.Visible = false
	end
end

-- Event banner (hidden by default) ------------------------------------------
-- Centred below the leaderboard (y 392): clear of the leaderboard above,
-- the feed on the left, and the bottom button bar below on any window.
local eventBanner = create("Frame", {
	Name = "EventBanner",
	Size = UDim2.new(0, 560, 0, 44),
	Position = UDim2.new(0.5, -280, 0, 392),
	BackgroundColor3 = ORANGE,
	BorderSizePixel = 0,
	Visible = false,
}, screenGui)
create("UICorner", { CornerRadius = UDim.new(0, 10) }, eventBanner)

local eventBannerLabel = create("TextLabel", {
	Name = "EventBannerLabel",
	Size = UDim2.new(1, -16, 1, 0),
	Position = UDim2.new(0, 8, 0, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = WHITE,
	TextWrapped = true,
	Text = "",
}, eventBanner)

-- Notification feed (top-LEFT now, newest on top, fades after 4 s): it
-- moved here from the top-right so it never stacks with the leaderboard
-- panel, which now sits under the top bar on the right. It starts at
-- y 220, below the money panel (which ends at y 116), and ends at
-- y 380 — above the event banner (y 392) — so a toast never covers
-- the banner on any window width.
local feedFrame = create("Frame", {
	Name = "NotificationFeed",
	Size = UDim2.new(0, 320, 0, 160),
	Position = UDim2.new(0, 10, 0, 220),
	BackgroundTransparency = 1,
}, screenGui)
create("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6),
}, feedFrame)

local function addNotification(text, color)
	notificationCount = notificationCount + 1
	local note = create("TextLabel", {
		Name = "Notification",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = color or WHITE,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = DARK,
		TextWrapped = true,
		Text = tostring(text or ""),
		LayoutOrder = -notificationCount,
	}, feedFrame)
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, note)
	task.delay(4, function()
		local tween = TweenService:Create(note, TweenInfo.new(0.5), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
		note:Destroy()
	end)
end

-- Leaderboard panel (right side, "TOP EARNERS", 10 rows) -------------------
-- It sits directly under the top bar (y 64, bottom 384), so on any window
-- it can never reach the bottom button bar (whose top is H-132, i.e. 468
-- even on a short 600px-tall window): no button ever sits under it.
-- Dark navy panel with a green outline, white text, top-3 style.
local leaderboardFrame = create("Frame", {
	Name = "LeaderboardPanel",
	Size = UDim2.new(0, 240, 0, 320),
	Position = UDim2.new(1, -250, 0, 64),
	BackgroundColor3 = NAVY,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
}, screenGui)
stylePanel(leaderboardFrame, NAVY)
create("UIStroke", {
	Color = GREEN,
	Thickness = 2,
}, leaderboardFrame)

create("TextLabel", {
	Name = "Title",
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = WHITE,
	Text = "TOP EARNERS",
}, leaderboardFrame)

local leaderboardList = create("Frame", {
	Name = "Rows",
	Size = UDim2.new(1, -12, 1, -40),
	Position = UDim2.new(0, 6, 0, 36),
	BackgroundTransparency = 1,
}, leaderboardFrame)
create("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 2),
}, leaderboardList)

local function rebuildLeaderboard(entries)
	for _, child in ipairs(leaderboardList:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	entries = entries or {}
	for i = 1, math.min(10, #entries) do
		local entry = entries[i]
		local name = "Player"
		local total = 0
		if type(entry) == "table" then
			name = entry.name or "Player"
			total = entry.totalEarned or 0
		end
		create("TextLabel", {
			Name = "Row" .. tostring(i),
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = tostring(i) .. ". " .. tostring(name) .. " — " .. formatMoney(total),
			LayoutOrder = i,
		}, leaderboardList)
	end
	if #entries == 0 then
		create("TextLabel", {
			Name = "RowEmpty",
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 15,
			TextColor3 = LIGHT_GREY,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "No earners yet — be the first!",
			LayoutOrder = 1,
		}, leaderboardList)
	end
end
rebuildLeaderboard({})

-- Bottom bar: Shop (B), Shield (Q), Lock, Rebirth + SLOTS + REBIRTH LV ----
-- One row, everything in it: the four action buttons first, then the
-- booth count and rebirth level as small dark pills with coloured
-- outlines. The pills used to float under the money panel, where they
-- covered brainrot overhead tags — now they ride inside this bar, so
-- nothing floats over the play area. Width math (all fixed sizes, gaps
-- of 8, side padding 10+10): 100 + 100 + 100 + 160 + 95 + 115 = 670,
-- + 5 gaps x 8 = 40, + padding 20 = 730, inside a 740px bar. The bar
-- is centred, so at 800px wide it spans x 30..770 — clear of both
-- screen edges and, vertically (H-72..H-12), always below the
-- leaderboard (which ends at y 384). Dark navy panel with a muted
-- outline, dark buttons with bright coloured outlines, top-3 style.
local bottomBar = create("Frame", {
	Name = "BottomBar",
	Size = UDim2.new(1, -24, 0, 60),
	Position = UDim2.new(0.5, 0, 1, -72),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = NAVY,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
}, screenGui)
stylePanel(bottomBar, NAVY)
create("UIStroke", {
	Color = BAR_STROKE,
	Thickness = 2,
}, bottomBar)
-- The bar never exceeds 740 wide and never runs off-screen: on narrow
-- windows it shrinks to (viewport - 24) instead of clipping the last pill.
create("UISizeConstraint", {
	MaxSize = Vector2.new(740, 60),
}, bottomBar)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, bottomBar)
create("UIPadding", {
	PaddingTop = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 6),
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
}, bottomBar)

local shopButton = create("TextButton", {
	Name = "ShopButton",
	Size = UDim2.new(0.134, 0, 0, 46),
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = DARK,
	Text = "Shop (B)",
	LayoutOrder = 1,
}, bottomBar)
styleButton(shopButton, BAR_STROKE)
-- Fixed 14pt (styleButton sets 16; this overrides it). TextScaled is
-- OFF so all six bar labels render at exactly the same size and font.
shopButton.TextSize = 14

local shieldButton = create("TextButton", {
	Name = "ShieldButton",
	Size = UDim2.new(0.134, 0, 0, 46),
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = DARK,
	Text = "Shield (Q)",
	LayoutOrder = 2,
}, bottomBar)
styleButton(shieldButton, BAR_STROKE)
shieldButton.TextSize = 14

local lockButton = create("TextButton", {
	Name = "LockButton",
	Size = UDim2.new(0.134, 0, 0, 46),
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = DARK,
	Text = "Lock Booth",
	LayoutOrder = 3,
}, bottomBar)
styleButton(lockButton, BAR_STROKE)
lockButton.TextSize = 14

local rebirthButton = create("TextButton", {
	Name = "RebirthButton",
	Size = UDim2.new(0.214, 0, 0, 46),
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = DARK,
	Text = "Rebirth — $50,000",
	LayoutOrder = 4,
}, bottomBar)
styleButton(rebirthButton, BAR_STROKE)
rebirthButton.TextSize = 14

-- Booth-count and rebirth-level pills, riding inside the bottom bar
-- (moved here from under the money panel so they never cover a
-- brainrot's overhead tag). Same values, same update code — only the
-- parent changed.
-- widthScale is a fraction of the bar width, so the pills shrink with
-- the bar on narrow windows instead of running off-screen.
local function bottomStatPill(widthScale, strokeColor, order)
	local pill = create("Frame", {
		Name = "BottomStatPill",
		Size = UDim2.new(widthScale, 0, 0, 46),
		BackgroundColor3 = BTN,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, bottomBar)
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, pill)
	create("UIStroke", {
		Color = strokeColor,
		Thickness = 2,
	}, pill)
	return pill
end

local countPill = bottomStatPill(0.127, BAR_STROKE, 5)
local countLabel = create("TextLabel", {
	Name = "BrainrotCountLabel",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "SLOTS 0/8",
}, countPill)

local rebirthStatPill = bottomStatPill(0.154, BAR_STROKE, 6)
local rebirthLabel = create("TextLabel", {
	Name = "RebirthLabel",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "REBIRTH LV 0",
}, rebirthStatPill)

-- Rebirth affordability is shown ONLY by dimming the same white text
-- (TextTransparency); the font, hue, fill and outline never change.
local function updateRebirthButton()
	if currentCash >= REBIRTH_COST then
		rebirthButton.TextTransparency = 0
	else
		rebirthButton.TextTransparency = 0.5
	end
end

-- ============================================================================
-- (c) Shop UI — Frame, hidden by default, B toggles
-- ============================================================================
local shopFrame = create("Frame", {
	Name = "ShopFrame",
	Size = UDim2.new(0, 440, 0, 380),
	Position = UDim2.new(0.5, -220, 0.5, -190),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	Visible = false,
}, screenGui)
stylePanel(shopFrame, WHITE)

create("TextLabel", {
	Name = "ShopTitle",
	Size = UDim2.new(1, -50, 0, 40),
	Position = UDim2.new(0, 10, 0, 6),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	TextColor3 = DARK,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "CARNIVAL SHOP",
}, shopFrame)

local shopCloseButton = create("TextButton", {
	Name = "CloseButton",
	Size = UDim2.new(0, 36, 0, 36),
	Position = UDim2.new(1, -44, 0, 6),
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = DARK,
	Text = "X",
}, shopFrame)
styleButton(shopCloseButton, RED)

local shopList = create("Frame", {
	Name = "ShopList",
	Size = UDim2.new(1, -20, 1, -56),
	Position = UDim2.new(0, 10, 0, 48),
	BackgroundTransparency = 1,
}, shopFrame)
create("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, shopList)

local speedBuyButton = nil
local speedDescLabel = nil

local function makeShopRow(order, itemId, itemName, itemDesc, priceText, buyText)
	local row = create("Frame", {
		Name = "Row_" .. itemId,
		Size = UDim2.new(1, 0, 0, 68),
		BackgroundColor3 = Color3.fromRGB(240, 248, 255),
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, shopList)
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, row)

	create("TextLabel", {
		Name = "ItemName",
		Size = UDim2.new(1, -120, 0, 24),
		Position = UDim2.new(0, 10, 0, 6),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = DARK,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = itemName,
	}, row)

	local desc = create("TextLabel", {
		Name = "ItemDesc",
		Size = UDim2.new(1, -120, 0, 34),
		Position = UDim2.new(0, 10, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(70, 70, 70),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = itemDesc,
	}, row)

	create("TextLabel", {
		Name = "ItemPrice",
		Size = UDim2.new(0, 100, 0, 20),
		Position = UDim2.new(1, -110, 0, 8),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = GREEN,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = priceText,
	}, row)

	local buyButton = create("TextButton", {
		Name = "BuyButton",
		Size = UDim2.new(0, 100, 0, 32),
		Position = UDim2.new(1, -110, 0, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = DARK,
		Text = buyText,
	}, row)
	styleButton(buyButton, GREEN)
	buyButton.MouseButton1Click:Connect(function()
		BuyShopItem:FireServer(itemId)
	end)
	return row, desc, buyButton
end

do
	local _, desc, buyButton = makeShopRow(1, "walkspeed", "Speed Boots", "Walk faster. Level 0/3.", "$500 / level", "BUY $500")
	speedDescLabel = desc
	speedBuyButton = buyButton
	makeShopRow(2, "boost", "Income Boost", "Double income for 60 seconds", "$1,000", "BUY $1,000")
	makeShopRow(3, "shield", "Shield", "Protect your brainrots for 15 seconds", "$250", "BUY $250")
	makeShopRow(4, "lock", "Booth Lock", "Lock your booth for 60 seconds", "$500", "BUY $500")
end

local function toggleShop()
	shopFrame.Visible = not shopFrame.Visible
end

shopButton.MouseButton1Click:Connect(toggleShop)
shopCloseButton.MouseButton1Click:Connect(function()
	shopFrame.Visible = false
end)

-- ============================================================================
-- Shared actions for the bottom bar + keyboard
-- ============================================================================
local function fireShield()
	local now = os.clock()
	if now - lastShieldTime < 1 then
		return
	end
	lastShieldTime = now
	UseShield:FireServer()
end

shieldButton.MouseButton1Click:Connect(fireShield)

lockButton.MouseButton1Click:Connect(function()
	ToggleLock:FireServer()
end)

rebirthButton.MouseButton1Click:Connect(function()
	if currentCash >= REBIRTH_COST then
		Rebirth:FireServer()
	else
		addNotification("You need $50,000 to rebirth!", ORANGE)
	end
end)

-- ============================================================================
-- (d) Input: B toggles the shop, Q uses the shield
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		toggleShop()
	elseif input.KeyCode == Enum.KeyCode.Q then
		fireShield()
	end
end)

-- ============================================================================
-- (e) Listeners
-- ============================================================================
local function applyProfile(profile)
	if type(profile) ~= "table" then
		return
	end

	currentCash = tonumber(profile.cash) or 0
	cashLabel.Text = formatMoney(currentCash)

	local incomePerSec = profile.incomePerSec or profile.income or 0
	incomeLabel.Text = "+" .. formatMoney(tonumber(incomePerSec) or 0) .. "/sec"

	local brainrots = profile.brainrots or {}
	local count = #brainrots
	-- A brainrot only joins the profile list once it is deposited, so a
	-- count increase while carrying means the carried brainrot arrived
	-- at the booth: stop showing "Carrying: ...".
	if carryingName and count > currentBrainrotCount then
		carryingName = nil
		updateCarrying()
	end
	currentBrainrotCount = count
	countLabel.Text = "SLOTS " .. tostring(count) .. "/" .. tostring(MAX_SLOTS)

	local rebirthLevel = tonumber(profile.rebirthLevel) or 0
	rebirthLabel.Text = "REBIRTH LV " .. tostring(rebirthLevel)
	-- Permanent income multiplier: +50% per rebirth level
	-- (Economy.rebirthMultiplier). Shown small under the income.
	multLabel.Text = string.format("x%.1f MULT", 1 + 0.5 * rebirthLevel)
	updateRebirthButton()

	local upgrades = profile.upgrades or {}
	local speedLevel = tonumber(upgrades.walkSpeed) or 0
	if speedDescLabel then
		speedDescLabel.Text = "Walk faster. Level " .. tostring(speedLevel) .. "/" .. tostring(MAX_SPEED_LEVEL) .. "."
	end
	if speedBuyButton then
		local stroke = speedBuyButton:FindFirstChildOfClass("UIStroke")
		if speedLevel >= MAX_SPEED_LEVEL then
			speedBuyButton.Text = "MAX"
			speedBuyButton.TextColor3 = Color3.fromRGB(140, 145, 160)
			if stroke then
				stroke.Color = GREY
			end
		else
			speedBuyButton.Text = "BUY $500"
			speedBuyButton.TextColor3 = WHITE
			if stroke then
				stroke.Color = GREEN
			end
		end
	end
end

ProfileUpdate.OnClientEvent:Connect(applyProfile)

Notify.OnClientEvent:Connect(function(data)
	if type(data) == "table" then
		local color = WHITE
		if typeof(data.color) == "Color3" then
			color = data.color
		end
		addNotification(data.text or "", color)
	elseif type(data) == "string" then
		addNotification(data, WHITE)
	end
end)

EventWarning.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	local phase = data.phase or "clear"
	if phase == "clear" then
		eventBanner.Visible = false
		eventBannerLabel.Text = ""
	elseif phase == "warning" then
		local seconds = tonumber(data.secondsLeft) or 10
		eventBanner.BackgroundColor3 = ORANGE
		eventBannerLabel.Text = "RUNAWAY FERRIS WHEEL IN " .. tostring(seconds) .. "s — RUN TO YOUR BOOTH!"
		eventBanner.Visible = true
	elseif phase == "active" then
		eventBanner.BackgroundColor3 = RED
		eventBannerLabel.Text = "FERRIS WHEEL SWEEP! STAY IN YOUR BOOTH!"
		eventBanner.Visible = true
	end
end)

LeaderboardUpdate.OnClientEvent:Connect(function(entries)
	if type(entries) == "table" then
		rebuildLeaderboard(entries)
	end
end)

-- Carrying tracker: the server creates the ProximityPrompts on parade
-- brainrots and pedestals. When the local player triggers one, this is
-- the client-side signal that a buy (or a deposit) just happened, so the
-- "Carrying: ..." label can follow it without any new remote. The
-- ProfileUpdate count check above clears it again once the brainrot
-- is deposited.
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if player ~= LocalPlayer then
		return
	end
	local action = prompt.ActionText or ""
	if string.find(action, "Deposit") then
		carryingName = nil
		updateCarrying()
	elseif string.find(action, "Buy") then
		local name = prompt.ObjectText or ""
		if name == "" and prompt.Parent then
			name = prompt.Parent.Name or ""
		end
		if name == "" then
			name = "Brainrot"
		end
		carryingName = name
		updateCarrying()
	end
end)

-- If the character respawns, anything being carried is dropped, so the
-- "Carrying: ..." label must not survive the respawn.
LocalPlayer.CharacterAdded:Connect(function()
	carryingName = nil
	updateCarrying()
end)

-- ============================================================================
-- (f) On join: call GetProfile once to populate the HUD immediately
-- ============================================================================
local ok, profile = pcall(function()
	return GetProfile:InvokeServer()
end)
if ok and type(profile) == "table" then
	applyProfile(profile)
else
	addNotification("Could not load your profile. Please rejoin if the HUD stays empty.", ORANGE)
end
