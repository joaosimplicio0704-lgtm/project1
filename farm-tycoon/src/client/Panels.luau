-- Panels
-- Menu tabulado a direita: Sementes, Melhorias, Rebirth, Codigos.
-- Toda linha e um botao que dispara uma Action; nenhum estado de jogo aqui.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local NetClient = require(script.Parent.NetClient)

local Panels = {}

local TABS = {
	{ id = "seeds", label = "🌱 Sementes" },
	{ id = "upgrades", label = "⚡ Melhorias" },
	{ id = "rebirth", label = "♻️ Rebirth" },
	{ id = "codes", label = "🎁 Códigos" },
}

local refs = {}
local currentTab = "seeds"
local rowBuilders = {}
local open = true

local function clear(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "Layout" then
			child:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- LINHAS
---------------------------------------------------------------------------

local function row(parent, order, height)
	local r = Theme.frame(parent, {
		size = UDim2.new(1, 0, 0, height or 56),
		color = Theme.panelAlt,
		transparency = 0.15,
		radius = 10,
		stroke = false,
	})
	r.LayoutOrder = order
	r.Name = "Row" .. order
	return r
end

---------------------------------------------------------------------------
-- TAB: SEMENTES
---------------------------------------------------------------------------

rowBuilders.seeds = function(parent, snapshot)
	local order = 0
	for _, crop in ipairs(GameConfig.Crops) do
		order += 1
		local unlocked = snapshot.level >= crop.level
		local selected = snapshot.selectedCrop == crop.id

		local r = row(parent, order, 54)
		r.BackgroundColor3 = selected and Color3.fromRGB(38, 66, 52) or Theme.panelAlt
		if not unlocked then
			r.BackgroundTransparency = 0.45
		end

		local button = Instance.new("TextButton")
		button.Size = UDim2.fromScale(1, 1)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.Parent = r

		Theme.label(r, {
			text = crop.emoji .. "  " .. crop.name,
			size = UDim2.new(1, -120, 0, 20),
			position = UDim2.fromOffset(12, 8),
			font = Theme.fontBlack,
			textSize = 14,
			color = unlocked and Theme.text or Theme.dim,
		})

		Theme.label(r, {
			text = string.format("%s  →  %s", Format.money(crop.seed), Format.money(crop.sell * crop.amount)),
			size = UDim2.new(1, -120, 0, 16),
			position = UDim2.fromOffset(12, 28),
			font = Theme.fontBody,
			textSize = 11,
			color = Theme.dim,
		})

		Theme.label(r, {
			text = Format.time(crop.grow),
			size = UDim2.fromOffset(48, 16),
			position = UDim2.new(1, -60, 0, 8),
			font = Theme.fontBody,
			textSize = 11,
			color = Theme.cyan,
			xAlign = Enum.TextXAlignment.Right,
		})

		local statusText
		if not unlocked then
			statusText = "Nv " .. crop.level
		elseif selected then
			statusText = "ATIVO"
		else
			statusText = "usar"
		end

		Theme.label(r, {
			text = statusText,
			size = UDim2.fromOffset(60, 16),
			position = UDim2.new(1, -60, 0, 26),
			font = Theme.fontBlack,
			textSize = 11,
			color = selected and Theme.green or Theme.dim,
			xAlign = Enum.TextXAlignment.Right,
		})

		if unlocked then
			button.MouseButton1Click:Connect(function()
				NetClient.action(Net.ActionKind.SelectCrop, crop.id)
			end)
		end
	end
end

---------------------------------------------------------------------------
-- TAB: MELHORIAS
---------------------------------------------------------------------------

local UPGRADE_META = {
	conveyor = { icon = "🛤️", desc = "Itens chegam mais rápido na esteira" },
	sell = { icon = "💰", desc = "Multiplica o valor vendido" },
	luck = { icon = "🍀", desc = "Mais chance de mutações raras" },
}

rowBuilders.upgrades = function(parent, snapshot)
	local order = 0

	-- plot
	order += 1
	do
		local cost, levelReq = GameConfig.plotCost(snapshot.plots)
		local r = row(parent, order, 58)
		Theme.label(r, {
			text = "🧱  Terreno extra  (" .. snapshot.plots .. "/" .. GameConfig.Plots.Max .. ")",
			size = UDim2.new(1, -140, 0, 20),
			position = UDim2.fromOffset(12, 8),
			font = Theme.fontBlack,
			textSize = 14,
		})
		Theme.label(r, {
			text = "Planta uma cultura a mais",
			size = UDim2.new(1, -140, 0, 16),
			position = UDim2.fromOffset(12, 30),
			font = Theme.fontBody,
			textSize = 11,
			color = Theme.dim,
		})
		if cost then
			local btn = Theme.button(r, {
				text = "COMPRAR\n" .. Format.money(cost),
				size = UDim2.fromOffset(118, 42),
				position = UDim2.new(1, -128, 0.5, 0),
				anchor = Vector2.new(0, 0.5),
				color = Theme.greenDark,
				textSize = 12,
			})
			btn.MouseButton1Click:Connect(function()
				NetClient.action(Net.ActionKind.BuyPlot)
			end)
		else
			Theme.label(r, {
				text = "MÁXIMO",
				size = UDim2.fromOffset(118, 42),
				position = UDim2.new(1, -128, 0.5, 0),
				anchor = Vector2.new(0, 0.5),
				color = Theme.dim,
				font = Theme.fontBlack,
				xAlign = Enum.TextXAlignment.Center,
			})
		end
	end

	for _, kind in ipairs({ "conveyor", "sell", "luck" }) do
		order += 1
		local meta = UPGRADE_META[kind]
		local tier = snapshot.upgrades[kind] or 0
		local cost = GameConfig.upgradeCost(kind, tier)
		local r = row(parent, order, 58)

		Theme.label(r, {
			text = meta.icon .. "  " .. GameConfig.Upgrades[kind].name,
			size = UDim2.new(1, -140, 0, 20),
			position = UDim2.fromOffset(12, 8),
			font = Theme.fontBlack,
			textSize = 14,
		})
		Theme.label(r, {
			text = meta.desc .. "  ·  Nv " .. tier .. "/" .. GameConfig.Upgrades[kind].maxTier,
			size = UDim2.new(1, -140, 0, 16),
			position = UDim2.fromOffset(12, 30),
			font = Theme.fontBody,
			textSize = 11,
			color = Theme.dim,
		})

		if cost then
			local btn = Theme.button(r, {
				text = "MELHORAR\n" .. Format.money(cost),
				size = UDim2.fromOffset(118, 42),
				position = UDim2.new(1, -128, 0.5, 0),
				anchor = Vector2.new(0, 0.5),
				color = Theme.panel,
				textColor = Theme.gold,
				textSize = 12,
			})
			btn.MouseButton1Click:Connect(function()
				NetClient.action(Net.ActionKind.BuyUpgrade, kind)
			end)
		else
			Theme.label(r, {
				text = "MÁXIMO",
				size = UDim2.fromOffset(118, 42),
				position = UDim2.new(1, -128, 0.5, 0),
				anchor = Vector2.new(0, 0.5),
				color = Theme.dim,
				font = Theme.fontBlack,
				xAlign = Enum.TextXAlignment.Center,
			})
		end
	end

	-- auto-colheita
	order += 1
	do
		local tier = snapshot.upgrades.auto or 0
		local cost = GameConfig.autoCost(tier)
		local r = row(parent, order, 58)
		Theme.label(r, {
			text = "✨  Colheita Dupla  ·  Nv " .. tier .. "/" .. #GameConfig.AutoTiers,
			size = UDim2.new(1, -140, 0, 20),
			position = UDim2.fromOffset(12, 8),
			font = Theme.fontBlack,
			textSize = 14,
		})
		Theme.label(r, {
			text = tier > 0 and string.format("Colhe sozinho a cada %.1fs", GameConfig.autoInterval(tier))
				or "Colhe tudo automaticamente",
			size = UDim2.new(1, -140, 0, 16),
			position = UDim2.fromOffset(12, 30),
			font = Theme.fontBody,
			textSize = 11,
			color = Theme.dim,
		})
		if cost then
			local btn = Theme.button(r, {
				text = "COMPRAR\n" .. Format.money(cost),
				size = UDim2.fromOffset(118, 42),
				position = UDim2.new(1, -128, 0.5, 0),
				anchor = Vector2.new(0, 0.5),
				color = Theme.panel,
				textColor = Theme.cyan,
				textSize = 12,
			})
			btn.MouseButton1Click:Connect(function()
				NetClient.action(Net.ActionKind.BuyAuto)
			end)
		else
			Theme.label(r, {
				text = "MÁXIMO",
				size = UDim2.fromOffset(118, 42),
				position = UDim2.new(1, -128, 0.5, 0),
				anchor = Vector2.new(0, 0.5),
				color = Theme.dim,
				font = Theme.fontBlack,
				xAlign = Enum.TextXAlignment.Center,
			})
		end
	end

	-- crystal upgrades
	order += 1
	local divider = Theme.label(parent, {
		text = "💎  MELHORIAS PERMANENTES  (não resetam no rebirth)",
		size = UDim2.new(1, 0, 0, 22),
		color = Theme.purple,
		font = Theme.fontBlack,
		textSize = 11,
	})
	divider.LayoutOrder = order

	for _, kind in ipairs({ "growth", "sell", "luck" }) do
		order += 1
		local upgrade = GameConfig.CrystalUpgrades[kind]
		local rank = snapshot.crystalUpgrades[kind] or 0
		local cost = GameConfig.crystalCost(kind, rank)
		local r = row(parent, order, 54)
		r.BackgroundColor3 = Color3.fromRGB(40, 32, 56)

		Theme.label(r, {
			text = upgrade.name .. "  ·  Rank " .. rank .. "/" .. upgrade.maxRank,
			size = UDim2.new(1, -130, 0, 20),
			position = UDim2.fromOffset(12, 8),
			font = Theme.fontBlack,
			textSize = 13,
		})
		Theme.label(r, {
			text = string.format("+%d%% por rank", math.floor(upgrade.step * 100 + 0.5)),
			size = UDim2.new(1, -130, 0, 16),
			position = UDim2.fromOffset(12, 28),
			font = Theme.fontBody,
			textSize = 11,
			color = Theme.dim,
		})

		if cost then
			local btn = Theme.button(r, {
				text = "💎 " .. cost,
				size = UDim2.fromOffset(110, 38),
				position = UDim2.new(1, -122, 0.5, 0),
				anchor = Vector2.new(0, 0.5),
				color = Color3.fromRGB(72, 50, 110),
				textColor = Theme.purple,
				textSize = 13,
			})
			btn.MouseButton1Click:Connect(function()
				NetClient.action(Net.ActionKind.BuyCrystal, kind)
			end)
		else
			Theme.label(r, {
				text = "MAX",
				size = UDim2.fromOffset(110, 38),
				position = UDim2.new(1, -122, 0.5, 0),
				anchor = Vector2.new(0, 0.5),
				color = Theme.dim,
				font = Theme.fontBlack,
				xAlign = Enum.TextXAlignment.Center,
			})
		end
	end
end

---------------------------------------------------------------------------
-- TAB: REBIRTH
---------------------------------------------------------------------------

rowBuilders.rebirth = function(parent, snapshot)
	local order = 0
	local cfg = GameConfig.Rebirth

	order += 1
	local info = row(parent, order, 96)
	Theme.label(info, {
		text = "♻️  Rebirth " .. (snapshot.rebirths + 1),
		size = UDim2.new(1, -20, 0, 22),
		position = UDim2.fromOffset(12, 10),
		font = Theme.fontBlack,
		textSize = 18,
		color = Theme.gold,
	})
	Theme.label(info, {
		text = string.format(
			"Requer Nível %d  +  %s\nReseta cash, nivel e upgrades.\nMantém cristais e melhorias permanentes.",
			cfg.RequiredLevel,
			Format.money(cfg.RequiredCash)
		),
		size = UDim2.new(1, -24, 0, 52),
		position = UDim2.fromOffset(12, 36),
		font = Theme.fontBody,
		textSize = 12,
		color = Theme.dim,
		wrapped = true,
	})

	order += 1
	local rewards = row(parent, order, 64)
	Theme.label(rewards, {
		text = "Recompensa:  💎 " .. GameConfig.rebirthCrystals(snapshot.rebirths) .. "  ·  x" .. string.format(
			"%.1f",
			GameConfig.rebirthMultiplier(snapshot.rebirths + 1)
		) .. " em tudo",
		size = UDim2.new(1, -24, 0, 20),
		position = UDim2.fromOffset(12, 10),
		font = Theme.fontBlack,
		textSize = 13,
		color = Theme.purple,
	})
	Theme.label(rewards, {
		text = "Rebirth atual: " .. snapshot.rebirths .. "/" .. cfg.Max,
		size = UDim2.new(1, -24, 0, 16),
		position = UDim2.fromOffset(12, 32),
		font = Theme.fontBody,
		textSize = 11,
		color = Theme.dim,
	})

	order += 1
	local canRebirth = snapshot.level >= cfg.RequiredLevel
		and snapshot.cash >= cfg.RequiredCash
		and snapshot.rebirths < cfg.Max
	local btn = Theme.button(parent, {
		text = snapshot.rebirths >= cfg.Max and "REBIRTH MÁXIMO" or "FAZER REBIRTH",
		size = UDim2.new(1, 0, 0, 46),
		color = canRebirth and Color3.fromRGB(96, 70, 20) or Theme.panelAlt,
		textColor = canRebirth and Theme.gold or Theme.dim,
		textSize = 15,
	})
	btn.LayoutOrder = order
	btn.MouseButton1Click:Connect(function()
		NetClient.action(Net.ActionKind.Rebirth)
	end)

	order += 1
	local stats = row(parent, order, 84)
	Theme.label(stats, {
		text = "📊  Estatísticas",
		size = UDim2.new(1, -24, 0, 18),
		position = UDim2.fromOffset(12, 8),
		font = Theme.fontBlack,
		textSize = 13,
	})
	Theme.label(stats, {
		text = string.format(
			"Colheitas: %s\nTotal ganho: %s\nMaior venda: %s",
			Format.number(snapshot.stats.harvests),
			Format.money(snapshot.stats.earned),
			Format.money(snapshot.stats.bestSale)
		),
		size = UDim2.new(1, -24, 0, 58),
		position = UDim2.fromOffset(12, 24),
		font = Theme.fontBody,
		textSize = 11,
		color = Theme.dim,
		wrapped = true,
	})
end

---------------------------------------------------------------------------
-- TAB: CODIGOS
---------------------------------------------------------------------------

rowBuilders.codes = function(parent, snapshot)
	local order = 1
	local r = row(parent, order, 92)

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -24, 0, 38)
	box.Position = UDim2.fromOffset(12, 12)
	box.BackgroundColor3 = Theme.bg
	box.BorderSizePixel = 0
	box.Font = Theme.font
	box.TextSize = 14
	box.TextColor3 = Theme.text
	box.PlaceholderText = "digite o código..."
	box.PlaceholderColor3 = Theme.dim
	box.Text = ""
	box.ClearTextOnFocus = false
	box.Parent = r
	Theme.corner(box, 8)
	Theme.stroke(box, Theme.stroke, 1, 0.4)

	local submit = Theme.button(r, {
		text = "RESGATAR",
		size = UDim2.new(1, -24, 0, 32),
		position = UDim2.fromOffset(12, 54),
		color = Theme.greenDark,
		textSize = 13,
	})
	submit.MouseButton1Click:Connect(function()
		if box.Text ~= "" then
			NetClient.action(Net.ActionKind.Redeem, box.Text)
			box.Text = ""
		end
	end)

	for code, entry in pairs(GameConfig.Codes) do
		order += 1
		local rr = row(parent, order, 44)
		local redeemed = snapshot.redeemedCodes and snapshot.redeemedCodes[code]
		Theme.label(rr, {
			text = code,
			size = UDim2.new(1, -130, 1, 0),
			position = UDim2.fromOffset(12, 0),
			font = Theme.fontBlack,
			textSize = 13,
			color = redeemed and Theme.dim or Theme.text,
		})
		Theme.label(rr, {
			text = redeemed and "resgatado" or entry.label,
			size = UDim2.fromOffset(110, 44),
			position = UDim2.new(1, -122, 0, 0),
			font = Theme.fontBody,
			textSize = 11,
			color = redeemed and Theme.dim or Theme.green,
			xAlign = Enum.TextXAlignment.Right,
		})
	end
