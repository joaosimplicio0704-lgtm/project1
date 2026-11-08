-- PetsPanel
-- Inventário em grade: equipar, vender, e a fusão dos 3 selecionados.
-- Clique no pet = equipar/desequipar. Segurar = modo venda.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local NetClient = require(script.Parent.NetClient)

local PetsPanel = {}

local refs = { cards = {} }
local gui
local fuseMode = false
local fuseSelection = {}
local sellMode = false

local CARD = 92
local PER_ROW = 6

local function sortedPets(snapshot)
	local list = {}
	for _, instance in ipairs(snapshot.pets or {}) do
		table.insert(list, instance)
	end
	table.sort(list, function(a, b)
		local petA = GameConfig.pet(a.petId)
		local petB = GameConfig.pet(b.petId)
		if not petA or not petB then
			return false
		end
		local ra = GameConfig.rarity(petA.rarity).order
		local rb = GameConfig.rarity(petB.rarity).order
		if ra ~= rb then
			return ra > rb
		end
		return petA.income > petB.income
	end)
	return list
end

local function isEquipped(snapshot, uid)
	for _, id in ipairs(snapshot.equipped or {}) do
		if id == uid then
			return true
		end
	end
	return false
end

local function inFuse(uid)
	for _, id in ipairs(fuseSelection) do
		if id == uid then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------
-- CARD
---------------------------------------------------------------------------

local function buildCard(parent, instance)
	local pet = GameConfig.pet(instance.petId)
	if not pet then
		return nil
	end
	local rarity = GameConfig.rarity(pet.rarity)

	local card = Instance.new("TextButton")
	card.Size = UDim2.fromOffset(CARD, CARD + 22)
	card.BackgroundColor3 = Color3.fromRGB(255, 252, 246)
	card.BorderSizePixel = 0
	card.AutoButtonColor = false
	card.Text = ""
	card.ClipsDescendants = false
	card.Parent = parent
	Theme.corner(card, 18)
	local stroke = Theme.stroke(card, rarity.color, 4)

	local iconHolder = Instance.new("Frame")
	iconHolder.Size = UDim2.fromOffset(CARD - 20, CARD - 20)
	iconHolder.Position = UDim2.fromOffset(10, 8)
	iconHolder.BackgroundColor3 = pet.color
	iconHolder.BorderSizePixel = 0
	iconHolder.ZIndex = 2
	iconHolder.Parent = card
	Theme.corner(iconHolder, math.floor((CARD - 20) / 2))
	Theme.stroke(iconHolder, Theme.outline, 2)

	Theme.label(iconHolder, {
		text = pet.emoji,
		size = UDim2.fromScale(1, 1),
		textSize = 44,
		strokeTransparency = 1,
		zIndex = 3,
	})

	local name = Theme.label(card, {
		text = pet.name,
		size = UDim2.new(1, -8, 0, 18),
		position = UDim2.fromOffset(4, CARD - 10),
		textSize = 13,
		color = Theme.textDark,
		strokeTransparency = 1,
		zIndex = 3,
	})

	local income = Theme.label(card, {
		text = "🪙 " .. Format.number(pet.income * (instance.golden and 1.5 or 1)),
		size = UDim2.new(1, -8, 0, 16),
		position = UDim2.fromOffset(4, CARD + 4),
		textSize = 13,
		color = Color3.fromRGB(220, 150, 30),
		strokeTransparency = 1,
		zIndex = 3,
	})

	-- selo EQUIPADO
	local badge = Theme.label(card, {
		text = "✓",
		size = UDim2.fromOffset(26, 26),
		position = UDim2.new(1, -6, 0, -6),
		anchor = Vector2.new(1, 0),
		textSize = 18,
		color = Color3.fromRGB(255, 255, 255),
		strokeTransparency = 1,
		zIndex = 6,
	})
	local badgeBg = Instance.new("Frame")
	badgeBg.Size = UDim2.fromOffset(26, 26)
	badgeBg.Position = UDim2.new(1, -6, 0, -6)
	badgeBg.AnchorPoint = Vector2.new(1, 0)
	badgeBg.BackgroundColor3 = Color3.fromRGB(110, 205, 110)
	badgeBg.BorderSizePixel = 0
	badgeBg.ZIndex = 5
	badgeBg.Visible = false
	badgeBg.Parent = card
	Theme.corner(badgeBg, 13)
	Theme.stroke(badgeBg, Theme.outline, 2)
	badge.Parent = badgeBg
	badge.Position = UDim2.fromScale(0.5, 0.5)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Size = UDim2.fromScale(1, 1)

	if instance.golden then
		local glow = Instance.new("UIStroke")
		glow.Color = Color3.fromRGB(255, 210, 80)
		glow.Thickness = 5
		glow.Transparency = 0.2
		glow.Parent = card
	end

	card.MouseButton1Click:Connect(function()
		if fuseMode then
			local found = nil
			for index, id in ipairs(fuseSelection) do
				if id == instance.uid then
					found = index
					break
				end
			end
			if found then
				table.remove(fuseSelection, found)
			elseif #fuseSelection < 3 then
				table.insert(fuseSelection, instance.uid)
			end
			PetsPanel.refresh()
			return
		end

		if sellMode then
			PetsPanel.confirmSell(instance.uid)
			return
		end

		if isEquipped(State.snapshot, instance.uid) then
			NetClient.action(Net.ActionKind.Unequip, instance.uid)
		else
			NetClient.action(Net.ActionKind.Equip, instance.uid)
		end
	end)

	return {
		card = card,
		stroke = stroke,
		badgeBg = badgeBg,
		instance = instance,
		pet = pet,
	}
