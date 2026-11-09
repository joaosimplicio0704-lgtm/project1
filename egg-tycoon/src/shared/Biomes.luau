-- Biomes
-- Os 7 mundos do jogo. Cada um tem paleta, relevo, ovo próprio e uma regra
-- de desbloqueio. Fica em Shared porque cliente (painel de mundos) e servidor
-- (construção do mapa, viagem) leem a MESMA tabela — nada de duplicar dado.

local Biomes = {}

Biomes.HubRadius = 96
-- Arquipélago compacto: as 6 ilhas cabem num disco de ~430 studs. Longe o
-- bastante para cada uma ter horizonte próprio, perto o bastante para caberem
-- juntas na tela. Anel de 760 deixava o hub perdido num oceano vazio.
Biomes.RingDistance = 380
Biomes.IslandRadius = 105
Biomes.SkyHeight = 300

-- kind: "free" nunca bloqueia | "hatched" precisa ter chovido N ovos
--       | "rebirths" precisa de N renascimentos
Biomes.List = {
	{
		id = "meadow",
		name = "Vale Verdejante",
		emoji = "🌷",
		eggId = "starter",
		unlock = { kind = "free", value = 0 },
		blurb = "Onde todo mundo começa. Grama macia e flores.",
		theme = "meadow",
		center = { x = 380, y = 0, z = 0 },
		radius = 105,
		colors = {
			grass = { 122, 222, 96 },
			grassDark = { 84, 192, 78 },
			rock = { 178, 196, 214 },
			sand = { 240, 226, 190 },
			accent = { 255, 150, 190 },
			water = { 96, 210, 236 },
		},
		light = {
			ambience = { 255, 246, 214 },
			glow = { 255, 236, 180 },
			intensity = 1.5,
			range = 260,
			sky = { 168, 214, 255 },
			haze = 0.15,
		},
		height = { base = 3, amp = 9, scale = 0.055, ridged = false, detail = 4 },
		decor = { trees = 26, rocks = 14, flowers = 44, crystals = 0 },
	},
	{
		id = "forest",
		name = "Floresta Densa",
		emoji = "🌲",
		eggId = "green",
		unlock = { kind = "hatched", value = 3 },
		blurb = "Árvores gigantes e cogumelos que brilham.",
		theme = "forest",
		center = { x = 190, y = 0, z = 329 },
		radius = 105,
		colors = {
			grass = { 66, 182, 92 },
			grassDark = { 40, 142, 74 },
			rock = { 152, 174, 158 },
			sand = { 214, 206, 168 },
			accent = { 130, 235, 150 },
			water = { 72, 176, 168 },
		},
		light = {
			ambience = { 196, 236, 188 },
			glow = { 168, 255, 160 },
			intensity = 1.2,
			range = 250,
			sky = { 130, 186, 150 },
			haze = 0.32,
		},
		height = { base = 4, amp = 22, scale = 0.05, ridged = false, detail = 5 },
		decor = { trees = 54, rocks = 16, flowers = 20, crystals = 0 },
	},
	{
		id = "desert",
		name = "Deserto Dourado",
		emoji = "🏜️",
		eggId = "golden",
		unlock = { kind = "rebirths", value = 1 },
		blurb = "Dunas, obeliscos e ruínas soterradas.",
		theme = "desert",
		center = { x = -190, y = 0, z = 329 },
		radius = 105,
		colors = {
			grass = { 248, 214, 136 },
			grassDark = { 232, 184, 104 },
			rock = { 224, 176, 118 },
			sand = { 246, 226, 176 },
			accent = { 255, 196, 90 },
			water = { 120, 220, 232 },
		},
		light = {
			ambience = { 255, 232, 186 },
			glow = { 255, 200, 110 },
			intensity = 1.8,
			range = 270,
			sky = { 255, 214, 160 },
			haze = 0.22,
		},
		height = { base = 2, amp = 14, scale = 0.04, ridged = false, detail = 4 },
		decor = { trees = 6, rocks = 12, flowers = 0, crystals = 8 },
	},
	{
		id = "ice",
		name = "Picos Congelados",
		emoji = "❄️",
		eggId = "ice",
		unlock = { kind = "rebirths", value = 2 },
		blurb = "Montanhas de gelo e pinheiros nevados.",
		theme = "ice",
		center = { x = -380, y = 0, z = 0 },
		radius = 105,
		colors = {
			grass = { 232, 246, 255 },
			grassDark = { 196, 226, 248 },
			rock = { 158, 186, 210 },
			sand = { 240, 248, 255 },
			accent = { 140, 220, 255 },
			water = { 156, 224, 246 },
		},
		light = {
			ambience = { 208, 236, 255 },
			glow = { 170, 224, 255 },
			intensity = 1.5,
			range = 260,
			sky = { 150, 196, 240 },
			haze = 0.18,
		},
		height = { base = 5, amp = 46, scale = 0.045, ridged = true, detail = 6 },
		decor = { trees = 30, rocks = 18, flowers = 0, crystals = 14 },
	},
	{
		id = "shadow",
		name = "Vale Sombrio",
		emoji = "🌑",
		eggId = "shadow",
		unlock = { kind = "rebirths", value = 3 },
		blurb = "Pedra escura, névoa roxa e obeliscos.",
		theme = "shadow",
		center = { x = -190, y = 0, z = -329 },
		radius = 105,
		colors = {
			grass = { 96, 86, 130 },
			grassDark = { 66, 58, 98 },
			rock = { 76, 72, 96 },
			sand = { 120, 110, 150 },
			accent = { 178, 120, 245 },
			water = { 90, 80, 140 },
		},
		light = {
			ambience = { 130, 116, 178 },
			glow = { 178, 120, 255 },
			intensity = 1.3,
			range = 240,
			sky = { 66, 58, 104 },
			haze = 0.42,
		},
		height = { base = 3, amp = 30, scale = 0.055, ridged = true, detail = 5 },
		decor = { trees = 18, rocks = 22, flowers = 0, crystals = 20 },
	},
	{
		id = "halloween",
		name = "Ilha Abóbora",
		emoji = "🎃",
		eggId = "halloween",
		unlock = { kind = "rebirths", value = 4 },
		blurb = "Abóboras gigantes, névoa laranja e fantasmas.",
		theme = "halloween",
		center = { x = 190, y = 0, z = -329 },
		radius = 105,
		colors = {
			grass = { 152, 176, 96 },
			grassDark = { 108, 132, 66 },
			rock = { 128, 116, 106 },
			sand = { 196, 168, 120 },
			accent = { 255, 140, 50 },
			water = { 110, 150, 120 },
		},
		light = {
			ambience = { 255, 206, 150 },
			glow = { 255, 140, 50 },
			intensity = 1.6,
			range = 250,
			sky = { 120, 92, 130 },
			haze = 0.35,
		},
		height = { base = 3, amp = 20, scale = 0.05, ridged = false, detail = 4 },
		decor = { trees = 14, rocks = 14, flowers = 0, crystals = 10 },
	},
	{
		id = "cosmos",
		name = "Nebulosa Cósmica",
		emoji = "🌌",
		eggId = "visits",
		unlock = { kind = "rebirths", value = 5 },
		blurb = "Ilha flutuante entre estrelas. O ovo dos 30M.",
		theme = "cosmos",
		-- 262 ficava alto demais: no mapa inteiro o cosmos aparecia como
		-- lixo verde no céu, e não dava pra ler como ilha. 118 é alto o
		-- bastante para ser "a ilha flutuante" e baixo o bastante para o
		-- jogador continuar vendo o arquipélago ao redor.
		center = { x = 0, y = 118, z = 0 },
		radius = 82,
		colors = {
			-- Cosmos tinha quase o mesmo roxo de shadow: no mapa as duas
			-- ilhas ficavam iguais. Violeta puxado para azul estelar.
			grass = { 96, 82, 190 },
			grassDark = { 62, 52, 140 },
			rock = { 96, 92, 150 },
			sand = { 140, 130, 210 },
			accent = { 190, 150, 255 },
			water = { 70, 60, 140 },
		},
		light = {
			ambience = { 178, 160, 255 },
			glow = { 190, 150, 255 },
			intensity = 1.9,
			range = 220,
			sky = { 34, 24, 62 },
			haze = 0.10,
		},
		height = { base = 2, amp = 12, scale = 0.06, ridged = false, detail = 4 },
		decor = { trees = 8, rocks = 10, flowers = 0, crystals = 26 },
	},
}

