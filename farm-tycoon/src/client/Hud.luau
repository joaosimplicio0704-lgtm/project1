-- Hud
-- Barra superior sempre visivel: cash, cristais, nivel/xp, rebirth.
-- Atualiza por snapshot, sem recriar instancias.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local GameConfig = require(Shared.GameConfig)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)

local Hud = {}

local refs = {}

function Hud.build(gui)
	local bar = Theme.frame(gui, {
		name = "Hud",
		size = UDim2.fromOffset(520, 64),
		position = UDim2.new(0.5, 0, 0, 12),
		anchor = Vector2.new(0.5, 0),
		color = Theme.bg,
		transparency = 0.08,
		radius = 14,
	})
	bar.Name = "TopBar"
	Theme.gradient(bar, Color3.fromRGB(30, 36, 50), Color3.fromRGB(16, 19, 26))

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = bar
	Theme.padding(bar, 6)

	local function stat(order, icon, color)
		local box = Theme.frame(bar, {
			size = UDim2.fromOffset(120, 46),
			color = Theme.panelAlt,
			transparency = 0.25,
			radius = 10,
			stroke = false,
		})
		box.LayoutOrder = order

		local iconLabel = Theme.label(box, {
			text = icon,
			size = UDim2.fromOffset(28, 46),
			position = UDim2.fromOffset(8, 0),
			textSize = 20,
		})
		iconLabel.Name = "Icon"

		local value = Theme.label(box, {
			text = "0",
			size = UDim2.new(1, -42, 0.5, 0),
			position = UDim2.fromOffset(38, 6),
			color = color,
			font = Theme.fontBlack,
			textSize = 18,
		})
		value.Name = "Value"

		local sub = Theme.label(box, {
			text = "",
			size = UDim2.new(1, -42, 0, 14),
			position = UDim2.fromOffset(38, 26),
			color = Theme.dim,
			font = Theme.fontBody,
			textSize = 11,
		})
		sub.Name = "Sub"
		return value, sub
	end

	refs.cash, refs.cashSub = stat(1, "💵", Theme.green)
	refs.crystals, refs.crystalsSub = stat(2, "💎", Theme.purple)

	-- nivel com barra
	local levelBox = Theme.frame(bar, {
		size = UDim2.fromOffset(238, 46),
		color = Theme.panelAlt,
		transparency = 0.25,
		radius = 10,
		stroke = false,
	})
	levelBox.LayoutOrder = 3

	refs.level = Theme.label(levelBox, {
		text = "Nível 1",
		size = UDim2.new(1, -16, 0, 16),
		position = UDim2.fromOffset(10, 5),
		font = Theme.fontBlack,
		textSize = 13,
	})
	refs.xpText = Theme.label(levelBox, {
		text = "0 / 0 XP",
		size = UDim2.new(1, -16, 0, 12),
		position = UDim2.fromOffset(10, 20),
		color = Theme.dim,
		font = Theme.fontBody,
		textSize = 10,
		xAlign = Enum.TextXAlignment.Right,
	})

	refs.xpBar, refs.xpFill = Theme.bar(levelBox, {
		size = UDim2.new(1, -20, 0, 7),
		position = UDim2.fromOffset(10, 34),
		color = Theme.cyan,
	})

	refs.pending = Theme.label(gui, {
		text = "",
		size = UDim2.fromOffset(300, 18),
		position = UDim2.new(0.5, 0, 0, 84),
		anchor = Vector2.new(0.5, 0),
		color = Theme.dim,
		font = Theme.fontBody,
		textSize = 12,
		xAlign = Enum.TextXAlignment.Center,
	})

	refs.rebirth = Theme.label(gui, {
		text = "",
		size = UDim2.fromOffset(300, 20),
		position = UDim2.new(0.5, 0, 0, 102),
		anchor = Vector2.new(0.5, 0),
		color = Theme.gold,
		font = Theme.fontBlack,
		textSize = 13,
		xAlign = Enum.TextXAlignment.Center,
	})

	local lastPending = -1

	local function setText(label, text)
		if label.Text ~= text then
			label.Text = text
		end
	end

	State.subscribe(function(snapshot)
		setText(refs.cash, Format.money(snapshot.cash))
		setText(refs.cashSub, "x" .. string.format("%.1f", snapshot.sellMult) .. " venda")
		setText(refs.crystals, Format.number(snapshot.crystals))
		setText(refs.crystalsSub, "sorte " .. string.format("%.1f", snapshot.luck))
		setText(refs.level, "Nível " .. snapshot.level)
		local pending = math.floor((snapshot.farm.pending or 0) * 10) / 10
		if pending ~= lastPending then
			lastPending = pending
			refs.pending.Text = "⏳ " .. Format.money(pending)
		end

		local need = snapshot.xpNeed
		if need < 0 then
			setText(refs.xpText, "MAX")
			refs.xpFill.Size = UDim2.fromScale(1, 1)
		else
			setText(refs.xpText, Format.number(snapshot.xp) .. " / " .. Format.number(need) .. " XP")
			refs.xpFill.Size = UDim2.fromScale(math.clamp(snapshot.xp / need, 0, 1), 1)
		end

		if snapshot.rebirths > 0 then
			setText(
				refs.rebirth,
				"REBIRTH "
					.. snapshot.rebirths
					.. "  ·  x"
					.. string.format("%.1f", GameConfig.rebirthMultiplier(snapshot.rebirths))
					.. " em tudo"
			)
		else
			setText(refs.rebirth, "")
		end
	end)

	-- nome do jogador no canto
	local playerName = Theme.label(gui, {
		text = Players.LocalPlayer.DisplayName,
		size = UDim2.fromOffset(260, 18),
		position = UDim2.new(0, 16, 1, -26),
		color = Theme.dim,
		font = Theme.fontBody,
		textSize = 12,
	})
	playerName.Name = "PlayerName"

	return refs
end

return Hud
