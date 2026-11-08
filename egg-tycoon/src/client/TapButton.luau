-- TapButton
-- O botão gigante de toque no canto inferior direito, com o "+1" flutuando
-- igual aos prints. Também aceita clique direto no mundo (mouse) pra tocar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)

local TapButton = {}

local refs = {}
local gui
local onTap

local function spawnPlusOne(amount)
	local parent = refs.holder
	if not parent then
		return
	end

	local plus = Theme.label(parent, {
		text = "+" .. Format.number(amount),
		size = UDim2.fromOffset(150, 60),
		position = UDim2.fromScale(0.5, 0.1),
		anchor = Vector2.new(0.5, 1),
		textSize = 34,
		color = Theme.yellow,
		strokeTransparency = 0,
		strokeColor = Theme.outline,
		zIndex = 20,
	})
	plus.Rotation = math.random(-8, 8)

	TweenService:Create(plus, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = plus.Position - UDim2.fromScale(0, 0.5),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	task.delay(0.75, function()
		plus:Destroy()
	end)
end

function TapButton.build(parentGui, tapCallback)
	gui = parentGui
	onTap = tapCallback

	local holder = Instance.new("Frame")
	holder.Name = "TapHolder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(210, 210)
	holder.Position = UDim2.new(1, -30, 1, -30)
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.Parent = gui
	refs.holder = holder

	-- sombra
	local shadow = Instance.new("Frame")
	shadow.Size = UDim2.fromOffset(184, 184)
	shadow.Position = UDim2.fromOffset(8, 16)
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.BackgroundColor3 = Theme.shadow
	shadow.BackgroundTransparency = 0.55
	shadow.BorderSizePixel = 0
	shadow.Parent = holder
	Theme.corner(shadow, 46)

	-- botão
	local button = Instance.new("TextButton")
	button.Name = "TapButton"
	button.Size = UDim2.fromOffset(184, 184)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.BackgroundColor3 = Color3.fromRGB(110, 195, 250)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = holder
	Theme.corner(button, 46)
	Theme.stroke(button, Color3.fromRGB(70, 140, 210), 6)
	Theme.gradient(button, Color3.fromRGB(160, 225, 255), Color3.fromRGB(90, 170, 235))

	-- "dedo" desenhado com partes (sem asset)
	local finger = Theme.label(button, {
		text = "👆",
		size = UDim2.fromScale(0.72, 0.72),
		position = UDim2.fromScale(0.5, 0.44),
		anchor = Vector2.new(0.5, 0.5),
		textSize = 96,
		strokeTransparency = 1,
		zIndex = 5,
	})
	finger.Rotation = -12

	-- selo "+1" no topo, como no print
	local badgeFrame = Instance.new("Frame")
	badgeFrame.Size = UDim2.fromOffset(74, 44)
	badgeFrame.Position = UDim2.fromScale(0.62, 0.02)
	badgeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	badgeFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	badgeFrame.BorderSizePixel = 0
	badgeFrame.ZIndex = 8
	badgeFrame.Parent = holder
	Theme.corner(badgeFrame, 14)
	Theme.stroke(badgeFrame, Color3.fromRGB(60, 130, 200), 4)

	Theme.label(badgeFrame, {
		text = "+1",
		size = UDim2.fromScale(1, 1),
		textSize = 26,
		color = Color3.fromRGB(70, 150, 220),
		strokeTransparency = 1,
		zIndex = 9,
	})

	local scale = Instance.new("UIScale")
	scale.Parent = button

	local function doTap()
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		onTap()
	end

	button.MouseButton1Click:Connect(doTap)
	-- mobile: mousebutton1click cobre touch; adiciona também atalho espaço
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space then
			doTap()
		end
	end)

	refs.button = button
	refs.finger = finger

	local lastPower = 1
	State.subscribe(function(snapshot)
		lastPower = snapshot.tapPower or 1
		local badge = badgeFrame:FindFirstChildOfClass("TextLabel")
		if badge then
			badge.Text = "+" .. Format.number(lastPower)
		end
	end)

	return holder
end

function TapButton.showReward(amount)
	spawnPlusOne(amount)
end

return TapButton
