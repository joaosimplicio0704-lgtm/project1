-- World
-- Constroi o mapa inteiro em codigo: sem .rbxm, sem asset externo.
-- Cada jogador ganha um lote (base) alocado na grade, estilo tycoon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)

local World = {}

local LAYOUT = GameConfig.Layout
local LOT_SIZE = LAYOUT.lotSize
local LOTS_PER_ROW = 4
local MAX_LOTS = 24
local FOLDER_NAME = "FarmTycoon"

local lotOwners = {} -- [lotIndex] = userId
local lots = {} -- [lotIndex] = { model, origin, plots, conveyor, sign }

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

---------------------------------------------------------------------------
-- AMBIENTE
---------------------------------------------------------------------------

function World.buildEnvironment()
	Lighting.Ambient = Color3.fromRGB(95, 105, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 155, 175)
	Lighting.Brightness = 2.6
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = -15
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true

	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	if not existing then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.32
		atmosphere.Haze = 1.2
		atmosphere.Glare = 0.15
		atmosphere.Color = Color3.fromRGB(199, 214, 230)
		atmosphere.Decay = Color3.fromRGB(116, 130, 152)
		atmosphere.Parent = Lighting
	end

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		local b = Instance.new("BloomEffect")
		b.Intensity = 0.45
		b.Size = 26
		b.Threshold = 1.1
		b.Parent = Lighting
	end

	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace

	local ground = part({
		Name = "Ground",
		Size = Vector3.new(1400, 4, 900),
		Position = Vector3.new(0, -2.5, 0),
		Color = Color3.fromRGB(96, 148, 82),
		Material = Enum.Material.Grass,
	})
	ground.Parent = folder

	-- borda elevada pra ninguem cair do mapa
	local rim = part({
		Name = "Rim",
		Size = Vector3.new(1400, 14, 900),
		Position = Vector3.new(0, -11, 0),
		Color = Color3.fromRGB(74, 118, 66),
		Material = Enum.Material.Grass,
	})
	rim.Parent = folder

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Size = Vector3.new(18, 1, 18)
	spawnLocation.Position = Vector3.new(0, 0.5, 400)
	spawnLocation.Anchored = true
	spawnLocation.BrickColor = BrickColor.new("Bright green")
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.TopSurface = Enum.SurfaceType.Smooth
	spawnLocation.Duration = 0
	spawnLocation.Parent = folder

	World.folder = folder

	-- decoracao barata: arvores espalhadas nas bordas (nao no meio dos lotes)
	local rng = Random.new(7)
	for i = 1, 46 do
		local x = (rng:NextNumber() - 0.5) * 1300
		local z = (rng:NextNumber() - 0.5) * 840
		if math.abs(x) < 420 and z > -420 and z < 340 then
			continue
		end
		local trunk = part({
			Size = Vector3.new(2.2, 12, 2.2),
			Position = Vector3.new(x, 6, z),
			Color = Color3.fromRGB(94, 66, 46),
			Material = Enum.Material.Wood,
		})
		trunk.Parent = folder
		local leaves = part({
			Size = Vector3.new(11, 11, 11),
			Position = Vector3.new(x, 14.5, z),
			Color = Color3.fromRGB(52, 122, 66),
			Material = Enum.Material.Grass,
			Shape = Enum.PartType.Ball,
		})
		leaves.Parent = folder
	end
end

---------------------------------------------------------------------------
-- LOTE
---------------------------------------------------------------------------

local function lotOrigin(index)
	local col = (index - 1) % LOTS_PER_ROW
	local row = (index - 1) // LOTS_PER_ROW
	return Vector3.new((col - (LOTS_PER_ROW - 1) / 2) * (LOT_SIZE + 20), 0, -170 + row * (LOT_SIZE + 26))
end

-- O GameConfig entrega a SUPERFICIE do terreno; a terra tem 0.8 de espessura,
-- entao o centro fica 0.4 abaixo. Render usa a mesma superficie, sem divergir.
local SOIL_HEIGHT = 0.8

