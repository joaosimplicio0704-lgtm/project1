-- Effects
-- Feedback visível NO MUNDO para cada ação do jogador.
--
-- O problema que isto resolve: a mecânica sempre existiu (clicar, chocar ovo,
-- equipar pet, subir de nível, rebirth), mas ela só acontecia no servidor e
-- aparecia em painel de números. Quem olhava o mapa — ou um print dele — não
-- via jogo nenhum acontecendo. Aqui cada ação deixa rastro no espaço:
--
--   tap      -> moeda dourada sobe e some, anel de choque no chão
--   chocar   -> ovo racha, explosão de cor, pet nasce e é lançado pro alto
--   equipar  -> o pet fica orbitando o jogador
--   upgrade  -> letreiro "NÍVEL 2!" subindo
--   rebirth  -> anel gigante atravessa o mapa, tela inteira sente
--
-- Tudo é feito de Part/Neon e TweenService: nada de asset externo.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Effects = {}

local folder

function Effects.init(parent)
	folder = Instance.new("Folder")
	folder.Name = "Effects"
	folder.Parent = parent or workspace
end

local function newPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = folder
	return p
end

local function tween(part, info, goal)
	local t = TweenService:Create(part, info, goal)
	t:Play()
	return t
end

---------------------------------------------------------------------------
-- PEQUENOS
---------------------------------------------------------------------------

-- Moeda que sobe e some. Uma por clique, com vida de 0.8s.
function Effects.coinBurst(position, color, count)
	count = count or 1
	color = color or Color3.fromRGB(255, 205, 60)
	for i = 1, count do
		local coin = newPart({
			Name = "CoinPop",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 2.6, 2.6),
			Position = position + Vector3.new((math.random() - 0.5) * 5, math.random() * 2, (math.random() - 0.5) * 5),
			Color = color,
		})
		coin.CFrame = CFrame.new(coin.Position) * CFrame.Angles(0, 0, math.pi / 2)
		local dx = (math.random() - 0.5) * 6
		local dz = (math.random() - 0.5) * 6
		tween(coin, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = coin.Position + Vector3.new(dx, 14, dz),
			Transparency = 1,
			Size = Vector3.new(0.3, 0.4, 0.4),
		})
		Debris:AddItem(coin, 0.9)
	end
end

-- Anel de choque no chão: o "tum" de cada clique.
function Effects.shockwave(position, color, radius, lifetime)
	radius = radius or 12
	lifetime = lifetime or 0.45
	local ring = newPart({
		Name = "ShockRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 2, 2),
		Position = position + Vector3.new(0, 0.4, 0),
		Color = color or Color3.fromRGB(255, 255, 255),
		Transparency = 0.15,
	})
	ring.CFrame = CFrame.new(ring.Position) * CFrame.Angles(0, 0, math.pi / 2)
	tween(ring, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.6, radius * 2, radius * 2),
		Transparency = 1,
	})
	Debris:AddItem(ring, lifetime + 0.05)
end

-- Explosão de partículas de cor: nascimento de pet, level up, rebirth.
function Effects.burst(position, color, count, speed, size)
	count = count or 16
	speed = speed or 26
	size = size or 2.4
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random() * 0.4
		local lift = 0.35 + math.random() * 0.9
		local dir = Vector3.new(math.cos(angle), lift, math.sin(angle))
		local p = newPart({
			Name = "Burst",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size) * (0.6 + math.random() * 0.7),
			Position = position,
			Color = color,
			Transparency = 0.05,
		})
		tween(p, TweenInfo.new(0.7 + math.random() * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = position + dir * (speed * (4 + math.random() * 4)),
			Transparency = 1,
			Size = p.Size * 0.2,
		})
		Debris:AddItem(p, 1.1)
	end
end

-- Texto flutuante no mundo (não é GUI, é parte 3D: aparece em print e de longe).
function Effects.floatText(position, text, color, height)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(260, 90)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(40, 20, 60)
	label.Text = text
	label.Parent = billboard

	local anchor = newPart({
		Name = "FloatAnchor",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Position = position,
		Transparency = 1,
	})
	anchor.Material = Enum.Material.SmoothPlastic
	anchor.CanCollide = false
	billboard.Parent = anchor

	tween(billboard, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, height or 16, 0),
	})
	tween(label, TweenInfo.new(1.1), { TextTransparency = 1, TextStrokeTransparency = 1 })
	Debris:AddItem(anchor, 1.2)
end

---------------------------------------------------------------------------
-- GRANDES
---------------------------------------------------------------------------

