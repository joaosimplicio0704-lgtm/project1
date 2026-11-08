-- World
-- Mapa cartoon low-poly construído em código, no estilo dos tycoons de ovo:
-- palco central, ilhas de ovo, lojas, portal de rebirth e a fonte.
-- Nada de asset externo: tudo Instance.new com cores chapadas.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)

local World = {}

local PALETTE = {
	grass = Color3.fromRGB(104, 196, 90),
	grassDark = Color3.fromRGB(76, 160, 70),
	path = Color3.fromRGB(238, 196, 141),
	pathEdge = Color3.fromRGB(214, 166, 110),
	wood = Color3.fromRGB(150, 100, 62),
	woodDark = Color3.fromRGB(110, 72, 44),
	rock = Color3.fromRGB(178, 190, 205),
	rockDark = Color3.fromRGB(140, 155, 175),
	water = Color3.fromRGB(90, 205, 235),
	sand = Color3.fromRGB(240, 226, 190),
	flower = Color3.fromRGB(255, 150, 190),
	stem = Color3.fromRGB(70, 150, 65),
	white = Color3.fromRGB(250, 250, 250),
	gold = Color3.fromRGB(255, 190, 50),
	goldDark = Color3.fromRGB(230, 150, 30),
	purple = Color3.fromRGB(150, 110, 220),
	purpleDark = Color3.fromRGB(105, 70, 175),
	pink = Color3.fromRGB(255, 170, 210),
	blue = Color3.fromRGB(90, 150, 240),
}

