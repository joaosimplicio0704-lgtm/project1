-- World
-- Mapa cartoon low-poly construído em código, no estilo dos tycoons de ovo:
-- palco central, ilhas de ovo, lojas, portal de rebirth e a fonte.
-- Nada de asset externo: tudo Instance.new com cores chapadas.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Terrain = require(ReplicatedStorage.Shared.Terrain)

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
	portal = Color3.fromRGB(150, 235, 255),
	portalDark = Color3.fromRGB(70, 150, 200),
	stone = Color3.fromRGB(205, 210, 220),
	stoneDark = Color3.fromRGB(150, 158, 172),
	cosmic = Color3.fromRGB(180, 150, 255),
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
	Lighting.ExposureCompensation = 0.25

	-- O céu não é opcional: sem um Sky o horizonte fica cinza e as ilhas
	-- distantes somem. Nada de asset pago — o Sky padrão do Roblox já serve.
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
		sky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
		sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
		sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
		sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
		sky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
		sky.Parent = Lighting
	end

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
	World.buildBiomes()

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
	-- O hub nao guarda mais os ovos: cada ovo mora no seu bioma. No lugar
	-- fica a arcada de portais, que e o que o jogador ve ao nascer.
	local deck = part({
		Name = "PortalDeck",
		Size = Vector3.new(150, 2, 40),
		Position = Vector3.new(0, 2.2, -44),
		Color = PALETTE.stone,
		Material = Enum.Material.Marble,
	}, root)
	deck.CanCollide = true

	part({
		Name = "PortalDeckTrim",
		Size = Vector3.new(152, 0.6, 42),
		Position = Vector3.new(0, 1.4, -44),
		Color = PALETTE.gold,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, root)

	makeSign(Vector3.new(0, 26, -52), "MUNDOS", Color3.fromRGB(255, 255, 255), root)
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

---------------------------------------------------------------------------
-- BIOMAS
---------------------------------------------------------------------------

-- Toda ilha de bioma e feita dos mesmos ingredientes: base rochosa, praia,
-- relevo em grade, decoracao, portal, pedestal do ovo e area de spawn.
-- O que muda vem de Biomes.List (paleta, relevo, quantidades).

local biomeRoot

local function rgb(triple, transparency)
	local c = Color3.fromRGB(triple[1], triple[2], triple[3])
	return c, transparency
end

-- Portais: dois pilares + arco neon + plataforma de ativacao.
-- `targetBiome == nil` significa "portal de volta pro hub".
local function buildPortal(position, look, targetBiome, parent, name)
	local model = Instance.new("Model")
	model.Name = name or ("Portal_" .. (targetBiome and targetBiome.id or "hub"))
	model.Parent = parent

	local accent = look.accent

	-- base
	part({
		Name = "Base",
		Size = Vector3.new(26, 2.4, 26),
		Position = position + Vector3.new(0, 1.2, 0),
		Color = PALETTE.stone,
		Material = Enum.Material.Marble,
	}, model)

	part({
		Name = "BaseGlow",
		Size = Vector3.new(22, 0.5, 22),
		Position = position + Vector3.new(0, 2.6, 0),
		Color = Color3.fromRGB(accent[1], accent[2], accent[3]),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, model)

	-- pilares
	for side = -1, 1, 2 do
		part({
			Name = "Pillar",
			Size = Vector3.new(4.5, 24, 4.5),
			Position = position + Vector3.new(side * 11, 14, 0),
			Color = PALETTE.stone,
			Material = Enum.Material.Marble,
		}, model)

		part({
			Name = "PillarCap",
			Size = Vector3.new(6.5, 1.6, 6.5),
			Position = position + Vector3.new(side * 11, 26.4, 0),
			Color = Color3.fromRGB(accent[1], accent[2], accent[3]),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, model)
	end

	-- arco
	part({
		Name = "Arch",
		Size = Vector3.new(26.5, 4.2, 4.5),
		Position = position + Vector3.new(0, 26.4, 0),
		Color = PALETTE.stone,
		Material = Enum.Material.Marble,
	}, model)

	part({
		Name = "ArchGlow",
		Size = Vector3.new(24, 0.8, 4.9),
		Position = position + Vector3.new(0, 28.2, 0),
		Color = Color3.fromRGB(accent[1], accent[2], accent[3]),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, model)

	-- veu do portal (nao colide: o jogador atravessa andando)
	local veil = part({
		Name = "Veil",
		Size = Vector3.new(21, 22, 0.6),
		Position = position + Vector3.new(0, 14.4, 0),
		Color = Color3.fromRGB(accent[1], accent[2], accent[3]),
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CanCollide = false,
	}, model)

	local light = Instance.new("PointLight")
	light.Brightness = 2.2
	light.Range = 34
	light.Color = Color3.fromRGB(accent[1], accent[2], accent[3])
	light.Parent = veil

	-- detector de clique para teletransporte
	local detector = Instance.new("ClickDetector")
	detector.Name = "PortalClick"
	detector.MaxActivationDistance = 26
	detector.Parent = veil

	veil:SetAttribute("BiomeId", targetBiome and targetBiome.id or "meadow")
	veil:SetAttribute("Portal", true)

	local zoneName = targetBiome and ("portal_" .. targetBiome.id) or "portal_hub"
	zoneBindings[zoneName] = {
		part = veil,
		detector = detector,
		biomeId = targetBiome and targetBiome.id or nil,
		portal = true,
	}

	-- placa com o nome do destino
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(22, 6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 32, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = veil

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(40, 30, 60)
	label.Text = targetBiome and (targetBiome.emoji .. " " .. targetBiome.name) or "🏠 HUB"
	label.Parent = billboard

	return model
end

-- Pedestal do ovo: base, anel neon e o ovo com pintinhas + placa.
local function buildEggPedestal(egg, position, parent)
	local model = Instance.new("Model")
	model.Name = "EggStand_" .. egg.id
	model.Parent = parent

	part({
		Name = "Pedestal",
		Size = Vector3.new(14, 3.6, 14),
		Position = position + Vector3.new(0, 1.8, 0),
		Color = PALETTE.white,
		Material = Enum.Material.Marble,
	}, model)

	part({
		Name = "PedestalRing",
		Size = Vector3.new(11.5, 1, 11.5),
		Position = position + Vector3.new(0, 3.9, 0),
		Color = PALETTE.gold,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, model)

	local eggPart = ball({
		Name = "Egg_" .. egg.id,
		Size = Vector3.new(9.6, 13.2, 9.6),
		Position = position + Vector3.new(0, 10.6, 0),
		Color = egg.color,
		Material = Enum.Material.SmoothPlastic,
	}, model)

	local rng = Random.new(#egg.id * 977 + 13)
	for i = 1, 9 do
		local theta = rng:NextNumber() * math.pi * 2
		local phi = math.acos(2 * rng:NextNumber() - 1)
		local radius = 4.8
		ball({
			Name = "Spot",
			Size = Vector3.new(1.9, 1.9, 1.9),
			Position = eggPart.Position + Vector3.new(
				math.sin(phi) * math.cos(theta) * radius,
				math.cos(phi) * radius * 1.38,
				math.sin(phi) * math.sin(theta) * radius
			),
			Color = egg.spot,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		}, model)
	end

	-- ovo balanca de leve: o cliente anima pela atributo Spin
	eggPart:SetAttribute("EggId", egg.id)
	eggPart:SetAttribute("Spin", true)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(15, 6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 10, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = eggPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.55)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(70, 55, 90)
	label.Text = egg.name
	label.Parent = billboard

	local price = Instance.new("TextLabel")
	price.Size = UDim2.fromScale(1, 0.4)
	price.Position = UDim2.fromScale(0, 0.58)
	price.BackgroundTransparency = 1
	price.Font = Enum.Font.FredokaOne
	price.TextScaled = true
	price.TextColor3 = PALETTE.gold
	price.TextStrokeTransparency = 0
	price.TextStrokeColor3 = Color3.fromRGB(70, 45, 10)
	price.Text = "🪙 " .. require(ReplicatedStorage.Shared.Format).number(egg.cost)
	price.Parent = billboard

	local detector = Instance.new("ClickDetector")
	detector.Name = "EggClick"
	detector.MaxActivationDistance = 26
	detector.Parent = eggPart

	zoneBindings["egg_" .. egg.id] = { part = eggPart, detector = detector, eggId = egg.id }
	return model
end

-- Decoração por tema, apoiada na altura real do relevo.
local function decorateBiome(biome, cells, home, center)
	local spec = biome.decor
	local accent = biome.colors.accent
	local rng = Random.new(biome.seed or 11)

	local function groundAt(angle, radius)
		local lx = math.cos(angle) * radius
		local lz = math.sin(angle) * radius
		return lx, lz, Terrain.heightAtCell(biome, cells, lx, lz)
	end

	-- anel onde a decoração pode nascer: fora do platô do ovo, dentro da ilha
	local placeable = biome.radius * 0.86
	local innerRing = biome.radius * 0.30

	-- árvores (ou pinheiros / abóboras, conforme o tema)
	for i = 1, spec.trees do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = innerRing + (placeable - innerRing) * rng:NextNumber()
		local x, z, y = groundAt(angle, radius)
		local scale = 0.7 + rng:NextNumber() * 0.8

		if biome.id == "halloween" then
			-- abóbora gigante
			local pos = center + Vector3.new(x, y + 3 * scale, z)
			local pumpkin = ball({
				Name = "Pumpkin",
				Size = Vector3.new(9 * scale, 7 * scale, 9 * scale),
				Position = pos,
				Color = Color3.fromRGB(250, 140, 40),
				Material = Enum.Material.SmoothPlastic,
			}, home)
			ball({
				Name = "PumpkinShade",
				Size = Vector3.new(9.6 * scale, 5 * scale, 9.6 * scale),
				Position = pos,
				Color = Color3.fromRGB(214, 104, 26),
				Material = Enum.Material.SmoothPlastic,
				Transparency = 0.55,
				CanCollide = false,
			}, home)
			part({
				Name = "PumpkinStem",
				Size = Vector3.new(1.6, 3 * scale, 1.6),
				Position = pos + Vector3.new(0, 5 * scale, 0),
				Color = Color3.fromRGB(90, 130, 60),
				Material = Enum.Material.Grass,
			}, home)
		elseif biome.id == "ice" or biome.id == "forest" then
			-- pinheiro: tronco + 3 cones empilhados
			local pos = center + Vector3.new(x, y, z)
			local trunkColor = biome.id == "ice" and Color3.fromRGB(150, 140, 150) or Color3.fromRGB(110, 80, 55)
			local leafColor = biome.id == "ice" and Color3.fromRGB(226, 244, 255) or Color3.fromRGB(52, 140, 88)
			part({
				Name = "Trunk",
				Size = Vector3.new(2.6 * scale, 9 * scale, 2.6 * scale),
				Position = pos + Vector3.new(0, 4.5 * scale, 0),
				Color = trunkColor,
				Material = Enum.Material.Wood,
			}, home)
			for tier = 1, 3 do
				local w = (8.5 - tier * 1.7) * scale
				part({
					Name = "Leaf",
					Size = Vector3.new(w, 5.2 * scale, w),
					Position = pos + Vector3.new(0, (7 + tier * 3.4) * scale, 0),
					Color = leafColor,
					Material = Enum.Material.Grass,
				}, home)
			end
		else
			tree(center + Vector3.new(x, y, z), scale, home)
		end
	end

	-- pedras
	for i = 1, spec.rocks do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = innerRing + (placeable - innerRing) * rng:NextNumber()
		local x, z, y = groundAt(angle, radius)
		local scale = 0.8 + rng:NextNumber() * 1.4
		ball({
			Name = "Rock",
			Size = Vector3.new(5 * scale, 4 * scale, 5.5 * scale),
			Position = center + Vector3.new(x, y + 1.2 * scale, z),
			Color = Color3.fromRGB(biome.colors.rock[1], biome.colors.rock[2], biome.colors.rock[3]),
			Material = Enum.Material.Slate,
		}, home)
	end

	-- flores (só bioma de grama)
	for i = 1, spec.flowers do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = innerRing + (placeable - innerRing) * rng:NextNumber()
		local x, z, y = groundAt(angle, radius)
		flower(center + Vector3.new(x, y, z), home)
	end

	-- cristais brilhantes (gelo, sombrio, cosmos, deserto)
	for i = 1, spec.crystals do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = innerRing + (placeable - innerRing) * rng:NextNumber()
		local x, z, y = groundAt(angle, radius)
		local height = 4 + rng:NextNumber() * 9
		local crystal = part({
			Name = "Crystal",
			Size = Vector3.new(2.4, height, 2.4),
			Position = center + Vector3.new(x, y + height / 2, z),
			Color = Color3.fromRGB(accent[1], accent[2], accent[3]),
			Material = Enum.Material.Neon,
		}, home)
		crystal.CFrame = CFrame.new(crystal.Position) * CFrame.Angles(0.18, rng:NextNumber() * 6.28, -0.14)
	end
end

-- Constroi um bioma inteiro e devolve as referências que o servidor precisa.
function World.buildBiome(biome, portalPosition, parent)
	local home = Instance.new("Model")
	home.Name = "Biome_" .. biome.id
	home.Parent = parent

	local center = Biomes.centerVector(biome)
	local colors = biome.colors

	-- plataforma de rocha flutuante (o "casco" da ilha)
	part({
		Name = "Base",
		Size = Vector3.new(biome.radius * 2.3, 26, biome.radius * 2.3),
		Position = center + Vector3.new(0, -26, 0),
		Color = Color3.fromRGB(colors.rock[1], colors.rock[2], colors.rock[3]),
		Material = Enum.Material.Slate,
	}, home)

	part({
		Name = "BaseUnder",
		Size = Vector3.new(biome.radius * 1.75, 30, biome.radius * 1.75),
		Position = center + Vector3.new(0, -52, 0),
		Color = Color3.fromRGB(colors.rock[1] - 40, colors.rock[2] - 40, colors.rock[3] - 40),
		Material = Enum.Material.Slate,
		CanCollide = false,
	}, home)

	-- borda de praia circular
	part({
		Name = "Beach",
		Size = Vector3.new(biome.radius * 2.12, 3, biome.radius * 2.12),
		Position = center + Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(colors.sand[1], colors.sand[2], colors.sand[3]),
		Material = Enum.Material.Sand,
	}, home)

	-- relevo em grade
	local cells = Terrain.generate(biome)
	local cellModel = Instance.new("Model")
	cellModel.Name = "Terrain"
	cellModel.Parent = home

	for _, cell in ipairs(cells) do
		local cellPart = part({
			Name = cell.top and "CellTop" or "CellFill",
			Size = Vector3.new(cell.sx, cell.sy, cell.sz),
			Position = center + Vector3.new(cell.x, cell.y, cell.z),
			Color = Color3.fromRGB(cell.color[1], cell.color[2], cell.color[3]),
			Material = cell.kind == "sand" and Enum.Material.Sand or Enum.Material.Grass,
			CanCollide = true,
		}, cellModel)
		cellPart.TopSurface = Enum.SurfaceType.Smooth
	end

	decorateBiome(biome, cells, home, center)

	-- pedestal do ovo no miolo plano. A altura vem da célula central, não de
	-- uma constante: se o relevo mudar, o ovo acompanha e não afunda.
	local groundY = Terrain.heightAtCell(biome, cells, 0, 0)
	local egg = GameConfig.EggById[biome.eggId]
	local eggSpot = Vector3.new(center.X, center.Y + groundY, center.Z)
	if egg then
		buildEggPedestal(egg, eggSpot, home)
	end

	-- portal de volta para o hub
	local spawn = Biomes.spawnPoint(biome)
	local portal = buildPortal(portalPosition, {
		accent = colors.accent,
	}, nil, home, "Portal_Return")

	-- placa do bioma
	makeSign(Vector3.new(center.X, center.Y + groundY + 34, center.Z), biome.name, Color3.fromRGB(255, 255, 255), home)

	-- area de chegada: plataforma discreta onde o jogador aparece
	part({
		Name = "ArrivalPad",
		Size = Vector3.new(30, 1, 30),
		Position = Vector3.new(spawn.X, center.Y + groundY + 0.6, spawn.Z),
		Color = Color3.fromRGB(colors.accent[1], colors.accent[2], colors.accent[3]),
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
	}, home)

	return {
		biome = biome,
		model = home,
		center = center,
		eggSpot = eggSpot,
		spawn = spawn,
		portal = portal,
	}
end

-- Portais do hub: um por bioma, no anel externo da praça, alinhados com a
-- direção real da ilha. Assim o jogador vê para onde o portal leva.
local biomeRefs = {}

function World.buildBiomes()
	biomeRoot = Instance.new("Folder")
	biomeRoot.Name = "Biomes"
	biomeRoot.Parent = root

	for _, biome in ipairs(Biomes.List) do
		local center = Biomes.centerVector(biome)

		-- direção no plano entre o hub e a ilha
		local flat = Vector3.new(center.X, 0, center.Z)
		if flat.Magnitude < 1 then
			flat = Vector3.new(0, 0, -1) -- cosmos fica no alto (centro do hub)
		end

		-- portal do hub
		local portalPosition = Vector3.new(0, 0, 0)
		if flat.Magnitude > 1 then
			portalPosition = flat.Unit * 70
		end
		buildPortal(portalPosition, { accent = biome.colors.accent }, biome, root, "PortalTo_" .. biome.id)

		-- Portal de volta: na encosta, virado para o hub. A altura vem do
		-- próprio relevo — o portal fica em cima do chão, não afundado na base.
		local direction = flat.Magnitude < 1 and Vector3.new(0, 0, 1) or flat.Unit
		local portalRadius = biome.radius * 0.66
		local portalX = center.X + direction.X * portalRadius
		local portalZ = center.Z + direction.Z * portalRadius
		local cells = Terrain.generate(biome)
		local localX = portalX - center.X
		local localZ = portalZ - center.Z
		local backPosition =
			Vector3.new(portalX, center.Y + Terrain.heightAtCell(biome, cells, localX, localZ), portalZ)

		biomeRefs[biome.id] = World.buildBiome(biome, backPosition, biomeRoot)
	end
end

function World.getBiomeRefs()
	return biomeRefs
end

function World.biomeArrival(biomeId)
	local ref = biomeRefs[biomeId]
	if not ref then
		return nil
	end
	return CFrame.new(ref.spawn)
		* CFrame.Angles(0, math.atan2(ref.center.X - ref.spawn.X, ref.center.Z - ref.spawn.Z), 0)
end

function World.centerOf(biomeId)
	local ref = biomeRefs[biomeId]
	return ref and ref.center or nil
end

return World
