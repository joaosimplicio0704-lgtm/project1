-- Hud
-- Canto inferior esquerdo: renascimentos, moedas (+renda/s), gemas.
-- Topo: barra "PRÓXIMO!" com o objetivo atual. Botões Loja / Troca na esquerda.
-- Exatamente o layout dos prints.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local GameConfig = require(Shared.GameConfig)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)

local Hud = {}

local refs = {}

---------------------------------------------------------------------------
-- LINHA DE STAT (ícone + número + label)
---------------------------------------------------------------------------

local function statRow(parent, config)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(230, 52)
	row.Parent = parent

	local shadow = Instance.new("TextLabel")
	shadow.BackgroundTransparency = 1
	shadow.Size = UDim2.fromOffset(52, 52)
	shadow.Font = Enum.Font.FredokaOne
	shadow.TextScaled = true
	shadow.Text = config.icon
	shadow.TextColor3 = Color3.fromRGB(40, 30, 20)
	shadow.TextTransparency = 0.65
	shadow.Position = UDim2.fromOffset(3, 3)
	shadow.ZIndex = 2
	shadow.Parent = row

	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(52, 52)
	icon.Font = Enum.Font.FredokaOne
	icon.TextScaled = true
	icon.Text = config.icon
	icon.ZIndex = 3
	icon.Parent = row

	local value = Theme.label(row, {
		text = "0",
		size = UDim2.fromOffset(140, 34),
		position = UDim2.fromOffset(58, 0),
		xAlign = Enum.TextXAlignment.Left,
		textSize = 30,
		strokeTransparency = 0.15,
		strokeColor = Theme.outline,
		zIndex = 3,
	})
	value.Name = config.name .. "_Value"

	local label = Theme.label(row, {
		text = config.label,
		size = UDim2.fromOffset(140, 20),
		position = UDim2.fromOffset(62, 26),
		xAlign = Enum.TextXAlignment.Left,
		textSize = 15,
		color = Color3.fromRGB(255, 255, 255),
		strokeTransparency = 0.2,
		zIndex = 3,
	})

	refs[config.name] = value
	refs[config.name .. "_Label"] = label
	return { row = row, value = value, label = label, icon = icon, shadow = shadow }
end

---------------------------------------------------------------------------
-- BARRA DE MISSÃO (topo)
---------------------------------------------------------------------------

local function questBar(parent)
	local bar = Theme.panel(parent, {
		name = "QuestBar",
		size = UDim2.fromOffset(560, 96),
		position = UDim2.new(0.5, 0, 0, 16),
		anchor = Vector2.new(0.5, 0),
		color = Theme.white,
		radius = 22,
		zIndex = 5,
	})
	Theme.stroke(bar, Color3.fromRGB(150, 195, 235), 4)

	local title = Theme.label(bar, {
		text = "PRÓXIMO!",
		size = UDim2.fromOffset(200, 26),
		position = UDim2.fromOffset(28, 8),
		xAlign = Enum.TextXAlignment.Left,
		textSize = 22,
		color = Color3.fromRGB(240, 170, 40),
		strokeTransparency = 0.3,
		strokeColor = Color3.fromRGB(120, 70, 20),
		zIndex = 6,
	})

	local icon = Theme.label(bar, {
		text = "🥚",
		size = UDim2.fromOffset(66, 66),
		position = UDim2.fromOffset(24, 26),
		textSize = 52,
		strokeTransparency = 1,
		zIndex = 6,
	})

	local text = Theme.label(bar, {
		text = "Abra seu primeiro ovo!",
		size = UDim2.new(1, -140, 0, 40),
		position = UDim2.fromOffset(100, 26),
		xAlign = Enum.TextXAlignment.Left,
		textSize = 28,
		color = Color3.fromRGB(60, 110, 180),
		strokeTransparency = 1,
		zIndex = 6,
	})

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -64, 0, 12)
	track.Position = UDim2.fromOffset(32, 72)
	track.BackgroundColor3 = Color3.fromRGB(225, 235, 245)
	track.BorderSizePixel = 0
	track.ZIndex = 6
	track.Parent = bar
	Theme.corner(track, 6)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(120, 205, 110)
	fill.BorderSizePixel = 0
	fill.ZIndex = 7
	fill.Parent = track
	Theme.corner(fill, 6)

	refs.questText = text
	refs.questFill = fill
	refs.questIcon = icon
	refs.questTitle = title
	return bar
end

---------------------------------------------------------------------------
-- BOTÕES LATERAIS
---------------------------------------------------------------------------