end

---------------------------------------------------------------------------
-- SHELL
---------------------------------------------------------------------------

-- Assinatura dos campos que a UI mostra. Se nada mudou, nao reconstroi.
local function signature(snapshot)
	return table.concat({
		currentTab,
		snapshot.level,
		snapshot.selectedCrop,
		snapshot.plots,
		snapshot.upgrades.conveyor,
		snapshot.upgrades.sell,
		snapshot.upgrades.luck,
		snapshot.upgrades.auto,
		snapshot.crystalUpgrades.growth,
		snapshot.crystalUpgrades.sell,
		snapshot.crystalUpgrades.luck,
		snapshot.rebirths,
		snapshot.crystals,
		math.floor(snapshot.cash / 50),
		snapshot.stats.harvests // 500,
	}, "|")
end

local function renderTab(snapshot, force)
	local content = refs.content
	if not content then
		return
	end
	local sig = signature(snapshot)
	if not force and sig == refs.lastSig then
		return
	end
	refs.lastSig = sig
	clear(content)
	local builder = rowBuilders[currentTab]
	if builder then
		builder(content, snapshot)
	end
end

function Panels.build(gui)
	local panel = Theme.frame(gui, {
		size = UDim2.fromOffset(340, 470),
		position = UDim2.new(1, -16, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.bg,
		transparency = 0.06,
		radius = 16,
	})
	panel.Name = "PanelsRoot"
	refs.root = panel

	local header = Theme.frame(panel, {
		size = UDim2.new(1, 0, 0, 34),
		position = UDim2.fromOffset(0, 8),
		color = Theme.panel,
		transparency = 1,
		radius = 12,
		stroke = false,
	})
	header.Name = "DragHandle"
	Theme.label(header, {
		text = "  ⠿  FARMTYCOON",
		size = UDim2.fromScale(1, 1),
		font = Theme.fontBlack,
		textSize = 16,
		color = Theme.green,
	})
	Theme.makeDraggable(panel, header)

	local tabBar = Theme.frame(panel, {
		size = UDim2.new(1, -20, 0, 38),
		position = UDim2.fromOffset(10, 42),
		color = Theme.panel,
		transparency = 0.2,
		radius = 10,
		stroke = false,
	})
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 4)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar
	Theme.padding(tabBar, 4)

	refs.tabs = {}
	for index, tab in ipairs(TABS) do
		local button = Theme.button(tabBar, {
			text = tab.label,
			size = UDim2.new(0.25, -5, 1, 0),
			color = Theme.panelAlt,
			textSize = 11,
			radius = 7,
		})
		button.LayoutOrder = index
		button.Name = "Tab_" .. tab.id
		refs.tabs[tab.id] = button
		button.MouseButton1Click:Connect(function()
			currentTab = tab.id
			Panels.refresh()
		end)
	end

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -20, 1, -100)
	scroll.Position = UDim2.fromOffset(10, 88)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.stroke
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.Parent = panel
	refs.content = scroll

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Name = "Layout"
	layout.Parent = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = scroll

	-- botao de esconder menu
	local toggle = Theme.button(gui, {
		text = "☰",
		size = UDim2.fromOffset(44, 44),
		position = UDim2.new(1, -16, 0, 16),
		anchor = Vector2.new(1, 0),
		color = Theme.bg,
		transparency = 0.08,
	})
	toggle.Name = "MenuToggle"
	toggle.MouseButton1Click:Connect(function()
		Panels.toggle()
	end)

	State.subscribe(function(snapshot)
		refs.lastSnapshot = snapshot
		if panel.Visible then
			renderTab(snapshot)
		end
	end)

	panel.Visible = open
	return panel
end

function Panels.toggle()
	open = not open
	if refs.root then
		refs.root.Visible = open
	end
end

function Panels.refresh()
	for id, button in pairs(refs.tabs) do
		button.BackgroundColor3 = id == currentTab and Theme.greenDark or Theme.panelAlt
	end
	if refs.lastSnapshot then
		renderTab(refs.lastSnapshot, true)
	end
end

return Panels
