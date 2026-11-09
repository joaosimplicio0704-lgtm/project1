-- Combat.luau — vida, dano, XP e nível.
--
-- O jogo não tinha combate. Isto aqui é o núcleo: um monstro tem vida, o
-- jogador (ou o pet) bate, o monstro morre e dá XP. Vida do JOGADOR existe
-- pelo mesmo motivo que a de qualquer jogo: sem risco, bater não tem peso.
--
-- Regras de projeto (o que faz valer a pena):
--
-- 1. XP de JOGADOR vem de tudo que é ação de verdade: bater, matar, chocar
--    ovo, achar minério. Subir de nível dá bônus PERMANENTE, então jogar
--    mais tempo sempre vale a pena — e é isso que segura o jogador.
--
-- 2. XP de PET é separado. O pet sobe de nível trabalhando, e cada nível
--    aumenta o DANO dele. Pet que não batalha não evolui, então o jogador
--    tem motivo para colocar o pet na briga em vez de só olhar.
--
-- 3. Vida do jogador regenera fora de combate. Morrer não pode punir com
--    perda de pet ou de moeda: aqui o jogador é criança, punição dura
--    ensina a não jogar. Morrer = voltar ao spawn e perder alguns segundos.
--
-- Tudo aqui é função pura com números explícitos, para o teste poder rodar
-- mil combates sem abrir o Roblox.

local Combat = {}

---------------------------------------------------------------------------
-- CURVAS
---------------------------------------------------------------------------

-- XP necessário para ir do nível `level` para o seguinte.
-- Cresce de forma suave: nível 2 custa 100, nível 10 custa ~1.5k, nível 30
-- custa ~13k. Um jogador ativo sobe o começo rápido (é o que dá o gostinho)
-- e desacelera depois, em vez de travar.
function Combat.xpToNext(level)
	level = math.max(1, math.floor(level or 1))
	return math.floor(60 * level ^ 1.55 + 40 * level)
end

-- Bônus permanente por nível: +6% de dano e +4% de renda por nível acima do 1.
-- Linear de propósito: se fosse exponencial, quem começou ontem nunca
-- alcançaria quem começou semana passada, e o jogo morre.
function Combat.levelBonus(level)
	level = math.max(1, math.floor(level or 1))
	return {
		damage = 1 + 0.06 * (level - 1),
		income = 1 + 0.04 * (level - 1),
	}
end

-- XP de pet: mais barato que o do jogador, porque são vários pets e cada um
-- precisa mostrar progresso visível rápido.
function Combat.petXpToNext(level)
	level = math.max(1, math.floor(level or 1))
	return math.floor(40 * level ^ 1.4 + 25 * level)
end

-- Dano do pet: base pela raridade, multiplicado pelo nível dele.
-- Pet raro bate mais forte E sobe mais forte: as duas coisas juntas.
Combat.PetBaseDamage = {
	common = 4,
	uncommon = 6,
	rare = 10,
	epic = 16,
	legendary = 26,
	secret = 42,
}

function Combat.petDamage(rarity, level)
	local base = Combat.PetBaseDamage[rarity] or Combat.PetBaseDamage.common
	level = math.max(1, math.floor(level or 1))
	-- +18% por nível do pet: mais agressivo que o nível do jogador, porque o
	-- pet é o que o jogador escolhe evoluir.
	return base * (1 + 0.18 * (level - 1))
end

-- Dano do jogador (o toque).
--
-- O `tapPower` NÃO entra direto aqui. Ele já é multiplicado por 1 a cada
-- upgrade e chega a dezenas — se o dano seguisse ele, no nível 20 qualquer
-- monstro morreria com um clique e o combate viraria enfeite. Por isso a
-- parte vinda do upgrade é comprimida por raiz: o upgrade continua valendo
-- (dobrar o toque aumenta o combate, só que devagar), mas quem carrega o
-- combate é o NÍVEL, que é o número que o jogador vê subir.
function Combat.playerDamage(level, tapPower)
	local bonus = Combat.levelBonus(level).damage
	local upgrades = math.sqrt(math.max(0, (tapPower or 1) - 1))
	return (Combat.BaseHit + 2 * upgrades) * bonus
end

---------------------------------------------------------------------------
-- VIDA
---------------------------------------------------------------------------

Combat.PlayerMaxHealth = 100

-- Regeneração fora de combate.
-- `secondsSinceHit` conta desde o último dano recebido: enquanto o jogador
-- está apanhando não regenera, senão vida não significa nada.
function Combat.PlayerRegenPerSecond()
	return 6
end

Combat.RegenDelay = 4

-- Vida por nível: +8 por nível. Assim subir de nível também te deixa mais
-- resistente, não só mais forte.
function Combat.playerMaxHealth(level)
	return Combat.PlayerMaxHealth + 8 * math.max(0, (level or 1) - 1)
end

-- Aplica regeneração. Devolve a vida nova.
function Combat.regenerate(health, maxHealth, secondsSinceHit, dt)
	if secondsSinceHit < Combat.RegenDelay then
		return health
	end
	local rate = Combat.PlayerRegenPerSecond()
	return math.min(maxHealth, health + rate * dt)
end