local function sideButton(parent, text, icon, color, order, onClick)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(120, 120)
	holder.Position = UDim2.fromOffset(20, 0)
	holder.LayoutOrder = order
	holder.Parent = parent

	local shadow = Instance.new("Frame")
	shadow.Size = UDim2.fromOffset(112, 112)
	shadow.Position = UDim2.fromOffset(4, 8)
	shadow.BackgroundColor3 = Theme.shadow
	shadow.BackgroundTransparency = 0.6
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 3
	shadow.Parent = holder
	Theme.corner(shadow, 24)

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(112, 112)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.ZIndex = 4
	button.Parent = holder
	Theme.corner(button, 24)
	Theme.stroke(button, Theme.outline, 4)
	Theme.gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215))

	local iconLabel = Theme.label(button, {
		text = icon,
		size = UDim2.fromScale(1, 0.66),
		position = UDim2.fromScale(0, 0.02),
		textSize = 52,
		strokeTransparency = 1,
		zIndex = 5,
	})

	Theme.label(button, {
		text = text,
		size = UDim2.fromScale(1, 0.3),
		position = UDim2.fromScale(0, 0.66),
		textSize = 22,
		strokeTransparency = 0.1,
		zIndex = 5,
	})

	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseButton1Down:Connect(function()
		scale.Scale = 0.92
	end)
	button.MouseButton1Up:Connect(function()
		scale.Scale = 1
	end)
	button.MouseLeave:Connect(function()
		scale.Scale = 1
	end)

	button.MouseButton1Click:Connect(onClick)
	return button, iconLabel
end

---------------------------------------------------------------------------
-- BUILD
---------------------------------------------------------------------------

