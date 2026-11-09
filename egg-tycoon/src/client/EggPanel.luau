-- EggPanel
-- Painel de ovos: lista de ovos, botão ABRIR, e a animação de chocar
-- (ovo balançando -> estilhaços -> pet aparecendo), igual aos prints.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local NetClient = require(script.Parent.NetClient)

local EggPanel = {}

local refs = {}
local gui
local selected = "starter"
local hatching = false

---------------------------------------------------------------------------
-- CARD DE OVO
---------------------------------------------------------------------------

local function eggCard(parent, egg, order)
	local card = Instance.new("TextButton")
	card.Name = "EggCard_" .. egg.id
	card.Size = UDim2.fromOffset(268, 96)
	card.BackgroundColor3 = Theme.white
	card.BorderSizePixel = 0
	card.AutoButtonColor = false
	card.Text = ""
	card.LayoutOrder = order
	card.Parent = parent
	Theme.corner(card, 20)
	local stroke = Theme.stroke(card, Color3.fromRGB(225, 210, 190), 3)

	local iconFrame = Instance.new("Frame")
	iconFrame.Size = UDim2.fromOffset(64, 64)
	iconFrame.Position = UDim2.fromOffset(12, 16)
	iconFrame.BackgroundColor3 = egg.color
	iconFrame.BorderSizePixel = 0
	iconFrame.ZIndex = 2
	iconFrame.Parent = card
	Theme.corner(iconFrame, 32)
	Theme.stroke(iconFrame, Theme.outline, 3)

	Theme.label(iconFrame, {
		text = egg.emoji,
		size = UDim2.fromScale(1, 1),
		textSize = 34,
		strokeTransparency = 1,
		zIndex = 3,
	})

	Theme.label(card, {
		text = egg.name,
		size = UDim2.new(1, -96, 0, 26),
		position = UDim2.fromOffset(86, 12),
		xAlign = Enum.TextXAlignment.Left,
		textSize = 20,
		color = Theme.textDark,
		strokeTransparency = 1,
		zIndex = 3,
	})

	local cost = Theme.label(card, {
		text = "🪙 " .. Format.number(egg.cost),
		size = UDim2.new(1, -96, 0, 22),
		position = UDim2.fromOffset(86, 36),
		xAlign = Enum.TextXAlignment.Left,
		textSize = 18,
		color = Color3.fromRGB(230, 160, 30),
		strokeTransparency = 1,
		zIndex = 3,
	})

	local statusLabel = Theme.label(card, {
		text = "",
		size = UDim2.new(1, -96, 0, 18),
		position = UDim2.fromOffset(86, 60),
		xAlign = Enum.TextXAlignment.Left,
		textSize = 14,
		color = Color3.fromRGB(150, 150, 160),
		strokeTransparency = 1,
		zIndex = 3,
	})

	card.MouseButton1Click:Connect(function()
		EggPanel.select(egg.id)
	end)

	return {
		card = card,
		stroke = stroke,
		cost = cost,
		status = statusLabel,
		egg = egg,
	}
end

---------------------------------------------------------------------------
-- ANIMAÇÃO DE CHOCAR
---------------------------------------------------------------------------

