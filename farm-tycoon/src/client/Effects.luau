-- Effects
-- Feedback visual: texto flutuante de venda, flash no level up, shake no rebirth.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)

local Effects = {}

local gui
local saleBuffer = 0
local flushAt = 0

function Effects.init(parentGui)
	gui = parentGui
end

local function makeLabel(text, color, size)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Theme.fontBlack
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.Size = UDim2.fromOffset(280, 34)
	label.TextStrokeTransparency = 0.5
	label.Parent = gui
	return label
end

function Effects.sale(amount)
	saleBuffer += amount
	local now = os.clock()
	if now < flushAt then
		return
	end
	flushAt = now + 0.55

	local total = saleBuffer
	saleBuffer = 0

	local label = makeLabel("+ " .. Format.money(total), Theme.green, 22)
	label.Position = UDim2.new(0.5, -140 + math.random(-40, 40), 0.62, 0)
	label.TextTransparency = 0.1
	label.Rotation = math.random(-4, 4)

	TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.fromOffset(0, 70),
		TextTransparency = 1,
	}):Play()

	task.delay(1.2, function()
		label:Destroy()
	end)
end

function Effects.levelUp()
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.cyan
	frame.BackgroundTransparency = 0.8
	frame.BorderSizePixel = 0
	frame.ZIndex = 50
	frame.Parent = gui

	TweenService:Create(frame, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	task.delay(0.5, function()
		frame:Destroy()
	end)

	local label = makeLabel("⬆️  LEVEL UP", Theme.cyan, 30)
	label.Size = UDim2.fromOffset(400, 60)
	label.Position = UDim2.new(0.5, -200, 0.4, 0)
	label.ZIndex = 51

	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.fromOffset(0, 60),
		TextTransparency = 1,
	}):Play()
	task.delay(1, function()
		label:Destroy()
	end)
end

function Effects.rebirth()
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.gold
	frame.BackgroundTransparency = 0.6
	frame.BorderSizePixel = 0
	frame.ZIndex = 60
	frame.Parent = gui

	TweenService:Create(frame, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
	task.delay(1, function()
		frame:Destroy()
	end)

	local label = makeLabel("♻️  REBIRTH!", Theme.gold, 44)
	label.Size = UDim2.fromOffset(600, 80)
	label.Position = UDim2.new(0.5, -300, 0.38, 0)
	label.ZIndex = 61
	label.Rotation = -6

	TweenService:Create(label, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.fromOffset(0, 90),
		TextTransparency = 1,
		Rotation = 6,
	}):Play()

	task.delay(1.5, function()
		label:Destroy()
	end)
end

return Effects
