-- ShopPanel
-- Loja de moedas (toque, slots, multiplicador) e loja de gemas
-- (renda, sorte, toque, slots) — duas abas no mesmo painel, como nos prints.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local NetClient = require(script.Parent.NetClient)

local ShopPanel = {}

local refs = { rows = {} }
local gui
local currentTab = "coins"

local COIN_META = {
	tap = { icon = "👆", desc = "Mais moedas por toque" },
	slots = { icon = "🎒", desc = "Equipe mais pets" },
	mult = { icon = "✨", desc = "Multiplica toda a renda" },
}

local GEM_META = {
	gemsIncome = { icon = "💎", desc = "Renda de pets permanente" },
	gemsLuck = { icon = "🍀", desc = "Mais chance de pets raros" },
	gemsTap = { icon = "👊", desc = "Toque mais forte, pra sempre" },
	gemsSlots = { icon = "🎒", desc = "Slot extra permanente" },
}

local function clearRows()
	for _, row in pairs(refs.rows) do
		row:Destroy()
	end
	refs.rows = {}
end

local function buildRow(parent, order, icon, title, subtitle, buttonText, affordable, onClick)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 76)
	row.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Parent = parent
	Theme.corner(row, 18)
	Theme.stroke(row, Color3.fromRGB(230, 215, 195), 3)

	local iconFrame = Instance.new("Frame")
	iconFrame.Size = UDim2.fromOffset(52, 52)
	iconFrame.Position = UDim2.fromOffset(12, 12)
	iconFrame.BackgroundColor3 = Color3.fromRGB(255, 235, 200)
	iconFrame.BorderSizePixel = 0
	iconFrame.ZIndex = 2
	iconFrame.Parent = row
	Theme.corner(iconFrame, 16)

	Theme.label(iconFrame, {
		text = icon,
		size = UDim2.fromScale(1, 1),
		textSize = 28,
		strokeTransparency = 1,
		zIndex = 3,
	})

	Theme.label(row, {
		text = title,
		size = UDim2.new(1, -230, 0, 22),
		position = UDim2.fromOffset(76, 12),
		xAlign = Enum.TextXAlignment.Left,
		textSize = 18,
		color = Theme.textDark,
		strokeTransparency = 1,
		zIndex = 3,
	})

	Theme.label(row, {
		text = subtitle,
		size = UDim2.new(1, -230, 0, 18),
		position = UDim2.fromOffset(76, 36),
		xAlign = Enum.TextXAlignment.Left,
		textSize = 14,
		color = Color3.fromRGB(160, 150, 140),
		strokeTransparency = 1,
		zIndex = 3,
	})

	local buy = Theme.button(row, {
		text = buttonText,
		size = UDim2.fromOffset(150, 46),
		position = UDim2.new(1, -12, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = affordable and Theme.green or Color3.fromRGB(200, 200, 205),
		textSize = 16,
		radius = 23,
		shadow = false,
		zIndex = 4,
	})
	buy.MouseButton1Click:Connect(function()
		if affordable then
			onClick()
		end
	end)

	refs.rows[#refs.rows + 1] = row
	return row
end

function ShopPanel.build(parentGui)
	gui = parentGui

	local root = Theme.panel(gui, {
		name = "ShopPanel",
		size = UDim2.fromOffset(560, 580),
		position = UDim2.new(0.5, 0, 0.5, 0),
		color = Theme.white,
		radius = 30,
		zIndex = 25,
	})
	root.Visible = false
	refs.root = root

	-- titleTag devolve o TextLabel interno, então refs.title.Text continua
	-- funcionando quando alterna entre LOJA e GEMAS.
	refs.title = Theme.titleTag(root, "LOJA", { width = 190, offset = -26, zIndex = 25, textSize = 26 })

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
		ShopPanel.hide()
	end)

	-- barra de abas
	local tabs = Instance.new("Frame")
	tabs.Size = UDim2.new(1, -40, 0, 52)
	tabs.Position = UDim2.fromOffset(20, 88)
	tabs.BackgroundTransparency = 1
	tabs.ZIndex = 27
	tabs.Parent = root
	Theme.list(tabs, {
		direction = Enum.FillDirection.Horizontal,
		padding = 8,
		hAlign = Enum.HorizontalAlignment.Left,
	})

	local function tabButton(text, id, order, color)
		local btn = Theme.button(tabs, {
			text = text,
			size = UDim2.fromOffset(240, 50),
			color = color,
			textSize = 19,
			layoutOrder = order,
			radius = 25,
			shadow = false,
			zIndex = 28,
		})
		btn.MouseButton1Click:Connect(function()
			currentTab = id
			ShopPanel.refresh()
		end)
		return btn
	end

	refs.coinTab = tabButton("🪙 MOEDAS", "coins", 1, Theme.yellow)
	refs.gemTab = tabButton("💎 GEMAS", "gems", 2, Theme.purple)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -32, 1, -176)
	scroll.Position = UDim2.fromOffset(16, 152)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = Color3.fromRGB(210, 200, 190)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.ZIndex = 26
	scroll.Parent = root
	Theme.list(scroll, { padding = 8 })
	refs.scroll = scroll

	Theme.makeDraggable(root, header)

	State.subscribe(function()
		if root.Visible then
			ShopPanel.refresh()
		end
	end)

	return root