end

---------------------------------------------------------------------------
-- BUILD
---------------------------------------------------------------------------

function PetsPanel.build(parentGui)
	gui = parentGui

	local root = Theme.panel(gui, {
		name = "PetsPanel",
		size = UDim2.fromOffset(660, 600),
		position = UDim2.new(0.5, 0, 0.5, 0),
		color = Theme.white,
		radius = 30,
		zIndex = 25,
	})
	root.Visible = false
	refs.root = root

	Theme.titleTag(root, "MEUS PETS", { width = 240, offset = -26, zIndex = 24 })

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
		PetsPanel.hide()
	end)

	refs.countLabel = Theme.label(root, {
		text = "0 / 0 equipados",
		size = UDim2.new(1, -40, 0, 24),
		position = UDim2.fromOffset(24, 88),
		xAlign = Enum.TextXAlignment.Left,
		textSize = 17,
		color = Theme.textDark,
		strokeTransparency = 1,
		zIndex = 27,
	})

	-- botões de modo
	local modeBar = Instance.new("Frame")
	modeBar.Size = UDim2.new(1, -40, 0, 46)
	modeBar.Position = UDim2.fromOffset(20, 116)
	modeBar.BackgroundTransparency = 1
	modeBar.ZIndex = 27
	modeBar.Parent = root
	Theme.list(modeBar, {
		direction = Enum.FillDirection.Horizontal,
		padding = 8,
		hAlign = Enum.HorizontalAlignment.Left,
	})

	local function modeButton(text, order, color)
		local btn = Theme.button(modeBar, {
			text = text,
			size = UDim2.fromOffset(150, 46),
			color = color,
			textSize = 17,
			layoutOrder = order,
			radius = 23,
			shadow = false,
			zIndex = 28,
		})
		return btn
	end

	local fuseButton = modeButton("FUNDIR", 1, Theme.purple)
	local sellButton = modeButton("VENDER", 2, Theme.red)

	fuseButton.MouseButton1Click:Connect(function()
		fuseMode = not fuseMode
		sellMode = false
		fuseSelection = {}
		PetsPanel.refresh()
	end)

	sellButton.MouseButton1Click:Connect(function()
		sellMode = not sellMode
		fuseMode = false
		PetsPanel.refresh()
	end)

	local confirmFuse = Theme.button(modeBar, {
		text = "CONFIRMAR FUSÃO",
		size = UDim2.fromOffset(200, 46),
		color = Theme.pink,
		textSize = 16,
		layoutOrder = 3,
		radius = 23,
		shadow = false,
		zIndex = 28,
	})
	refs.confirmFuse = confirmFuse
	confirmFuse.MouseButton1Click:Connect(function()
		if #fuseSelection == 3 then
			NetClient.action(Net.ActionKind.Fuse, fuseSelection)
			fuseSelection = {}
			fuseMode = false
			PetsPanel.refresh()
		end
	end)

	-- grade
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -40, 1, -190)
	scroll.Position = UDim2.fromOffset(20, 172)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = Color3.fromRGB(200, 210, 225)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.ZIndex = 26
	scroll.Parent = root

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(CARD, CARD + 22)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.Parent = scroll
	refs.grid = scroll

	refs.empty = Theme.label(root, {
		text = "Nenhum pet ainda.\nAbra um ovo na aba OVOS 🥚",
		size = UDim2.new(1, -60, 0, 120),
		position = UDim2.fromScale(0.5, 0.55),
		anchor = Vector2.new(0.5, 0.5),
		textSize = 22,
		color = Color3.fromRGB(170, 170, 180),
		strokeTransparency = 1,
		wrapped = true,
		zIndex = 27,
	})

	Theme.makeDraggable(root, header)

	State.subscribe(function()
		if root.Visible then
			PetsPanel.refresh()
		end
	end)

	return root
