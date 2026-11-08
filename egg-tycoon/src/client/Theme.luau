-- Theme
-- Visual cartoon dos tycoons de ovo: cantos bem grandes, contorno escuro
-- grosso, gradiente pastel, sombra chapada embaixo. Fonte FredokaOne.
-- Nada de painel cinza de programador.

local Theme = {}

Theme.text = Color3.fromRGB(255, 255, 255)
Theme.textDark = Color3.fromRGB(74, 52, 38)
Theme.outline = Color3.fromRGB(64, 44, 30)

Theme.green = Color3.fromRGB(126, 217, 87)
Theme.greenDark = Color3.fromRGB(74, 160, 60)
Theme.yellow = Color3.fromRGB(255, 206, 61)
Theme.yellowDark = Color3.fromRGB(226, 158, 26)
Theme.blue = Color3.fromRGB(96, 186, 255)
Theme.blueDark = Color3.fromRGB(52, 132, 216)
Theme.purple = Color3.fromRGB(178, 130, 255)
Theme.purpleDark = Color3.fromRGB(124, 78, 205)
Theme.pink = Color3.fromRGB(255, 138, 190)
Theme.pinkDark = Color3.fromRGB(215, 84, 145)
Theme.red = Color3.fromRGB(255, 106, 106)
Theme.cyan = Color3.fromRGB(96, 240, 235)
Theme.white = Color3.fromRGB(255, 252, 245)
Theme.panel = Color3.fromRGB(255, 248, 232)
Theme.panelStroke = Color3.fromRGB(206, 168, 116)
Theme.shadow = Color3.fromRGB(38, 26, 18)

Theme.font = Enum.Font.FredokaOne
Theme.fontBody = Enum.Font.FredokaOne
Theme.fontNum = Enum.Font.FredokaOne

local function corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 18)
	c.Parent = instance
	return c
end
Theme.corner = corner

local function stroke(instance, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.outline
	s.Thickness = thickness or 3
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = instance
	return s
end
Theme.stroke = stroke

local function gradient(instance, top, bottom, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = rotation or 90
	g.Parent = instance
	return g
end
Theme.gradient = gradient

-- botão principal: pílula com gradiente, contorno grosso e sombra
function Theme.button(parent, props)
	local button = Instance.new("TextButton")
	button.Name = props.name or "Button"
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Size = props.size or UDim2.fromOffset(200, 56)
	button.Position = props.position or UDim2.fromOffset(0, 0)
	button.AnchorPoint = props.anchor or Vector2.zero
	button.Font = props.font or Theme.font
	button.Text = props.text or ""
	button.TextColor3 = props.textColor or Theme.text
	button.TextSize = props.textSize or 22
	button.TextStrokeTransparency = props.textStrokeTransparency or 0.25
	button.TextStrokeColor3 = Theme.outline
	button.BackgroundColor3 = props.color or Theme.green
	button.LayoutOrder = props.layoutOrder or 0
	button.ZIndex = props.zIndex or 2
	button.Parent = parent

	corner(button, props.radius or (button.AbsoluteSize.Y > 0 and math.floor(button.AbsoluteSize.Y / 2) or 22))
	stroke(button, props.strokeColor or Theme.outline, props.strokeThickness or 3)
	gradient(button, props.gradientTop or Color3.new(1, 1, 1), props.gradientBottom or Color3.fromRGB(228, 228, 228))

	if props.shadow ~= false then
		local shadow = Instance.new("Frame")
		shadow.Name = "Shadow"
		shadow.BackgroundColor3 = props.shadowColor or Theme.shadow
		shadow.BackgroundTransparency = 0.6
		shadow.BorderSizePixel = 0
		shadow.Size = UDim2.fromScale(1, 1)
		shadow.Position = UDim2.fromOffset(0, props.shadowOffset or 5)
		shadow.ZIndex = button.ZIndex - 1
		shadow.Parent = parent
		corner(shadow, props.radius or 22)
		stroke(shadow, Theme.outline, props.strokeThickness or 3)
		shadow.LayoutOrder = -1

		button.AncestryChanged:Connect(function()
			shadow:Destroy()
		end)

		-- acompanha posição e tamanho do botão
		local function sync()
			shadow.Position = button.Position + UDim2.fromOffset(0, props.shadowOffset or 5)
			shadow.Size = button.Size
			shadow.AnchorPoint = button.AnchorPoint
			shadow.Visible = button.Visible
		end
		button:GetPropertyChangedSignal("Position"):Connect(sync)
		button:GetPropertyChangedSignal("Size"):Connect(sync)
		button:GetPropertyChangedSignal("Visible"):Connect(sync)
		sync()
	end

	-- feedback de press
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseButton1Down:Connect(function()
		scale.Scale = 0.94
	end)
	button.MouseButton1Up:Connect(function()
		scale.Scale = 1
	end)
	button.MouseLeave:Connect(function()
		scale.Scale = 1
	end)

	return button
end

function Theme.panel(parent, props)
	local frame = Instance.new("Frame")
	frame.Name = props.name or "Panel"
	frame.BackgroundColor3 = props.color or Theme.panel
	frame.BorderSizePixel = 0
	frame.Size = props.size or UDim2.fromOffset(420, 520)
	frame.Position = props.position or UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = props.anchor or Vector2.new(0.5, 0.5)
	frame.ZIndex = props.zIndex or 10
	frame.Parent = parent

	corner(frame, props.radius or 26)
	stroke(frame, props.strokeColor or Theme.panelStroke, 4)
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
	label.TextSize = props.textSize or 20
	label.TextXAlignment = props.xAlign or Enum.TextXAlignment.Center
	label.TextYAlignment = props.yAlign or Enum.TextYAlignment.Center
	label.TextScaled = props.scaled or false
	label.TextWrapped = props.wrapped or false
	label.RichText = props.rich or false
	label.TextStrokeTransparency = props.stroke == false and 1 or (props.strokeTransparency or 0.35)
	label.TextStrokeColor3 = props.strokeColor or Theme.outline
	label.ZIndex = props.zIndex or 2
	label.LayoutOrder = props.layoutOrder or 0
	label.Parent = parent
	return label
end

-- container vertical com espaçamento
function Theme.list(parent, props)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = props and props.direction or Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, props and props.padding or 10)
	layout.HorizontalAlignment = props and props.hAlign or Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = props and props.vAlign or Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

function Theme.padding(parent, px)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, px)
	pad.PaddingBottom = UDim.new(0, px)
	pad.PaddingLeft = UDim.new(0, px)
	pad.PaddingRight = UDim.new(0, px)
	pad.Parent = parent
	return pad
end

-- ícone de pet: círculo colorido com emoji grande
function Theme.petIcon(parent, pet, props)
	props = props or {}
	local size = props.size or 72

	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromOffset(size, size)
	holder.BackgroundColor3 = pet.color or Theme.white
	holder.BorderSizePixel = 0
	holder.ZIndex = props.zIndex or 3
	holder.Parent = parent
	corner(holder, math.floor(size / 2))
	stroke(holder, Theme.outline, props.strokeThickness or 3)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = pet.emoji or "🐾"
	label.ZIndex = holder.ZIndex + 1
	label.Parent = holder

	return holder, label
end

-- arrastar painel pelo cabeçalho
function Theme.makeDraggable(frame, handle)
	local UserInputService = game:GetService("UserInputService")
	local dragging, dragStart, startPos = false, nil, nil

	(handle or frame).InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
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
