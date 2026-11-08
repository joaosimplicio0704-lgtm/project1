-- Toasts
-- Mensagens curtas no topo, no estilo dos tycoons (pílula branca com contorno).

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Toasts = {}

local container

function Toasts.init(gui)
	container = Instance.new("Frame")
	container.Name = "Toasts"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromOffset(420, 260)
	container.Position = UDim2.new(0.5, 0, 0, 130)
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Parent = gui

	Theme.list(container, { padding = 8 })
end

function Toasts.push(text, kind)
	if not container then
		return
	end

	local color = Color3.fromRGB(255, 255, 255)
	local textColor = Theme.textDark
	if kind == "error" then
		color = Color3.fromRGB(255, 200, 200)
		textColor = Color3.fromRGB(170, 50, 50)
	elseif kind == "success" then
		color = Color3.fromRGB(205, 255, 205)
		textColor = Color3.fromRGB(50, 130, 70)
	end

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(400, 46)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 1
	frame.ZIndex = 35
	frame.Parent = container
	Theme.corner(frame, 23)

	local label = Theme.label(frame, {
		text = text,
		size = UDim2.new(1, -28, 1, 0),
		position = UDim2.fromOffset(14, 0),
		textSize = 18,
		color = textColor,
		strokeTransparency = 1,
		zIndex = 36,
	})

	TweenService:Create(frame, TweenInfo.new(0.18), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(label, TweenInfo.new(0.18), { TextTransparency = 0 }):Play()

	task.delay(2.4, function()
		TweenService:Create(frame, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		frame:Destroy()
	end)
end

return Toasts
