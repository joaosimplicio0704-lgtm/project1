-- Toasts
-- Feedback curto no canto inferior direito. Fila vertical + fade.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Toasts = {}

local container

function Toasts.init(gui)
	container = Instance.new("Frame")
	container.Name = "Toasts"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromOffset(300, 260)
	container.Position = UDim2.new(1, -16, 1, -16)
	container.AnchorPoint = Vector2.new(1, 1)
	container.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = container
end

function Toasts.push(text, color)
	if not container then
		return
	end

	local frame = Theme.frame(container, {
		size = UDim2.new(1, 0, 0, 38),
		color = Theme.panel,
		transparency = 0.08,
		radius = 10,
	})
	frame.BackgroundTransparency = 1

	local label = Theme.label(frame, {
		text = text,
		size = UDim2.new(1, -20, 1, 0),
		position = UDim2.fromOffset(10, 0),
		font = Theme.font,
		textSize = 13,
		color = color or Theme.text,
		wrapped = true,
	})

	TweenService:Create(frame, TweenInfo.new(0.15), { BackgroundTransparency = 0.08 }):Play()
	TweenService:Create(label, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()

	task.delay(2.6, function()
		TweenService:Create(frame, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		frame:Destroy()
	end)
end

return Toasts