end

function PetsPanel.confirmSell(uid)
	local instance = nil
	for _, cardRef in pairs(refs.cards) do
		if cardRef.instance.uid == uid then
			instance = cardRef.instance
			break
		end
	end
	if not instance then
		return
	end
	-- venda direta (o servidor devolve o valor via toast)
	NetClient.action(Net.ActionKind.SellPet, uid)
end

function PetsPanel.refresh()
	local snapshot = State.snapshot
	if not snapshot or not refs.root then
		return
	end

	for _, cardRef in pairs(refs.cards) do
		cardRef.card:Destroy()
	end
	refs.cards = {}

	local list = sortedPets(snapshot)
	refs.empty.Visible = #list == 0

	for index, instance in ipairs(list) do
		local cardRef = buildCard(refs.grid, instance)
		if cardRef then
			cardRef.card.LayoutOrder = index
			cardRef.badgeBg.Visible = isEquipped(snapshot, instance.uid)

			if inFuse(instance.uid) then
				cardRef.stroke.Color = Theme.cyan
				cardRef.stroke.Thickness = 7
			end
			if sellMode then
				cardRef.card.BackgroundColor3 = Color3.fromRGB(255, 235, 235)
			end
			refs.cards[instance.uid] = cardRef
		end
	end

	refs.countLabel.Text = string.format(
		"%d pets · %d/%d equipados · renda +%s/s",
		#list,
		#snapshot.equipped,
		snapshot.slots,
		Format.number(snapshot.income)
	)

	refs.confirmFuse.Visible = fuseMode
	refs.confirmFuse.Text = string.format("CONFIRMAR FUSÃO (%d/3)", #fuseSelection)
	refs.confirmFuse.BackgroundColor3 = #fuseSelection == 3 and Theme.green or Color3.fromRGB(190, 190, 200)
end

function PetsPanel.show()
	refs.root.Visible = true
	PetsPanel.refresh()
end

function PetsPanel.hide()
	refs.root.Visible = false
	fuseMode = false
	sellMode = false
	fuseSelection = {}
end

function PetsPanel.toggle()
	if refs.root.Visible then
		PetsPanel.hide()
	else
		PetsPanel.show()
	end
end

return PetsPanel