end

function ShopPanel.refresh()
	local snapshot = State.snapshot
	if not snapshot or not refs.root then
		return
	end

	clearRows()
	refs.coinTab.BackgroundColor3 = currentTab == "coins" and Theme.yellow or Color3.fromRGB(220, 220, 220)
	refs.gemTab.BackgroundColor3 = currentTab == "gems" and Theme.purple or Color3.fromRGB(220, 220, 220)

	if currentTab == "coins" then
		refs.title.Text = "LOJA"
		local order = 0
		for _, kind in ipairs({ "tap", "slots", "mult" }) do
			order += 1
			local meta = COIN_META[kind]
			local upgrade = GameConfig.Upgrades[kind]
			local tier = snapshot.upgrades[kind]
			local cost = GameConfig.upgradeCost(kind, tier)
			local prefix = "Nível " .. tier .. "/" .. upgrade.maxTier .. " · " .. meta.desc

			local text
			if cost then
				text = "🪙 " .. Format.number(cost)
			else
				text = "MÁXIMO"
			end

			buildRow(
				refs.scroll,
				order,
				meta.icon,
				upgrade.name,
				prefix,
				text,
				cost ~= nil and snapshot.coins >= cost,
				function()
					NetClient.action(Net.ActionKind.BuyUpgrade, kind)
				end
			)
		end
	else
		refs.title.Text = "GEMAS"
		local order = 0
		for _, kind in ipairs({ "gemsIncome", "gemsLuck", "gemsTap", "gemsSlots" }) do
			order += 1
			local meta = GEM_META[kind]
			local upgrade = GameConfig.GemUpgrades[kind]
			local rank = snapshot.gemUpgrades[kind]
			local cost = GameConfig.gemCost(kind, rank)
			local prefix = "Rank " .. rank .. "/" .. upgrade.maxRank .. " · " .. meta.desc

			local text
			if cost then
				text = "💎 " .. cost
			else
				text = "MÁXIMO"
			end

			buildRow(
				refs.scroll,
				order,
				meta.icon,
				upgrade.name,
				prefix,
				text,
				cost ~= nil and snapshot.gems >= cost,
				function()
					NetClient.action(Net.ActionKind.BuyGemUpgrade, kind)
				end
			)
		end

		-- troca de gemas (informativo)
		order += 1
		buildRow(
			refs.scroll,
			order,
			"💠",
			"Ganhe gemas",
			"Rebirth dá gemas · ranking semanal",
			"—",
			false,
			function() end
		)
	end
end

function ShopPanel.show(tab)
	if tab then
		currentTab = tab
	end
	refs.root.Visible = true
	ShopPanel.refresh()
end

function ShopPanel.hide()
	refs.root.Visible = false
end

function ShopPanel.toggle()
	if refs.root.Visible then
		ShopPanel.hide()
	else
		ShopPanel.show()
	end
end

return ShopPanel