Biomes.ById = {}
for _, biome in ipairs(Biomes.List) do
	Biomes.ById[biome.id] = biome
end

function Biomes.get(id)
	return Biomes.ById[id] or Biomes.List[1]
end

function Biomes.unlockedMap(stats)
	stats = stats or {}
	local out = {}
	for _, biome in ipairs(Biomes.List) do
		local unlock = biome.unlock
		if unlock.kind == "free" then
			out[biome.id] = true
		elseif unlock.kind == "hatched" then
			out[biome.id] = (stats.hatched or 0) >= unlock.value
		else
			out[biome.id] = (stats.rebirths or 0) >= unlock.value
		end
	end
	return out
end

function Biomes.forEgg(eggId)
	for _, biome in ipairs(Biomes.List) do
		if biome.eggId == eggId then
			return biome
		end
	end
	return nil
end

function Biomes.at(index)
	return Biomes.List[index]
end

-- Ponto central em studs (Vector3). Usa .x/.y/.z da tabela pura.
function Biomes.centerVector(biome)
	return Vector3.new(biome.center.x, biome.center.y, biome.center.z)
end

-- Onde o jogador aparece ao chegar no bioma: na frente do portal de retorno,
-- virado para o ovo.
function Biomes.spawnPoint(biome)
	local center = Biomes.centerVector(biome)
	local hub = Vector3.new(0, 0, 0)
	local flat = Vector3.new(center.X, 0, center.Z)
	local direction = flat - Vector3.new(hub.X, 0, hub.Z)
	if direction.Magnitude < 0.01 then
		direction = Vector3.new(0, 0, 1)
	end
	direction = direction.Unit
	return center + direction * (biome.radius * 0.42) + Vector3.new(0, 8, 0)
end

-- Texto do cadeado mostrado no painel.
function Biomes.unlockLabel(biome)
	local unlock = biome.unlock
	if unlock.kind == "free" then
		return "Livre"
	elseif unlock.kind == "hatched" then
		return string.format("Chocar %d ovos", unlock.value)
	else
		return string.format("Renascimento %d", unlock.value)
	end
end

return Biomes
