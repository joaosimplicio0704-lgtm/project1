-- BiomesPanel
-- Mapa-múndi do jogo: um cartão por bioma, com o ovo daquele mundo, o preço
-- do ovo e o requisito de desbloqueio. Tecla M abre; clicar viaja.
--
-- O painel NUNCA decide se pode viajar: mostra o cadeado a partir do snapshot
-- (biomes = mapa de desbloqueio vindo do servidor) e manda o pedido. Quem
-- barra é o servidor, em Game.handlers.travel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Biomes = require(Shared.Biomes)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local NetClient = require(script.Parent.NetClient)

local BiomesPanel = {}

local refs = { cards = {}, root = nil }
local gui

local CARD_W = 176
local CARD_H = 208
local PER_ROW = 4
local GAP = 12

local function makeCard(parent, biome, index)
	local card = Instance.new("TextButton")
	card.Name = "Biome_" .. biome.id
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.Position = UDim2.fromOffset((index % PER_ROW) * (CARD_W + GAP), math.floor(index / PER_ROW) * (CARD_H + GAP))
	card.BackgroundColor3 = Color3.fromRGB(biome.colors.grass[1], biome.colors.grass[2], biome.colors.grass[3])
	card.BorderSizePixel = 0
	card.AutoButtonColor = true
	card.Text = ""
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(biome.colors.grassDark[1], biome.colors.grassDark[2], biome.colors.grassDark[3])
	stroke.Thickness = 3
	stroke.Parent = card

	local emoji = Instance.new("TextLabel")
	emoji.Size = UDim2.fromScale(1, 0.34)
	emoji.Position = UDim2.fromScale(0, 0.06)
	emoji.BackgroundTransparency = 1
	emoji.Text = biome.emoji
	emoji.TextScaled = true
	emoji.Font = Theme.font
	emoji.Parent = card

	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(0.94, 0.16)
	name.Position = UDim2.fromScale(0.03, 0.44)
	name.BackgroundTransparency = 1
	name.Text = biome.name
	name.TextScaled = true
	name.Font = Theme.font
	name.TextColor3 = Theme.white
	name.TextStrokeTransparency = 0
	name.TextStrokeColor3 = Theme.outline
	name.Parent = card

	local egg = GameConfig.EggById[biome.eggId]
	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.Size = UDim2.fromScale(0.94, 0.14)
	detail.Position = UDim2.fromScale(0.03, 0.62)
	detail.BackgroundTransparency = 1
	detail.Text = egg and (egg.emoji .. " " .. Format.number(egg.cost)) or "—"
	detail.TextScaled = true
	detail.Font = Theme.font
	detail.TextColor3 = Theme.yellow
	detail.TextStrokeTransparency = 0
	detail.TextStrokeColor3 = Theme.outline
	detail.Parent = card

	-- cadeado / status
	local lock = Instance.new("TextLabel")
	lock.Name = "Lock"
	lock.Size = UDim2.fromScale(0.94, 0.16)
	lock.Position = UDim2.fromScale(0.03, 0.79)
	lock.BackgroundTransparency = 1
	lock.Text = ""
	lock.TextScaled = true
	lock.Font = Theme.font
	lock.TextColor3 = Theme.white
	lock.TextStrokeTransparency = 0
	lock.TextStrokeColor3 = Theme.outline
	lock.Parent = card

	-- selo de "você está aqui"
	local here = Instance.new("TextLabel")
	here.Name = "Here"
	here.Size = UDim2.fromOffset(64, 22)
	here.Position = UDim2.fromOffset(CARD_W - 70, 8)
	here.BackgroundColor3 = Theme.green
	here.BorderSizePixel = 0
	here.Text = "AQUI"
	here.TextScaled = true
	here.Font = Theme.font
	here.TextColor3 = Theme.white
	here.Visible = false
	here.Parent = card

	local hereCorner = Instance.new("UICorner")
	hereCorner.CornerRadius = UDim.new(0, 8)
	hereCorner.Parent = here

	card.MouseButton1Click:Connect(function()
		local snapshot = State.snapshot
		local unlocked = snapshot and snapshot.biomes and snapshot.biomes[biome.id]
		if not unlocked then
			local label = Biomes.unlockLabel(biome)
			require(script.Parent.Toasts).push("🔒 " .. biome.name .. " — " .. label, "error")
			return
		end
		NetClient.action(Net.ActionKind.Travel, biome.id)
		BiomesPanel.hide()
	end)

	refs.cards[biome.id] = { card = card, lock = lock, here = here, detail = detail }
	return card
end

function BiomesPanel.build(parent)
	gui = parent

	local overlay = Instance.new("TextButton")
	overlay.Name = "BiomesPanel"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(20, 12, 8)
	overlay.BackgroundTransparency = 0.45
	overlay.BorderSizePixel = 0
	overlay.Text = ""
	overlay.Visible = false
	overlay.ZIndex = 40
	overlay.Parent = parent
	refs.root = overlay

	local frame = Instance.new("Frame")
	frame.Name = "Card"
	frame.Size = UDim2.fromOffset(PER_ROW * CARD_W + (PER_ROW - 1) * GAP + 48, 420)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Theme.panel
	frame.BorderSizePixel = 0
	frame.ZIndex = 41
	frame.Parent = overlay

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 20)
	frameCorner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -32, 0, 44)
	title.Position = UDim2.fromOffset(16, 12)
	title.BackgroundTransparency = 1
	title.Text = "🗺️ MUNDOS"
	title.TextScaled = true
	title.Font = Theme.font
	title.TextColor3 = Theme.textDark
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 42
	title.Parent = frame

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.fromOffset(40, 40)
	closeButton.Position = UDim2.new(1, -52, 0, 12)
	closeButton.BackgroundColor3 = Theme.red
	closeButton.BorderSizePixel = 0
	closeButton.Text = "✕"
	closeButton.TextScaled = true
	closeButton.Font = Theme.font
	closeButton.TextColor3 = Theme.white
	closeButton.ZIndex = 42
	closeButton.Parent = frame
	closeButton.MouseButton1Click:Connect(function()
		BiomesPanel.hide()
	end)

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 12)
	closeCorner.Parent = closeButton

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, -32, 1, -78)
	grid.Position = UDim2.fromOffset(16, 64)
	grid.BackgroundTransparency = 1
	grid.ZIndex = 42
	grid.Parent = frame

	for index, biome in ipairs(Biomes.List) do
		makeCard(grid, biome, index - 1)
	end

	BiomesPanel.refresh()
end

function BiomesPanel.refresh()
	local snapshot = State.snapshot
	for _, biome in ipairs(Biomes.List) do
		local entry = refs.cards[biome.id]
		if entry then
			local unlocked = snapshot and snapshot.biomes and snapshot.biomes[biome.id]
			local current = snapshot and snapshot.biome == biome.id
			entry.lock.Text = unlocked and "✅ aberto" or ("🔒 " .. Biomes.unlockLabel(biome))
			entry.lock.TextColor3 = unlocked and Theme.white or Color3.fromRGB(255, 220, 220)
			entry.here.Visible = current == true
			entry.card.BackgroundTransparency = unlocked and 0 or 0.35
		end
	end
end

function BiomesPanel.show()
	refs.root.Visible = true
	BiomesPanel.refresh()
end

function BiomesPanel.hide()
	refs.root.Visible = false
end

function BiomesPanel.toggle()
	if refs.root.Visible then
		BiomesPanel.hide()
	else
		BiomesPanel.show()
	end
end

return BiomesPanel