function Hud.build(gui, callbacks)
	-- STATS (inferior esquerdo)
	local statsHolder = Instance.new("Frame")
	statsHolder.BackgroundTransparency = 1
	statsHolder.Size = UDim2.fromOffset(250, 190)
	statsHolder.Position = UDim2.new(0, 18, 1, -18)
	statsHolder.AnchorPoint = Vector2.new(0, 1)
	statsHolder.Parent = gui
	Theme.list(statsHolder, { padding = 2, hAlign = Enum.HorizontalAlignment.Left })

	statRow(statsHolder, { name = "Rebirths", icon = "♻️", label = "Rensamentos" })
	statRow(statsHolder, { name = "Coins", icon = "🪙", label = "+0/s" })
	statRow(statsHolder, { name = "Gems", icon = "💎", label = "Gemas" })

	-- VIDA E XP (superior esquerdo, abaixo dos botões de atalho)
	-- Duas barras, nessa ordem: vida em cima (vermelho, urgente) e XP embaixo
	-- (dourado, progresso). A criança entende barra que enche sem ler nada.
	local vitals = Instance.new("Frame")
	vitals.BackgroundTransparency = 1
	vitals.Size = UDim2.fromOffset(260, 74)
	vitals.Position = UDim2.fromOffset(18, 88)
	vitals.Parent = gui

	-- vida
	local healthTrack = Instance.new("Frame")
	healthTrack.Size = UDim2.new(1, 0, 0, 26)
	healthTrack.BackgroundColor3 = Color3.fromRGB(70, 40, 40)
	healthTrack.BorderSizePixel = 0
	healthTrack.Parent = vitals
	Theme.corner(healthTrack, 13)
	Theme.stroke(healthTrack, Color3.fromRGB(40, 24, 24), 3)

	local healthFill = Instance.new("Frame")
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.BackgroundColor3 = Color3.fromRGB(235, 88, 88)
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthTrack
	Theme.corner(healthFill, 13)

	local healthText = Theme.label(vitals, {
		text = "❤️ 100 / 100",
		size = UDim2.fromOffset(260, 26),
		textSize = 17,
		color = Color3.fromRGB(255, 255, 255),
		strokeTransparency = 0.2,
		zIndex = (healthTrack.ZIndex or 1) + 2,
	})
	refs.healthFill = healthFill
	refs.healthText = healthText

	-- XP
	local xpTrack = Instance.new("Frame")
	xpTrack.Size = UDim2.new(1, 0, 0, 18)
	xpTrack.Position = UDim2.fromOffset(0, 30)
	xpTrack.BackgroundColor3 = Color3.fromRGB(56, 48, 34)
	xpTrack.BorderSizePixel = 0
	xpTrack.Parent = vitals
	Theme.corner(xpTrack, 9)
	Theme.stroke(xpTrack, Color3.fromRGB(40, 32, 20), 3)

	local xpFill = Instance.new("Frame")
	xpFill.Size = UDim2.new(0, 0, 1, 0)
	xpFill.BackgroundColor3 = Color3.fromRGB(255, 206, 61)
	xpFill.BorderSizePixel = 0
	xpFill.Parent = xpTrack
	Theme.corner(xpFill, 9)

	local xpText = Theme.label(vitals, {
		text = "Nv 1 · 0 / 100",
		size = UDim2.fromOffset(260, 18),
		position = UDim2.fromOffset(0, 30),
		textSize = 14,
		color = Color3.fromRGB(255, 255, 255),
		strokeTransparency = 0.25,
		zIndex = (xpTrack.ZIndex or 1) + 2,
	})
	refs.xpFill = xpFill
	refs.xpText = xpText

	-- BOTÕES LATERAIS (esquerda, meio)
	local sideHolder = Instance.new("Frame")
	sideHolder.BackgroundTransparency = 1
	sideHolder.Size = UDim2.fromOffset(130, 260)
	sideHolder.Position = UDim2.new(0, 16, 0.5, -130)
	sideHolder.Parent = gui
	Theme.list(sideHolder, { padding = 12, hAlign = Enum.HorizontalAlignment.Left })

	refs.shopButton = sideButton(sideHolder, "Loja", "🧺", Theme.red, 1, function()
		if callbacks and callbacks.shop then
			callbacks.shop()
		end
	end)
	refs.tradeButton = sideButton(sideHolder, "Troca", "🔀", Color3.fromRGB(255, 150, 60), 2, function()
		if callbacks and callbacks.trade then
			callbacks.trade()
		end
	end)

	-- MISSÃO (topo)
	questBar(gui)

	-- DEBUG/INFO do canto superior direito (config e som)
	local topRight = Instance.new("Frame")
	topRight.BackgroundTransparency = 1
	topRight.Size = UDim2.fromOffset(180, 52)
	topRight.Position = UDim2.new(1, -18, 0, 16)
	topRight.AnchorPoint = Vector2.new(1, 0)
	topRight.Parent = gui
	local layout = Theme.list(topRight, {
		direction = Enum.FillDirection.Horizontal,
		padding = 10,
		hAlign = Enum.HorizontalAlignment.Right,
	})
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	local function circleButton(icon, order, onClick)
		local btn = Theme.button(topRight, {
			text = icon,
			size = UDim2.fromOffset(52, 52),
			color = Color3.fromRGB(120, 200, 255),
			textSize = 26,
			layoutOrder = order,
			radius = 26,
			shadow = false,
		})
		btn.MouseButton1Click:Connect(onClick)
		return btn
	end

	circleButton("⚙️", 1, function()
		if callbacks and callbacks.settings then
			callbacks.settings()
		end
	end)
	circleButton("🏆", 2, function()
		if callbacks and callbacks.ranks then
			callbacks.ranks()
		end
	end)

	-- assinatura de update
	local last = {}

	State.subscribe(function(snapshot)
		local Format_number = Format.number

		if last.coins ~= math.floor(snapshot.coins) then
			refs.Coins.Text = Format_number(snapshot.coins)
			last.coins = math.floor(snapshot.coins)
		end
		if last.income ~= math.floor(snapshot.income * 10) then
			refs.Coins_Label.Text = "+" .. Format_number(snapshot.income) .. "/s"
			last.income = math.floor(snapshot.income * 10)
		end
		if last.gems ~= snapshot.gems then
			refs.Gems.Text = Format_number(snapshot.gems)
			last.gems = snapshot.gems
		end
		if last.rebirths ~= snapshot.rebirths then
			refs.Rebirths.Text = tostring(snapshot.rebirths)
			last.rebirths = snapshot.rebirths
		end

		-- VIDA: muda de cor conforme o perigo. Barra vermelha em 100% e
		-- barra vermelha em 10% não comunicam nada; a cor é o aviso.
		local maxHealth = snapshot.maxHealth or 100
		local health = math.clamp(snapshot.health or maxHealth, 0, maxHealth)
		local fraction = maxHealth > 0 and health / maxHealth or 0
		if refs.healthFill then
			refs.healthFill.Size = UDim2.fromScale(fraction, 1)
			refs.healthFill.BackgroundColor3 = fraction > 0.5 and Color3.fromRGB(235, 88, 88)
				or (fraction > 0.25 and Color3.fromRGB(245, 160, 60) or Color3.fromRGB(200, 50, 50))
			refs.healthText.Text = string.format("❤️ %d / %d", math.floor(health), math.floor(maxHealth))
		end

		-- XP
		local progress = snapshot.progress
		if progress and refs.xpFill then
			local need = math.max(1, progress.xpToNext or 1)
			local have = math.clamp(progress.xp or 0, 0, need)
			refs.xpFill.Size = UDim2.fromScale(have / need, 1)
			refs.xpText.Text = string.format("Nv %d · %d / %d", progress.level or 1, have, need)
		end

		local quest = GameConfig.Quests[snapshot.questIndex]
		if quest then
			local progress = GameConfig.questProgress(snapshot, quest)
			refs.questText.Text = quest.text
			refs.questFill.Size = UDim2.fromScale(math.clamp(progress / quest.target, 0, 1), 1)
			refs.questTitle.Text = "PRÓXIMO!"
			refs.questTitle.TextColor3 = Color3.fromRGB(240, 170, 40)
		else
			refs.questText.Text = "Você completou tudo! 🏆"
			refs.questFill.Size = UDim2.fromScale(1, 1)
			refs.questTitle.Text = "COMPLETO!"
			refs.questTitle.TextColor3 = Color3.fromRGB(120, 200, 110)
		end
	end)

	return refs
end

return Hud
