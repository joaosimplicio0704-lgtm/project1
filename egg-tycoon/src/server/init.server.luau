-- init.server
-- Bootstrap do servidor: mundo -> remotes -> sessoes -> loop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Net = require(Shared.Net)
local Combat = require(Shared.Combat)
local Pets = require(Shared.Pets)

local World = require(script.World)
local Remotes = require(script.Remotes)
local PlayerData = require(script.PlayerData)
local Sessions = require(script.Sessions)
local Game = require(script.Game)
local Effects = require(script.Effects)
local Progress = require(script.Progress)
local Monsters = require(script.Monsters)

World.build()
Effects.init(workspace)

-- Viagem entre biomas: o Game decide SE pode ir, o init.server faz o teleporte.
Game.arrivalFor = function(session, biomeId)
	local character = session.player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local cframe = World.biomeArrival(biomeId)
	if cframe then
		root.CFrame = cframe
	end
end

-- ---------------------------------------------------------------------------
-- FEEDBACK NO MUNDO
-- Cada ação do jogador tem que deixar marca no espaço. Sem isso a mecânica
-- só mexe em número de painel: quem entra no jogo (ou vê um print) não vê
-- nada acontecendo. Onde o efeito nasce: no pé do personagem.
-- ---------------------------------------------------------------------------
local function feetPosition(session)
	local character = session.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	return root.Position - Vector3.new(0, 2.6, 0)
end

-- Cor por raridade vem da PROPRIA config (GameConfig.Rarities), em vez de uma
-- tabela duplicada aqui: duplicar garante divergir quando alguem ajustar a
-- paleta, e o efeito sai com a cor errada.
local function rarityColor(rarityId)
	local rarity = GameConfig.RarityById and GameConfig.RarityById[rarityId]
	if rarity and rarity.color then
		return rarity.color
	end
	return Color3.fromRGB(210, 215, 225)
end

Game.fx.tap = function(session, gained)
	local pos = feetPosition(session)
	if not pos then
		return
	end
	-- uma moeda por clique: o jogador vê o dinheiro sair do chão
	Effects.coinBurst(pos + Vector3.new(0, 2, 0), Color3.fromRGB(255, 205, 60), 1)
	Effects.shockwave(pos, Color3.fromRGB(255, 235, 150), 9, 0.4)
end

Game.fx.hatch = function(session, pet, instance)
	local pos = feetPosition(session)
	if not pos then
		return
	end
	local rarity = pet.rarity or "common"
	local color = rarityColor(rarity)
	Effects.hatchBurst(pos + Vector3.new(0, 4, 0), color, rarity == "secret")
	Effects.floatText(pos + Vector3.new(0, 8, 0), pet.name or "Pet", color, 26)
end

Game.fx.equip = function(session)
	local data = session.data
	local equipped = {}
	-- o campo da instancia e petId (nao id): comparar pet.id dava nil e o
	-- pet orbitando nunca aparecia
	for _, uid in ipairs(data.equipped or {}) do
		for _, pet in ipairs(data.pets or {}) do
			if pet.uid == uid then
				local config = GameConfig.pet(pet.petId)
				equipped[#equipped + 1] = {
					color = rarityColor(config and config.rarity or "common"),
					name = config and config.name or "Pet",
				}
			end
		end
	end
	Effects.setOrbit(session.player, equipped)
end

Game.fx.upgrade = function(session, kind, level)
	local pos = feetPosition(session)
	if not pos then
		return
	end
	-- nomes reais em GameConfig.defaultData().upgrades: tap / slots / mult
	local labels = {
		tap = "FORÇA",
		slots = "ESPAÇO DO PET",
		mult = "MULTIPLICADOR",
	}
	Effects.floatText(
		pos + Vector3.new(0, 9, 0),
		string.format("%s NÍVEL %d", labels[kind] or string.upper(kind), level),
		Color3.fromRGB(140, 255, 180),
		20
	)
	Effects.burst(pos + Vector3.new(0, 3, 0), Color3.fromRGB(140, 255, 180), 12, 16, 1.8)
end

-- MINA: o pet volta com o minério na mão. Sem efeito, a mecânica só mexe
-- número no painel e quem está olhando o mundo não vê nada acontecer.
Game.fx.mine = function(session, ore)
	local character = session.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not ore then
		return
	end
	local color = Color3.fromRGB(ore.color[1], ore.color[2], ore.color[3])
	local at = root.Position + Vector3.new(0, 3, 0)
	Effects.burst(at, color, 26, 20, 3.2)
	Effects.shockwave(at, color, 18, 0.55)
end

-- COMBATE: bater precisa deixar rastro. Sem isso o jogador clica no monstro
-- e não acontece nada visível — foi exatamente a queixa da rodada 3.
Game.fx.hit = function(session, result, killed)
	local character = session.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local at = root.Position + Vector3.new(0, 4, 0)
	local color = killed and Color3.fromRGB(255, 210, 90) or Color3.fromRGB(255, 120, 120)
	Effects.burst(at, color, killed and 30 or 10, killed and 26 or 14, killed and 3.4 or 2.0)
	if killed then
		Effects.shockwave(at, color, 22, 0.6)
	end
end