local function playHatchAnimation(petId, rarityId)
	local overlay = Instance.new("Frame")
	overlay.Name = "HatchOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.55
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 40
	overlay.Parent = gui

	local rarity = GameConfig.rarity(rarityId)
	local pet = GameConfig.pet(petId)

	local eggFrame = Instance.new("Frame")
	eggFrame.Size = UDim2.fromOffset(180, 220)
	eggFrame.Position = UDim2.fromScale(0.5, 0.5)
	eggFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	eggFrame.BackgroundColor3 = Color3.fromRGB(255, 245, 220)
	eggFrame.BorderSizePixel = 0
	eggFrame.ZIndex = 41
	eggFrame.Parent = overlay
	Theme.corner(eggFrame, 90)
	Theme.stroke(eggFrame, Theme.outline, 5)

	local eggEmoji = Theme.label(eggFrame, {
		text = "🥚",
		size = UDim2.fromScale(1, 1),
		textSize = 110,
		strokeTransparency = 1,
		zIndex = 42,
	})

	local scale = Instance.new("UIScale")
	scale.Parent = eggFrame

	-- balançar
	local wobble = 0
	local wobbleConnection
	wobbleConnection = game:GetService("RunService").RenderStepped:Connect(function(dt)
		wobble += dt * 18
		eggFrame.Rotation = math.sin(wobble) * 12
	end)

	task.delay(1.1, function()
		if wobbleConnection then
			wobbleConnection:Disconnect()
		end
		eggFrame.Rotation = 0
		eggEmoji.Text = "💥"

		TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 1.6 }):Play()
		task.wait(0.12)
		eggEmoji.Text = pet.emoji
		eggFrame.BackgroundColor3 = rarity.color
		TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()

		-- flash dourado se lendário+
		if GameConfig.rarity(rarityId).order >= 5 then
			local flash = Instance.new("Frame")
			flash.Size = UDim2.fromScale(1, 1)
			flash.BackgroundColor3 = rarity.color
			flash.BackgroundTransparency = 0.5
			flash.BorderSizePixel = 0
			flash.ZIndex = 43
			flash.Parent = overlay
			TweenService:Create(flash, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
			task.delay(0.8, function()
				flash:Destroy()
			end)
		end
	end)

	task.delay(1.7, function()
		local name = Theme.label(overlay, {
			text = pet.name,
			size = UDim2.fromOffset(600, 70),
			position = UDim2.fromScale(0.5, 0.28),
			anchor = Vector2.new(0.5, 0.5),
			textSize = 52,
			color = rarity.color,
			strokeTransparency = 0,
			strokeColor = Theme.outline,
			zIndex = 44,
		})
		local rarityLabel = Theme.label(overlay, {
			text = rarity.name:upper() .. "!",
			size = UDim2.fromOffset(600, 40),
			position = UDim2.fromScale(0.5, 0.34),
			anchor = Vector2.new(0.5, 0.5),
			textSize = 26,
			color = Color3.fromRGB(255, 255, 255),
			strokeTransparency = 0.2,
			zIndex = 44,
		})
		TweenService:Create(name, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.24),
		}):Play()
		rarityLabel.TextTransparency = 0

		task.delay(1.6, function()
			TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(name, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			TweenService:Create(rarityLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			TweenService:Create(eggFrame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(eggEmoji, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			task.wait(0.35)
			overlay:Destroy()
			EggPanel.setHatching(false)
		end)
	end)
end

---------------------------------------------------------------------------
-- PAINEL
---------------------------------------------------------------------------

function EggPanel.build(parentGui)
	gui = parentGui

	local root = Theme.panel(gui, {
		name = "EggPanel",
		size = UDim2.fromOffset(600, 560),
		position = UDim2.new(0.5, 0, 0.5, 0),
		color = Theme.white,
		radius = 30,
		zIndex = 25,
	})
	root.Visible = false
	refs.root = root

	-- cabeçalho com título estilo "Ovos"

	local title = Theme.titleTag(root, "OVOS", { width = 190, offset = -26, zIndex = 25, textSize = 26 })

	local close = Theme.button(root, {
		text = "✕",
		size = UDim2.fromOffset(52, 52),
		position = UDim2.new(1, -18, 0, 14),
		anchor = Vector2.new(1, 0),
		color = Theme.red,
		textSize = 26,
		radius = 26,
		shadow = false,
		zIndex = 30,
	})
	close.MouseButton1Click:Connect(function()
		EggPanel.hide()
	end)

	-- lista com scroll
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -40, 1, -216)
	scroll.Position = UDim2.fromOffset(20, 88)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = Color3.fromRGB(220, 180, 130)
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ZIndex = 26
	scroll.Parent = root
	Theme.list(scroll, { padding = 8 })

	refs.cards = {}
	for index, egg in ipairs(GameConfig.Eggs) do
		refs.cards[egg.id] = eggCard(scroll, egg, index)
	end

	-- rodapé: botão gigante ABRIR
	local footer = Instance.new("Frame")
	footer.Size = UDim2.new(1, -40, 0, 104)
	footer.Position = UDim2.new(0, 20, 1, -114)
	footer.BackgroundTransparency = 1
	footer.ZIndex = 26
	footer.Parent = root

	local openButton = Theme.button(footer, {
		text = "ABRIR OVO",
		size = UDim2.new(1, 0, 0, 82),
		position = UDim2.new(0, 0, 0, 10),
		color = Theme.green,
		textSize = 34,
		radius = 41,
		zIndex = 27,
	})
	Theme.gradient(openButton, Color3.fromRGB(190, 245, 140), Color3.fromRGB(90, 190, 80))
	refs.openButton = openButton

	openButton.MouseButton1Click:Connect(function()
		if hatching then
			return
		end
		local egg = GameConfig.egg(selected)
		local snapshot = State.snapshot
		if not egg or not snapshot then
			return
		end
		local bought = snapshot.eggBought and snapshot.eggBought[egg.id] or 0
		if snapshot.coins < GameConfig.eggPrice(egg.id, bought) then
			EggPanel.flashError()
			return
		end
		EggPanel.setHatching(true)
		NetClient.action(Net.ActionKind.Hatch)
		-- se o servidor não responder (sem moedas etc.), destrava em 2s
		task.delay(2, function()
			if hatching then
				EggPanel.setHatching(false)
			end
		end)
	end)

	Theme.makeDraggable(root, header)

	return root
end

function EggPanel.select(eggId)
	selected = eggId
	EggPanel.refresh()
end

function EggPanel.refresh()
	if not State.snapshot then
		return
	end
	local snapshot = State.snapshot
	for eggId, cardRef in pairs(refs.cards) do
		local egg = cardRef.egg
		local isSelected = eggId == selected
		cardRef.stroke.Color = isSelected and Color3.fromRGB(120, 205, 110) or Color3.fromRGB(225, 210, 190)
		cardRef.stroke.Thickness = isSelected and 5 or 3

		local bought = snapshot.eggBought and snapshot.eggBought[eggId] or 0
		local price = GameConfig.eggPrice(eggId, bought)
		cardRef.cost.Text = "🪙 " .. Format.number(price)
		if snapshot.coins >= price then
			cardRef.status.Text = "disponível"
			cardRef.status.TextColor3 = Color3.fromRGB(110, 180, 90)
		else
			cardRef.status.Text = "faltam " .. Format.number(price - snapshot.coins)
			cardRef.status.TextColor3 = Color3.fromRGB(200, 130, 130)
		end
	end

	local egg = GameConfig.egg(selected)
	if refs.openButton and egg then
		local bought = snapshot.eggBought and snapshot.eggBought[egg.id] or 0
		refs.openButton.Text = "ABRIR "
			.. egg.name:upper()
			.. "  ·  🪙 "
			.. Format.number(GameConfig.eggPrice(egg.id, bought))
	end
end

function EggPanel.flashError()
	if not refs.root then
		return
	end
	local original = refs.root.BackgroundColor3
	refs.root.BackgroundColor3 = Color3.fromRGB(255, 190, 190)
	task.delay(0.15, function()
		if refs.root then
			refs.root.BackgroundColor3 = original
		end
	end)
end

function EggPanel.setHatching(value)
	hatching = value
	if refs.openButton then
		refs.openButton.Text = value and "CHOCANDO..." or refs.openButton.Text
	end
end

function EggPanel.show()
	refs.root.Visible = true
	EggPanel.refresh()
end

function EggPanel.hide()
	refs.root.Visible = false
end

function EggPanel.toggle()
	if refs.root.Visible then
		EggPanel.hide()
	else
		EggPanel.show()
	end
end

function EggPanel.onHatch(payload)
	EggPanel.setHatching(true)
	local overlay = gui:FindFirstChild("HatchOverlay")
	if overlay then
		overlay:Destroy()
	end
	playHatchAnimation(payload.petId, payload.rarity)
end

return EggPanel