-- Chocar ovo: o ovo racha em pedaços, um clarão sai de dentro e o pet sobe.
function Effects.hatchBurst(position, rarityColor, isSecret)
	local power = isSecret and 2.2 or 1
	Effects.burst(position, rarityColor, math.floor(20 * power), 22 * power, 2.8 * power)
	Effects.shockwave(position, rarityColor, 26 * power, 0.7)

	local flash = newPart({
		Name = "HatchFlash",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(8, 8, 8),
		Position = position,
		Color = rarityColor,
		Transparency = 0.1,
	})
	tween(flash, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.new(34, 34, 34),
		Transparency = 1,
	})
	Debris:AddItem(flash, 0.5)

	-- cascas voando
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local shell = newPart({
			Name = "EggShell",
			Size = Vector3.new(2.6, 0.7, 3.4),
			Position = position,
			Color = Color3.fromRGB(250, 244, 232),
		})
		shell.Material = Enum.Material.SmoothPlastic
		tween(shell, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = position + Vector3.new(math.cos(angle) * 18, 10 + math.random() * 8, math.sin(angle) * 18),
			Rotation = shell.Rotation + Vector3.new(math.random() * 200, math.random() * 200, 0),
			Transparency = 1,
		})
		Debris:AddItem(shell, 0.9)
	end

	if isSecret then
		-- arco de luz para o secreto: sobe 60 studs
		local beam = newPart({
			Name = "SecretBeam",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(70, 5, 5),
			Position = position + Vector3.new(0, 34, 0),
			Color = rarityColor,
			Transparency = 0.15,
		})
		beam.CFrame = CFrame.new(beam.Position)
		tween(beam, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(80, 22, 22),
			Transparency = 1,
		})
		Debris:AddItem(beam, 1.5)
	end
end

-- Rebirth: um anel que cruza o mapa inteiro, visível de qualquer ilha.
function Effects.rebirthWave(position)
	for i = 0, 2 do
		task.delay(i * 0.18, function()
			local ring = newPart({
				Name = "RebirthWave",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.5, 8, 8),
				Position = position + Vector3.new(0, 1, 0),
				Color = Color3.fromRGB(255, 215, 90),
				Transparency = 0.1,
			})
			ring.CFrame = CFrame.new(ring.Position) * CFrame.Angles(0, 0, math.pi / 2)
			tween(ring, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(1.5, 900, 900),
				Transparency = 1,
			})
			Debris:AddItem(ring, 1.9)
		end)
	end
	Effects.burst(position + Vector3.new(0, 6, 0), Color3.fromRGB(255, 220, 120), 40, 40, 4)
end

---------------------------------------------------------------------------
-- PET ORBITANDO
---------------------------------------------------------------------------

-- Cada jogador com pet equipado ganha uma cópia 3D do pet girando em volta.
-- Sem isso, "equipar" só muda um número no painel: não há nada no mapa.
local orbits = {}

function Effects.setOrbit(player, petsTable)
	local previous = orbits[player]
	if previous then
		previous.model:Destroy()
		orbits[player] = nil
	end
	if not petsTable or #petsTable == 0 then
		return
	end

	local model = Instance.new("Model")
	model.Name = "PetOrbit_" .. player.Name
	model.Parent = folder

	local orbit = {
		model = model,
		pets = petsTable,
		angle = 0,
		parts = {},
	}
	orbits[player] = orbit
end

-- Chamado pelo loop do servidor: faz os pets girarem em volta do jogador.
function Effects.step(dt)
	for player, orbit in pairs(orbits) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end
		orbit.angle += dt * 1.1
		local count = math.max(1, #orbit.pets)
		for index, pet in ipairs(orbit.pets) do
			local slot = orbit.parts[index]
			if not slot then
				slot = Instance.new("Part")
				slot.Name = "OrbitPet"
				slot.Shape = Enum.PartType.Ball
				slot.Size = Vector3.new(5, 5, 5)
				slot.Anchored = true
				slot.CanCollide = false
				slot.CanQuery = false
				slot.CanTouch = false
				slot.CastShadow = false
				slot.Material = Enum.Material.SmoothPlastic
				slot.Color = pet.color or Color3.fromRGB(255, 255, 255)
				slot.Parent = orbit.model
				-- bolinha de olho, para ler como bichinho e não como bola
				local eye = Instance.new("Part")
				eye.Name = "Eye"
				eye.Shape = Enum.PartType.Ball
				eye.Size = Vector3.new(1.1, 1.1, 1.1)
				eye.Anchored = true
				eye.CanCollide = false
				eye.CanQuery = false
				eye.CastShadow = false
				eye.Color = Color3.fromRGB(30, 24, 40)
				eye.Parent = orbit.model
				slot:SetAttribute("EyeRef", eye.Name)
				orbit.parts[index] = slot
				orbit.parts["eye" .. index] = eye
			end
			local angle = orbit.angle + (index / count) * math.pi * 2
			local radius = 9 + count * 1.4
			local pos = root.Position
				+ Vector3.new(
					math.cos(angle) * radius,
					6 + math.sin(orbit.angle * 2 + index) * 1.6,
					math.sin(angle) * radius
				)
			slot.CFrame = CFrame.new(pos)
			local eye = orbit.parts["eye" .. index]
			if eye then
				eye.CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 1.9))
			end
		end
	end
end

function Effects.removePlayer(player)
	local orbit = orbits[player]
	if orbit then
		orbit.model:Destroy()
		orbits[player] = nil
	end
end

return Effects