World.palette = PALETTE

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		if key ~= "material" then
			p[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function ball(props, parent)
	local p = part(props, parent)
	p.Shape = Enum.PartType.Ball
	p.CanCollide = false
	return p
end

local function wedge(props, parent)
	local p = Instance.new("WedgePart")
	p.Anchored = true
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

---------------------------------------------------------------------------
-- INFRA
---------------------------------------------------------------------------

local root

function World.build()
	Lighting.Ambient = Color3.fromRGB(120, 132, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(160, 178, 200)
	Lighting.Brightness = 2.8
	Lighting.ClockTime = 13.6
	Lighting.GeographicLatitude = -15
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.6

	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	local atmosphere = existing or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Haze = 0.9
	atmosphere.Glare = 0.2
	atmosphere.Color = Color3.fromRGB(210, 226, 245)
	atmosphere.Decay = Color3.fromRGB(130, 150, 175)
	atmosphere.Parent = Lighting

	local old = Workspace:FindFirstChild("EggTycoon")
	if old then
		old:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "EggTycoon"
	root.Parent = Workspace

	-- agua de fundo + ilha principal em degrade de grama
	part({
		Name = "Ocean",
		Size = Vector3.new(3000, 4, 3000),
		Position = Vector3.new(0, -8, 0),
		Color = PALETTE.water,
		Material = Enum.Material.Water,
		Transparency = 0.15,
		CanCollide = false,
	}, root)

	-- praça central em tijolinho claro
	part({
		Name = "Plaza",
		Size = Vector3.new(150, 3, 150),
		Position = Vector3.new(0, 0.5, 0),
		Color = PALETTE.path,
		Material = Enum.Material.Brick,
	}, root)

	-- ilha de grama ao redor (grande, quadrada, com borda de terra)
	part({
		Name = "Island",
		Size = Vector3.new(340, 8, 340),
		Position = Vector3.new(0, -3.5, 0),
		Color = PALETTE.grass,
		Material = Enum.Material.Grass,
	}, root)

	local dirtRing = part({
		Name = "DirtRing",
		Size = Vector3.new(348, 6, 348),
		Position = Vector3.new(0, -6, 0),
		Color = Color3.fromRGB(170, 110, 70),
		Material = Enum.Material.Ground,
	}, root)
	dirtRing.CanCollide = false

	-- canteiros de grama alta na borda (silhueta cartoon)
	local rng = Random.new(31)
	for i = 1, 26 do
		local angle = (i / 26) * math.pi * 2
		local radius = 178 + rng:NextNumber() * 16
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local h = 8 + rng:NextNumber() * 10
		part({
			Size = Vector3.new(16 + rng:NextNumber() * 10, h, 16 + rng:NextNumber() * 10),
			Position = Vector3.new(x, -1 + h / 2, z),
			Color = i % 2 == 0 and PALETTE.grass or PALETTE.grassDark,
			Material = Enum.Material.Grass,
		}, root)
	end

	World.buildTrees()
	World.buildFountain()
	World.buildEggStands()
	World.buildShop()
	World.buildGemShop()
	World.buildGoldenCrate()
	World.buildFusion()
	World.buildRebirthPortal()
	World.buildTradePost()
	World.buildHalloween()

	-- SpawnLocation: sem isso o Roblox joga o jogador no vazio/default do template
	local spawnPad = part({
		Name = "SpawnLocation",
		Size = Vector3.new(18, 1, 18),
		Position = Vector3.new(0, 3.2, 62),
		Color = PALETTE.path,
		Material = Enum.Material.Brick,
	}, root)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(16, 0.4, 16)
	spawn.Position = Vector3.new(0, 3.9, 62)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = root

	-- anel neon marcando o spawn
	part({
		Name = "SpawnRing",
		Size = Vector3.new(17, 0.25, 17),
		Position = Vector3.new(0, 3.75, 62),
		Color = Color3.fromRGB(96, 240, 235),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, root)

	World.spawnPoint = Vector3.new(0, 5, 62)
end

function World.spawnCFrame()
	return CFrame.new(World.spawnPoint or Vector3.new(0, 5, 60)) * CFrame.Angles(0, math.pi, 0)
end

---------------------------------------------------------------------------
-- DECORACAO
---------------------------------------------------------------------------

local function tree(position, scale, parent)
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = parent

	part({
		Size = Vector3.new(4, 14, 4) * scale,
		Position = position + Vector3.new(0, 6 * scale, 0),
		Color = PALETTE.woodDark,
		Material = Enum.Material.Wood,
	}, model)

	for i, offset in ipairs({ Vector3.new(0, 15, 0), Vector3.new(0, 20, 0), Vector3.new(0, 24, 0) }) do
		local size = (10 - i * 2) * scale
		part({
			Size = Vector3.new(size, size * 0.9, size),
			Position = position + offset * scale,
			Color = i == 3 and Color3.fromRGB(92, 186, 96) or PALETTE.grass,
			Material = Enum.Material.Grass,
		}, model)
	end
	return model
end

local function flower(position, parent)
	local model = Instance.new("Model")
	model.Name = "Flower"
	model.Parent = parent

	part({
		Size = Vector3.new(0.5, 3, 0.5),
		Position = position + Vector3.new(0, 1.5, 0),
		Color = PALETTE.stem,
		Material = Enum.Material.Grass,
		CanCollide = false,
	}, model)

	ball({
		Size = Vector3.new(2.4, 2.4, 2.4),
		Position = position + Vector3.new(0, 3.4, 0),
		Color = PALETTE.flower,
		Material = Enum.Material.SmoothPlastic,
	}, model)
	return model
end

function World.buildTrees()
	local rng = Random.new(77)
	for i = 1, 22 do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = 100 + rng:NextNumber() * 62
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		tree(Vector3.new(x, 0, z), 1 + rng:NextNumber() * 0.55, root)
	end

	for i = 1, 40 do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = 88 + rng:NextNumber() * 70
		flower(Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), root)
	end
end

---------------------------------------------------------------------------
-- FONTE CENTRAL
---------------------------------------------------------------------------

function World.buildFountain()
	local model = Instance.new("Model")
	model.Name = "Fountain"
	model.Parent = root

	part({
		Size = Vector3.new(30, 2, 30),
		Position = Vector3.new(0, 1.6, 0),
		Color = PALETTE.white,
		Material = Enum.Material.Marble,
	}, model)

	part({
		Size = Vector3.new(26, 1.2, 26),
		Position = Vector3.new(0, 2.5, 0),
		Color = PALETTE.water,
		Material = Enum.Material.Water,
		Transparency = 0.2,
		CanCollide = false,
	}, model)

	for i = 1, 2 do
		local size = 26 - i * 7
		part({
			Size = Vector3.new(size, 1.4, size),
			Position = Vector3.new(0, 3 + i * 3.4, 0),
			Color = PALETTE.white,
			Material = Enum.Material.Marble,
			CanCollide = false,
		}, model)
		part({
			Size = Vector3.new(size - 3, 1, size - 3),
			Position = Vector3.new(0, 3.4 + i * 3.4, 0),
			Color = PALETTE.water,
			Material = Enum.Material.Water,
			Transparency = 0.25,
			CanCollide = false,
		}, model)
	end

	-- bichinho dourado no topo
	ball({
		Size = Vector3.new(7, 7, 7),
		Position = Vector3.new(0, 15, 0),
		Color = PALETTE.gold,
		Material = Enum.Material.Neon,
	}, model)

	ball({
		Size = Vector3.new(4.5, 4.5, 4.5),
		Position = Vector3.new(0, 19.5, 0),
		Color = PALETTE.gold,
		Material = Enum.Material.Neon,
	}, model)
end

---------------------------------------------------------------------------
-- UI DE MUNDO (placa + click detector)
---------------------------------------------------------------------------

local function makeSign(position, text, color, parent)
	local board = part({
		Name = "Sign_" .. text,
		Size = Vector3.new(16, 6, 0.8),
		Position = position,
		Color = PALETTE.wood,
		Material = Enum.Material.WoodPlanks,
		CanCollide = false,
	}, parent)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 150)
	gui.LightInfluence = 0.2
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.fromRGB(60, 40, 20)
	label.Text = text
	label.Parent = gui

	return board
end

local zoneBindings = {}

local function makeZone(name, position, size, color)
	local hitbox = part({
		Name = "Zone_" .. name,
		Size = size,
		Position = position,
		Color = color or PALETTE.pink,
		Material = Enum.Material.Neon,
		Transparency = 0.72,
		CanCollide = false,
		CanQuery = true,
	}, root)

	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 32
	detector.CursorIcon = "rbxasset://textures/GunCursor.png"
	detector.Parent = hitbox

	zoneBindings[name] = { part = hitbox, detector = detector, color = color }
	return hitbox
end

function World.getZoneBindings()
	return zoneBindings
end

---------------------------------------------------------------------------
-- OVOS
---------------------------------------------------------------------------

function World.buildEggStands()
	-- plataforma de pedra clara onde ficam os ovos
	part({
		Size = Vector3.new(96, 2, 40),
		Position = Vector3.new(0, 2.4, 40),
		Color = PALETTE.sand,
		Material = Enum.Material.Sandstone,
	}, root)

	local eggCount = #GameConfig.Eggs
	local spacing = 14
	local startX = -((eggCount - 1) * spacing) / 2

	for index, egg in ipairs(GameConfig.Eggs) do
		local x = startX + (index - 1) * spacing
		local base = Vector3.new(x, 4.6, 40)

		-- pedestal
		part({
			Size = Vector3.new(9, 3.2, 9),
			Position = base,
			Color = PALETTE.white,
			Material = Enum.Material.Marble,
		}, root)

		part({
			Size = Vector3.new(7.4, 0.8, 7.4),
			Position = base + Vector3.new(0, 2, 0),
			Color = PALETTE.gold,
			Material = Enum.Material.Neon,
		}, root)

		-- ovo (esfera escalada em Y)
		local eggPart = ball({
			Name = "Egg_" .. egg.id,
			Size = Vector3.new(7, 9.6, 7),
			Position = base + Vector3.new(0, 7.2, 0),
			Color = egg.color,
			Material = Enum.Material.SmoothPlastic,
		}, root)
		eggPart:SetAttribute("EggId", egg.id)

		-- pintinhas
		local rng = Random.new(index * 13)
		for i = 1, 7 do
			local theta = rng:NextNumber() * math.pi * 2
			local phi = math.acos(2 * rng:NextNumber() - 1)
			local radius = 3.55
			local offset = Vector3.new(
				math.sin(phi) * math.cos(theta) * radius,
				math.cos(phi) * radius * 1.35,
				math.sin(phi) * math.sin(theta) * radius
			)
			ball({
				Size = Vector3.new(1.6, 1.6, 1.6),
				Position = eggPart.Position + offset,
				Color = egg.spot,
				Material = Enum.Material.SmoothPlastic,
			}, root)
		end

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromScale(12, 5)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 8.5, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = eggPart
		billboard.Parent = eggPart

		local name = Instance.new("TextLabel")
		name.Size = UDim2.fromScale(1, 0.55)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextColor3 = Color3.fromRGB(255, 255, 255)
		name.TextStrokeTransparency = 0
		name.TextStrokeColor3 = Color3.fromRGB(80, 60, 90)
		name.Text = egg.name
		name.Parent = billboard

		local cost = Instance.new("TextLabel")
		cost.Size = UDim2.fromScale(1, 0.4)
		cost.Position = UDim2.fromScale(0, 0.58)
		cost.BackgroundTransparency = 1
		cost.Font = Enum.Font.FredokaOne
		cost.TextScaled = true
		cost.TextColor3 = PALETTE.gold
		cost.TextStrokeTransparency = 0
		cost.TextStrokeColor3 = Color3.fromRGB(80, 50, 10)
		cost.Text = "🪙 " .. require(ReplicatedStorage.Shared.Format).number(egg.cost)
		cost.Parent = billboard

		local detector = Instance.new("ClickDetector")
		detector.MaxActivationDistance = 22
		detector.Parent = eggPart
		detector.Name = "EggClick"

		zoneBindings["egg_" .. egg.id] = { part = eggPart, detector = detector, eggId = egg.id }
	end

	-- letreiro "Ovos"
	makeSign(Vector3.new(0, 22, 40), "OVOS", Color3.fromRGB(255, 255, 255), root)

	-- plataforma vazia pra escalar visualmente
	part({
		Size = Vector3.new(96, 1, 12),
		Position = Vector3.new(0, 3.4, 22),
		Color = PALETTE.pathEdge,
		Material = Enum.Material.Brick,
		CanCollide = false,
	}, root)
end

---------------------------------------------------------------------------
-- LOJAS
---------------------------------------------------------------------------

function World.buildShop()
	local origin = Vector3.new(-64, 0, -10)

	part({
		Size = Vector3.new(28, 1, 24),
		Position = origin + Vector3.new(0, 1.6, 0),
		Color = PALETTE.pathEdge,
		Material = Enum.Material.Brick,
	}, root)

	-- parede de madeira
	part({
		Size = Vector3.new(26, 18, 2),
		Position = origin + Vector3.new(0, 10, -8),
		Color = PALETTE.wood,
		Material = Enum.Material.WoodPlanks,
	}, root)

	-- telhado azul
	local roof = part({
		Size = Vector3.new(30, 2, 20),
		Position = origin + Vector3.new(0, 20, -2),
		Color = PALETTE.blue,
		Material = Enum.Material.Slate,
	}, root)
	roof.CFrame = CFrame.new(roof.Position) * CFrame.Angles(math.rad(-18), 0, 0)

	-- vitrine
	part({
		Size = Vector3.new(18, 9, 1),
		Position = origin + Vector3.new(0, 8, -7),
		Color = Color3.fromRGB(255, 240, 200),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, root)

	-- balcão
	part({
		Size = Vector3.new(22, 4, 5),
		Position = origin + Vector3.new(0, 4, -3),
		Color = PALETTE.woodDark,
		Material = Enum.Material.WoodPlanks,
	}, root)

	for i = -2, 2 do
		ball({
			Size = Vector3.new(3.4, 3.4, 3.4),
			Position = origin + Vector3.new(i * 4, 7.5, -3),
			Color = i % 2 == 0 and PALETTE.gold or PALETTE.pink,
			Material = Enum.Material.Neon,
		}, root)
	end

	makeZone(Net.Zones.Shop, origin + Vector3.new(0, 4, 4), Vector3.new(24, 1, 14), Color3.fromRGB(120, 220, 255))
	makeSign(origin + Vector3.new(0, 25, -7), "LOJA", Color3.fromRGB(255, 255, 255), root)
end

function World.buildGemShop()
	local origin = Vector3.new(64, 0, -10)

	part({
		Size = Vector3.new(28, 1, 24),
		Position = origin + Vector3.new(0, 1.6, 0),
		Color = PALETTE.pathEdge,
		Material = Enum.Material.Brick,
	}, root)

	part({
		Size = Vector3.new(26, 18, 2),
		Position = origin + Vector3.new(0, 10, -8),
		Color = PALETTE.white,
		Material = Enum.Material.SmoothPlastic,
	}, root)

	local roof = part({
		Size = Vector3.new(30, 2, 20),
		Position = origin + Vector3.new(0, 20, -2),
		Color = PALETTE.purple,
		Material = Enum.Material.Slate,
	}, root)
	roof.CFrame = CFrame.new(roof.Position) * CFrame.Angles(math.rad(-18), 0, 0)

	-- gema gigante na frente
	local gem = part({
		Size = Vector3.new(7, 9, 7),
		Position = origin + Vector3.new(0, 9, -1),
		Color = Color3.fromRGB(90, 220, 255),
		Material = Enum.Material.Neon,
	}, root)
	gem.CFrame = CFrame.new(gem.Position) * CFrame.Angles(0, math.rad(45), 0)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 230, 255)
	light.Brightness = 3
	light.Range = 26
	light.Parent = gem

	makeZone(Net.Zones.GemShop, origin + Vector3.new(0, 4, 4), Vector3.new(24, 1, 14), Color3.fromRGB(200, 150, 255))
	makeSign(origin + Vector3.new(0, 25, -7), "MELHORIAS DE GEMAS", Color3.fromRGB(230, 200, 255), root)
end

---------------------------------------------------------------------------
-- CRIAÇÃO DOURADA (o "oven" dourado dos prints)
---------------------------------------------------------------------------

function World.buildGoldenCrate()
	local origin = Vector3.new(-58, 0, 40)

	part({
		Size = Vector3.new(26, 1, 22),
		Position = origin + Vector3.new(0, 1.6, 0),
		Color = PALETTE.gold,
		Material = Enum.Material.Neon,
	}, root)

	-- dois "fornos" brancos com painel azul
	for i, offset in ipairs({ Vector3.new(-6, 0, 0), Vector3.new(6, 0, 0) }) do
		local body = part({
			Size = Vector3.new(9, 12, 8),
			Position = origin + offset + Vector3.new(0, 8, 0),
			Color = PALETTE.white,
			Material = Enum.Material.SmoothPlastic,
		}, root)

		part({
			Size = Vector3.new(5.5, 4.5, 0.6),
			Position = body.Position + Vector3.new(0, 0.5, -4.2),
			Color = Color3.fromRGB(90, 200, 245),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, root)

		part({
			Size = Vector3.new(9.4, 1.2, 8.4),
			Position = body.Position + Vector3.new(0, 6.6, 0),
			Color = PALETTE.gold,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, root)

		ball({
			Size = Vector3.new(1.6, 1.6, 1.6),
			Position = body.Position + Vector3.new(0, 8.2, 0),
			Color = PALETTE.gold,
			Material = Enum.Material.Neon,
		}, root)
	end

	part({
		Size = Vector3.new(14, 1, 14),
		Position = origin + Vector3.new(0, 3.2, 9),
		Color = PALETTE.gold,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.15,
		CanCollide = false,
	}, root)

	makeZone(Net.Zones.Golden, origin + Vector3.new(0, 4, 10), Vector3.new(16, 1, 16), PALETTE.gold)
	makeSign(origin + Vector3.new(0, 20, -1), "CRIAÇÃO DOURADA", PALETTE.gold, root)
end

---------------------------------------------------------------------------
-- FUSÃO SECRETA
---------------------------------------------------------------------------

function World.buildFusion()
	local origin = Vector3.new(58, 0, 40)

	part({
		Size = Vector3.new(26, 1, 22),
		Position = origin + Vector3.new(0, 1.6, 0),
		Color = PALETTE.purpleDark,
		Material = Enum.Material.Marble,
	}, root)

	-- tubos rosa neon
	for i, offset in ipairs({ Vector3.new(-8, 0, -3), Vector3.new(0, 0, -5), Vector3.new(8, 0, -3) }) do
		local height = i == 2 and 14 or 11
		part({
			Size = Vector3.new(5, height, 5),
			Position = origin + offset + Vector3.new(0, height / 2 + 2, 0),
			Color = PALETTE.pink,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		}, root)

		part({
			Size = Vector3.new(6, 1.2, 6),
			Position = origin + offset + Vector3.new(0, height + 2.4, 0),
			Color = PALETTE.white,
			Material = Enum.Material.SmoothPlastic,
		}, root)
	end

	part({
		Size = Vector3.new(12, 1, 10),
		Position = origin + Vector3.new(0, 3.2, 8),
		Color = PALETTE.pink,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, root)

	makeZone(Net.Zones.Fusion, origin + Vector3.new(0, 4, 9), Vector3.new(16, 1, 16), PALETTE.pink)
	makeSign(origin + Vector3.new(0, 22, -4), "FUSÃO SECRETA", Color3.fromRGB(255, 220, 245), root)
end

---------------------------------------------------------------------------
-- LOJA DE HALLOWEEN
---------------------------------------------------------------------------

function World.buildHalloween()
	local origin = Vector3.new(-100, 0, 92)

	part({
		Size = Vector3.new(30, 1, 22),
		Position = origin + Vector3.new(0, 1.6, 0),
		Color = Color3.fromRGB(255, 140, 60),
		Material = Enum.Material.Neon,
	}, root)

	part({
		Size = Vector3.new(28, 2, 22),
		Position = origin + Vector3.new(0, 16, 0),
		Color = Color3.fromRGB(110, 70, 180),
		Material = Enum.Material.Slate,
	}, root)

	for i = -2, 2 do
		part({
			Size = Vector3.new(3, 14, 3),
			Position = origin + Vector3.new(i * 6, 8, -9),
			Color = PALETTE.woodDark,
			Material = Enum.Material.Wood,
		}, root)
	end

	part({
		Size = Vector3.new(28, 8, 1),
		Position = origin + Vector3.new(0, 10, -9),
		Color = Color3.fromRGB(60, 40, 90),
		Material = Enum.Material.SmoothPlastic,
	}, root)

	ball({
		Size = Vector3.new(5, 5, 5),
		Position = origin + Vector3.new(-6, 12, -8),
		Color = Color3.fromRGB(255, 130, 40),
		Material = Enum.Material.Neon,
	}, root)

	-- zona de compra do ovo de halloween (usa o mesmo fluxo de ovo)
	makeZone("egg_halloween", origin + Vector3.new(0, 4, 7), Vector3.new(18, 1, 14), Color3.fromRGB(255, 150, 60))
	zoneBindings["egg_halloween"].eggId = "halloween"
	makeSign(origin + Vector3.new(0, 22, -9), "LOJA DE HALLOWEEN", Color3.fromRGB(255, 200, 120), root)
end

---------------------------------------------------------------------------
-- PORTAL DE REBIRTH
---------------------------------------------------------------------------

function World.buildRebirthPortal()
	local origin = Vector3.new(0, 0, -72)

	-- escadaria
	for i = 1, 6 do
		part({
			Size = Vector3.new(24, 1.6, 5),
			Position = origin + Vector3.new(0, i * 1.4, 20 - i * 4.4),
			Color = PALETTE.wood,
			Material = Enum.Material.WoodPlanks,
		}, root)
	end

	-- portal
	local frame = part({
		Size = Vector3.new(26, 30, 3),
		Position = origin + Vector3.new(0, 18, -4),
		Color = PALETTE.woodDark,
		Material = Enum.Material.Wood,
	}, root)

	local glow = part({
		Size = Vector3.new(20, 24, 1),
		Position = origin + Vector3.new(0, 18, -2.4),
		Color = Color3.fromRGB(120, 240, 200),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
	}, root)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(130, 255, 210)
	light.Brightness = 4
	light.Range = 40
	light.Parent = glow

	frame:SetAttribute("Portal", true)

	makeZone(Net.Zones.Rebirth, origin + Vector3.new(0, 5, 12), Vector3.new(22, 1, 14), Color3.fromRGB(120, 240, 200))
	makeSign(origin + Vector3.new(0, 38, -4), "RENASCIMENTO", Color3.fromRGB(150, 255, 215), root)
end

---------------------------------------------------------------------------
-- POSTO DE TROCA (placeholder de trade)
---------------------------------------------------------------------------

function World.buildTradePost()
	local origin = Vector3.new(110, 0, 40)

	part({
		Size = Vector3.new(20, 1, 18),
		Position = origin + Vector3.new(0, 1.6, 0),
		Color = PALETTE.pathEdge,
		Material = Enum.Material.Brick,
	}, root)

	part({
		Size = Vector3.new(10, 12, 10),
		Position = origin + Vector3.new(0, 8, 0),
		Color = Color3.fromRGB(255, 120, 90),
		Material = Enum.Material.SmoothPlastic,
	}, root)

	part({
		Size = Vector3.new(12, 2, 12),
		Position = origin + Vector3.new(0, 15, 0),
		Color = PALETTE.white,
		Material = Enum.Material.SmoothPlastic,
	}, root)

	makeZone(Net.Zones.Trade, origin + Vector3.new(0, 4, 9), Vector3.new(16, 1, 12), Color3.fromRGB(255, 150, 120))
	makeSign(origin + Vector3.new(0, 20, 0), "TROCA", Color3.fromRGB(255, 200, 180), root)
end

return World