---------------------------------------------------------------------------
-- MONSTROS
---------------------------------------------------------------------------

-- Um monstro por "campo" de ilha. `tier` decide vida, dano e XP.
-- O tier acompanha o bioma: o prado tem monstro fraco (o jogador aprende),
-- o cosmos tem monstro forte.
-- Dano base de um acerto no nível 1, sem upgrade nenhum. 6 dá ~7 acertos
-- na gosma: devagar o bastante para o clique ter peso, rápido o bastante
-- para ninguém largar o jogo no tutorial.
Combat.BaseHit = 6

Combat.MonsterTiers = {
	{ id = "slime", name = "Gosma", health = 40, damage = 5, xp = 18, coins = 60, tier = 1 },
	{ id = "bat", name = "Morcego", health = 90, damage = 9, xp = 42, coins = 180, tier = 2 },
	{ id = "golem", name = "Golem", health = 220, damage = 15, xp = 95, coins = 520, tier = 3 },
	{ id = "wraith", name = "Espectro", health = 480, damage = 24, xp = 210, coins = 1400, tier = 4 },
	{ id = "titan", name = "Titã", health = 1100, damage = 38, xp = 480, coins = 3800, tier = 5 },
}

Combat.monsterById = {}
for _, monster in ipairs(Combat.MonsterTiers) do
	Combat.monsterById[monster.id] = monster
end

-- Qual monstro mora em qual bioma. O prado é o tutorial: monstro fraco.
Combat.BiomeMonster = {
	meadow = "slime",
	forest = "bat",
	desert = "golem",
	ice = "wraith",
	shadow = "wraith",
	halloween = "golem",
	cosmos = "titan",
}

-- Vida do monstro escala com o nível do JOGADOR, para o combate nunca ficar
-- trivial (se fosse fixa, o jogador nível 30 mataria com um toque e a
-- mecânica inteira viraria clique sem graça).
function Combat.monsterMaxHealth(monsterId, playerLevel)
	local monster = Combat.monsterById[monsterId]
	if not monster then
		return 100
	end
	-- 0.10 < os 6% de dano + 4% de renda do levelBonus composto: o monstro
	-- fica mais forte, mas o jogador fica mais forte um pouco mais rápido.
	local scale = 1 + 0.10 * math.max(0, (playerLevel or 1) - 1)
	return math.floor(monster.health * scale)
end

-- XP que o monstro dá ao morrer (escala junto com a vida).
function Combat.monsterReward(monsterId, playerLevel)
	local monster = Combat.monsterById[monsterId]
	if not monster then
		return { xp = 0, coins = 0 }
	end
	local scale = 1 + 0.16 * math.max(0, (playerLevel or 1) - 1)
	return {
		xp = math.floor(monster.xp * scale),
		coins = math.floor(monster.coins * scale),
	}
end

-- Aplica dano. Devolve vida nova e se morreu.
function Combat.applyDamage(health, damage)
	local newHealth = math.max(0, health - math.max(0, damage))
	return newHealth, newHealth <= 0
end

---------------------------------------------------------------------------
-- XP / NÍVEL
---------------------------------------------------------------------------

-- Soma XP e devolve quantos níveis subiu. Aceita XP maior que um nível
-- inteiro e continua subindo (matar um titã no nível 1 pode dar 2 níveis).
function Combat.addXp(level, xp, xpIntoLevel)
	level = math.max(1, math.floor(level or 1))
	xpIntoLevel = math.max(0, xpIntoLevel or 0) + math.max(0, xp or 0)
	local levelsGained = 0
	while xpIntoLevel >= Combat.xpToNext(level) do
		xpIntoLevel = xpIntoLevel - Combat.xpToNext(level)
		level = level + 1
		levelsGained = levelsGained + 1
		-- trava de segurança: se a curva estiver errada, não roda para sempre
		if levelsGained > 500 then
			break
		end
	end
	return level, xpIntoLevel, levelsGained
end

---------------------------------------------------------------------------
-- RENDA OFFLINE
-- Padrão tirado de jogos reais (o LvAH guarda LastOnline e credita o tempo
-- fora). Aqui o teto é o que impede o jogo de quebrar: 8 horas.
---------------------------------------------------------------------------

Combat.OfflineMaxHours = 8
-- Fração da renda normal enquanto offline. Menos que online, senão ninguém
-- entra no jogo: só sairia e voltaria no outro dia.
Combat.OfflineRate = 0.35

-- `secondsAway` é quanto tempo passou. `incomePerSecond` é a renda do
-- jogador no momento em que ele saiu.
function Combat.offlineReward(secondsAway, incomePerSecond)
	secondsAway = math.max(0, secondsAway or 0)
	local cappedSeconds = math.min(secondsAway, Combat.OfflineMaxHours * 3600)
	-- +0.5 antes do floor: 0.35 * 3600 * 100 dá 125999.99999999999 em ponto
	-- flutuante, e truncar cru custaria 1 moeda inteira de cada vez.
	local coins = math.floor((incomePerSecond or 0) * cappedSeconds * Combat.OfflineRate + 0.5)
	return {
		coins = coins,
		seconds = cappedSeconds,
		capped = secondsAway > Combat.OfflineMaxHours * 3600,
	}
end

return Combat