-- Subir de nível: anel grande, cor de ouro. É o momento mais importante do
-- jogo — tem que ser visível de longe.
Game.fx.levelUp = function(session, level)
	local character = session.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local at = root.Position + Vector3.new(0, 3, 0)
	local gold = Color3.fromRGB(255, 214, 90)
	Effects.shockwave(at, gold, 34, 1.0)
	Effects.burst(at + Vector3.new(0, 6, 0), gold, 40, 30, 3.6)
	remotes.event:FireClient(session.player, Net.EventKind.LevelUp, { level = level })
end

Game.fx.hurt = function(session)
	local character = session.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	Effects.burst(root.Position + Vector3.new(0, 4, 0), Color3.fromRGB(200, 60, 60), 14, 16, 2.4)
end

Game.fx.offline = function() end

Game.fx.rebirth = function(session, rebirths)
	local pos = feetPosition(session)
	if not pos then
		return
	end
	Effects.rebirthWave(pos)
	Effects.floatText(
		pos + Vector3.new(0, 14, 0),
		string.format("REBIRTH %d!", rebirths),
		Color3.fromRGB(255, 225, 110),
		40
	)
end

local remotes = Remotes.setup()
Game.init(remotes)
PlayerData.start()
Game.start()

---------------------------------------------------------------------------
-- SESSAO
---------------------------------------------------------------------------

local function startSession(player)
	local data = PlayerData.load(player.UserId)
	local session = {
		player = player,
		data = data,
		dirty = false,
		tapWindow = {},
		lastSnapshot = 0,
		pendingToast = nil,
	}
	Sessions.byPlayer[player] = session

	-- RENDA OFFLINE
	-- Guarda o horário de saída e credita o tempo fora ao voltar. É o que
	-- faz o jogador abrir o jogo de novo no dia seguinte em vez de esquecer
	-- que existe. Teto de 8h para não quebrar a economia.
	Progress.ensure(data)
	if (data.lastOnline or 0) > 0 then
		local secondsAway = os.time() - data.lastOnline
		if secondsAway > 60 then
			local incomePerSecond = Pets.income(data) * Combat.levelBonus(data.level).income
			local reward = Combat.offlineReward(secondsAway, incomePerSecond)
			if reward.coins > 0 then
				data.coins = data.coins + reward.coins
				data.stats.coinsEarned = (data.stats.coinsEarned or 0) + reward.coins
				session.pendingOffline = reward
			end
		end
	end
	data.lastOnline = os.time()

	-- auto-equipa o melhor em slot livre ao entrar
	Pets.autoEquip(data)

	local character = player.Character or player.CharacterAdded:Wait()
	local root = character and character:WaitForChild("HumanoidRootPart", 10)
	if root and World.spawnCFrame then
		root.CFrame = World.spawnCFrame()
	end
end

local function endSession(player)
	local session = Sessions.get(player)
	if not session then
		return
	end
	-- marca a saída ANTES de soltar o save: a renda offline do próximo
	-- login é contada a partir daqui
	if session.data then
		session.data.lastOnline = os.time()
		PlayerData.markDirty(player.UserId)
	end
	Sessions.byPlayer[player] = nil
	PlayerData.release(player.UserId)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and World.spawnCFrame then
			task.wait(0.2)
			root.CFrame = World.spawnCFrame()
		end
	end)
	task.spawn(startSession, player)
end)

-- pets orbitando: anda junto com o personagem, então precisa de tick próprio
task.spawn(function()
	while true do
		local dt = task.wait(0.05)
		Effects.step(dt)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Effects.removePlayer(player)
	endSession(player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(startSession, player)
end

---------------------------------------------------------------------------
-- ACOES
---------------------------------------------------------------------------

local A = Net.ActionKind

-- ClickDetector dos portais: o jogador clica na placa e viaja.
local zoneBindings = World.getZoneBindings()
for name, binding in pairs(zoneBindings) do
	if binding.portal and binding.detector then
		local targetBiome = name == "portal_hub" and "meadow" or name:gsub("^portal_", "")
		binding.detector.MouseClick:Connect(function(player)
			local session = Sessions.get(player)
			if not session then
				return
			end
			local ok, err = Game.handlers.travel(session, targetBiome)
			if ok then
				Game.pushSnapshot(session)
			elseif err then
				remotes.event:FireClient(player, Net.EventKind.Toast, { text = err, kind = "error" })
			end
		end)
	end
end

-- CLIQUE NO MONSTRO: bate. Cada ilha tem o seu ClickDetector.
-- O dano é calculado no servidor (Game.handlers.hit), então clicar mil vezes
-- por segundo não vira dano infinito: o limite é o tick.
for biomeId, binding in pairs(World.getMonsterBindings()) do
	if binding.detector then
		binding.detector.MouseClick:Connect(function(player)
			local session = Sessions.get(player)
			if not session then
				return
			end
			Game.handlers.hit(session, nil)
		end)
	end
end

remotes.action.OnServerEvent:Connect(function(player, kind, payload)
	local session = Sessions.get(player)
	if not session then
		return
	end

	local ok, err = Game.handle(session, kind, payload)
	if not ok and err then
		remotes.event:FireClient(player, Net.EventKind.Toast, { text = err, kind = "error" })
	end
end)

print(string.format("[EggTycoon] Servidor pronto · %d pets · %d ovos", #GameConfig.Pets, #GameConfig.Eggs))