function World.buildLot(index, userId, displayName)
	local origin = lotOrigin(index)
	local model = Instance.new("Model")
	model.Name = "Lot_" .. index

	local platform = part({
		Name = "Platform",
		Size = Vector3.new(LOT_SIZE, 2, LOT_SIZE),
		Position = origin + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(126, 138, 152),
		Material = Enum.Material.Concrete,
	})
	platform.Parent = model

	-- divisoria de grama por cima do concreto
	local grass = part({
		Name = "Lawn",
		Size = Vector3.new(LOT_SIZE - 4, 0.4, LOT_SIZE - 4),
		Position = origin + Vector3.new(0, 1.6, 0),
		Color = Color3.fromRGB(104, 162, 92),
		Material = Enum.Material.Grass,
	})
	grass.Parent = model

	-- PLOTS: 12 terrenos, 4x3
	local plotParts = {}
	for i = 1, GameConfig.Plots.Max do
		local surface = GameConfig.plotLocalOffset(i)
		local soil = part({
			Name = "Plot_" .. i,
			Size = Vector3.new(LAYOUT.plotSize, SOIL_HEIGHT, LAYOUT.plotSize),
			Position = origin + surface - Vector3.new(0, SOIL_HEIGHT / 2, 0),
			Color = Color3.fromRGB(104, 74, 50),
			Material = Enum.Material.Ground,
			TopSurface = Enum.SurfaceType.Smooth,
		})
		soil:SetAttribute("PlotIndex", i)
		soil.Parent = model

		-- poste de marcador para o plot bloqueado
		local marker = part({
			Name = "Lock_" .. i,
			Size = Vector3.new(1, 7, 1),
			Position = origin + surface + Vector3.new(0, 5 - SOIL_HEIGHT / 2, 0),
			Color = Color3.fromRGB(58, 66, 78),
			Material = Enum.Material.Metal,
		})
		marker.Transparency = 0.55
		marker.CanCollide = false
		marker.Parent = model

		plotParts[i] = { soil = soil, marker = marker, origin = origin + surface }
	end

	-- ESTEIRA: lado direito do lote, correndo em Z ate o caixa
	local beltStart = origin + GameConfig.beltLocalStart()
	local beltLength = LAYOUT.beltLength
	local belt = part({
		Name = "Conveyor",
		Size = Vector3.new(LAYOUT.beltWidth, 0.8, beltLength),
		Position = beltStart + Vector3.new(0, 0, beltLength / 2),
		Color = Color3.fromRGB(44, 48, 58),
		Material = Enum.Material.DiamondPlate,
	})
	belt:SetAttribute("BeltStart", beltStart)
	belt:SetAttribute("BeltLength", beltLength)
	belt.Parent = model

	-- laterais da esteira
	for _, side in ipairs({ -(LAYOUT.beltWidth / 2 + 0.2), LAYOUT.beltWidth / 2 + 0.2 }) do
		local rail = part({
			Name = "Rail",
			Size = Vector3.new(0.5, 1.6, beltLength),
			Position = beltStart + Vector3.new(side, 0.5, beltLength / 2),
			Color = Color3.fromRGB(86, 94, 108),
			Material = Enum.Material.Metal,
		})
		rail.CanCollide = false
		rail.Parent = model
	end

	-- CAIXA / ponto de venda
	local sellPad = part({
		Name = "SellPad",
		Size = Vector3.new(14, 3, 14),
		Position = beltStart + Vector3.new(0, 0.4, beltLength + LAYOUT.sellPadDistance),
		Color = Color3.fromRGB(30, 34, 42),
		Material = Enum.Material.Metal,
	})
	sellPad.Parent = model

	local neonRing = part({
		Name = "SellRing",
		Size = Vector3.new(13, 0.3, 13),
		Position = beltStart + Vector3.new(0, 2.05, beltLength + LAYOUT.sellPadDistance),
		Color = Color3.fromRGB(90, 255, 170),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	neonRing.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(14, 5)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	billboard.AlwaysOnTop = false
	billboard.Adornee = neonRing
	billboard.Parent = neonRing

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(235, 255, 245)
	label.TextStrokeTransparency = 0.4
	label.Text = displayName .. "'s FARM"
	label.Parent = billboard

	-- placa de status
	local statusPart = part({
		Name = "Status",
		Size = Vector3.new(1, 6, 10),
		Position = origin + Vector3.new(-26, 5, 22),
		Color = Color3.fromRGB(30, 34, 42),
		Material = Enum.Material.Metal,
	})
	statusPart.CanCollide = true
	statusPart.Parent = model

	local statusGui = Instance.new("SurfaceGui")
	statusGui.Face = Enum.NormalId.Right
	statusGui.CanvasSize = Vector2.new(400, 240)
	statusGui.Parent = statusPart

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.fromScale(1, 1)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextScaled = true
	statusLabel.TextColor3 = Color3.fromRGB(120, 255, 190)
	statusLabel.Text = "AGUARDANDO"
	statusLabel.Parent = statusGui

	model.Parent = World.folder

	lots[index] = {
		model = model,
		origin = origin,
		plots = plotParts,
		beltStart = beltStart,
		beltLength = beltLength,
		sellPad = sellPad,
		statusLabel = statusLabel,
		owner = userId,
	}
	lotOwners[index] = userId

	return lots[index]
end

function World.getLot(index)
	return lots[index]
end

function World.lotFor(userId)
	for index, owner in pairs(lotOwners) do
		if owner == userId then
			return lots[index], index
		end
	end
	return nil
end

function World.freeLot()
	for index = 1, MAX_LOTS do
		if not lotOwners[index] then
			return index
		end
	end
	return nil
end

function World.releaseLot(index)
	if lots[index] then
		lots[index].model:Destroy()
		lots[index] = nil
	end
	lotOwners[index] = nil
end

---------------------------------------------------------------------------
-- VISUAL POR SNAPSHOT
---------------------------------------------------------------------------

-- O servidor empurra um snapshot leve; o cliente desenha. Aqui so atualizamos
-- o que e barato e autoritativo: marcador de plot bloqueado.
function World.refreshLot(index, plotCount, statusText)
	local lot = lots[index]
	if not lot then
		return
	end

	for i = 1, GameConfig.Plots.Max do
		local plot = lot.plots[i]
		if plot then
			local unlocked = i <= plotCount
			plot.marker.Transparency = unlocked and 1 or 0.55
			plot.marker.CanCollide = false
			plot.soil.Color = unlocked and Color3.fromRGB(104, 74, 50) or Color3.fromRGB(58, 62, 70)
		end
	end

	if statusText then
		lot.statusLabel.Text = statusText
	end
end

return World
