-- Theme
-- Cores, fontes e fabricas de instancia da UI. Uma paleta so.

local Theme = {}

Theme.bg = Color3.fromRGB(16, 19, 26)
Theme.panel = Color3.fromRGB(24, 28, 38)
Theme.panelAlt = Color3.fromRGB(31, 36, 48)
Theme.stroke = Color3.fromRGB(52, 60, 78)
Theme.text = Color3.fromRGB(236, 241, 248)
Theme.dim = Color3.fromRGB(150, 160, 180)
Theme.green = Color3.fromRGB(96, 235, 148)
Theme.greenDark = Color3.fromRGB(38, 120, 78)
Theme.gold = Color3.fromRGB(255, 205, 80)
Theme.purple = Color3.fromRGB(178, 128, 255)
Theme.cyan = Color3.fromRGB(110, 224, 255)
Theme.red = Color3.fromRGB(255, 104, 104)

Theme.font = Enum.Font.GothamBold
Theme.fontBlack = Enum.Font.GothamBlack
Theme.fontBody = Enum.Font.GothamMedium

function Theme.corner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = instance
	return corner
end

function Theme.stroke(instance, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.stroke
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0.35
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

function Theme.padding(instance, px)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, px)
	pad.PaddingBottom = UDim.new(0, px)
	pad.PaddingLeft = UDim.new(0, px)
	pad.PaddingRight = UDim.new(0, px)
	pad.Parent = instance
	return pad
end

function Theme.gradient(instance, top, bottom, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = rotation or 90
	gradient.Parent = instance
	return gradient
end

function Theme.frame(parent, props)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = props.color or Theme.panel
	frame.BackgroundTransparency = props.transparency or 0
	frame.BorderSizePixel = 0
	frame.Size = props.size or UDim2.fromOffset(200, 100)
	frame.Position = props.position or UDim2.fromOffset(0, 0)
	frame.AnchorPoint = props.anchor or Vector2.zero
	frame.Parent = parent
	if props.radius ~= false then
		Theme.corner(frame, props.radius or 10)
	end
	if props.stroke ~= false then
		Theme.stroke(frame, props.strokeColor, props.strokeThickness)
	end
	if props.clips then
		frame.ClipsDescendants = true
	end
	return frame
end

function Theme.label(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = props.size or UDim2.fromScale(1, 1)
	label.Position = props.position or UDim2.fromOffset(0, 0)
	label.AnchorPoint = props.anchor or Vector2.zero
	label.Font = props.font or Theme.font
	label.Text = props.text or ""
	label.TextColor3 = props.color or Theme.text
	label.TextSize = props.textSize or 14
	label.TextXAlignment = props.xAlign or Enum.TextXAlignment.Left
	label.TextYAlignment = props.yAlign or Enum.TextYAlignment.Center
	label.TextScaled = props.scaled or false
	label.RichText = props.rich or false
	label.TextWrapped = props.wrapped or false
	label.ZIndex = props.zIndex or 1
	label.Parent = parent
	return label
end

function Theme.button(parent, props)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = props.color or Theme.panelAlt
	button.BackgroundTransparency = props.transparency or 0
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Size = props.size or UDim2.fromOffset(120, 36)
	button.Position = props.position or UDim2.fromOffset(0, 0)
	button.AnchorPoint = props.anchor or Vector2.zero
	button.Font = props.font or Theme.font
	button.Text = props.text or ""
	button.TextColor3 = props.textColor or Theme.text
	button.TextSize = props.textSize or 14
	button.LayoutOrder = props.layoutOrder or 0
	button.Parent = parent
	if props.radius ~= false then
		Theme.corner(button, props.radius or 8)
	end
	Theme.stroke(button, props.strokeColor or Theme.stroke, 1, 0.4)
	return button
end

function Theme.bar(parent, props)
	local track = Theme.frame(parent, {
		size = props.size or UDim2.new(1, 0, 0, 8),
		position = props.position,
		color = props.track or Color3.fromRGB(40, 46, 60),
		radius = 4,
		stroke = false,
	})
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = props.color or Theme.green
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(props.value or 0, 1)
	fill.Parent = track
	Theme.corner(fill, 4)
	return track, fill
end

-- Arrasta um painel pela alca (handle). Sem handle, so o proprio frame arrasta.
-- Nunca escuta cliques dos filhos: botoes continuam clicaveis.
function Theme.makeDraggable(frame, handle)
	local dragging = false
	local dragStart, startPos
	local UserInputService = game:GetService("UserInputService")

	local grip = handle or frame
	grip.Active = true
	grip.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local delta = input.Position - dragStart
			frame.Position =
				UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

return Theme
