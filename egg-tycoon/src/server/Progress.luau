-- Progress.luau — XP, nível e renda offline.
--
-- Um lugar só para a pergunta "o jogador ganhou alguma coisa e subiu de
-- nível?". Se cada ação fizesse a conta por conta própria (bater, chocar
-- ovo, minerar), uma delas esqueceria de chamar o level-up e o jogador
-- ficaria travado sem ninguém notar.
--
-- XP de PET mora aqui também, mas em campo separado: são duas progressões
-- independentes e misturar as duas foi como perder o controle de balanceamento.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Combat)

local Progress = {}

-- Quanto os pets somam, no máximo, em fração do acerto do jogador. 0.75:
-- dá para sentir o pet batendo, mas o clique do jogador continua sendo a
-- maior parte do dano em qualquer nível.
Progress.PetMaxShare = 0.75

-- Fontes de XP do jogador. Dar XP por ação é o que faz o jogo ter ritmo:
-- toda coisa que o jogador faz empurra ele um pouco para frente.
Progress.Sources = {
	kill = 1.0, -- matar monstro (o XP vem do monstro)
	tap = 0, -- o toque não dá XP direto: ele dá moeda
	hatch = 60, -- chocar ovo
	mine = 45, -- recolher minério
	upgrade = 25, -- comprar melhoria
	rebirth = 900, -- renascer
}

-- Garante os campos no save. Saves antigos não têm "level": sem isto o
-- jogador que já jogava antes perde tudo ou quebra na primeira soma.
function Progress.ensure(data)
	data.level = math.max(1, tonumber(data.level) or 1)
	data.xp = math.max(0, tonumber(data.xp) or 0)
	data.levelUps = tonumber(data.levelUps) or 0
	return data
end

-- Soma XP e aplica o level-up. Devolve { gained, level, xp, leveled, levels }.
function Progress.addXp(data, amount, source)
	Progress.ensure(data)
	amount = math.max(0, math.floor(amount or 0))
	if amount <= 0 then
		return { gained = 0, level = data.level, xp = data.xp, leveled = false, levels = 0 }
	end

	local oldLevel = data.level
	data.level, data.xp, levels = Combat.addXp(data.level, amount, data.xp)
	data.levelUps = (data.levelUps or 0) + levels

	if source and data.stats then
		data.stats.xpFrom = data.stats.xpFrom or {}
		data.stats.xpFrom[source] = (data.stats.xpFrom[source] or 0) + amount
	end

	return {
		gained = amount,
		level = data.level,
		xp = data.xp,
		leveled = data.level > oldLevel,
		levels = levels,
	}
end

-- XP por fonte nomeada (chocar ovo, minerar...). Sem nível, sem XP: fonte
-- desconhecida devolve 0 em vez de explodir.
function Progress.awardSource(data, source)
	local amount = Progress.Sources[source] or 0
	if amount <= 0 then
		return nil
	end
	return Progress.addXp(data, amount, source)
end

-- Quanto falta para o próximo nível, para a barra da UI.
function Progress.toNext(data)
	Progress.ensure(data)
	return Combat.xpToNext(data.level) - data.xp
end

-- Campos que o cliente precisa para desenhar a barra de XP.
function Progress.snapshot(data)
	Progress.ensure(data)
	return {
		level = data.level,
		xp = data.xp,
		xpToNext = Combat.xpToNext(data.level),
		bonus = Combat.levelBonus(data.level),
	}
end

---------------------------------------------------------------------------
-- XP DE PET
---------------------------------------------------------------------------

-- Todo pet tem `level` e `xp` no save. O campo `level` já existia e NADA
-- usava — era um número morto. Agora significa alguma coisa.
function Progress.ensurePet(instance)
	instance.level = math.max(1, tonumber(instance.level) or 1)
	instance.xp = math.max(0, tonumber(instance.xp) or 0)
	return instance
end

-- Experiência que o pet ganha por participar (bater, achar minério, ficar
-- perto do jogador enquanto ele batalha). Chamar para todos os equipados.
function Progress.addPetXp(instance, amount)
	Progress.ensurePet(instance)
	amount = math.max(0, math.floor(amount or 0))
	if amount <= 0 then
		return nil
	end
	local oldLevel = instance.level
	-- ATENÇÃO: `Combat.addXp` usa a curva do JOGADOR. O pet tem curva
	-- própria (`petXpToNext`), então a conta é feita aqui. Chamar addXp
	-- fazia o pet precisar de XP de jogador e nunca subir nível.
	local newLevel, newXp, levels = instance.level, instance.xp + amount, 0
	while newXp >= Combat.petXpToNext(newLevel) do
		newXp = newXp - Combat.petXpToNext(newLevel)
		newLevel = newLevel + 1
		levels = levels + 1
		if levels > 500 then
			break
		end
	end
	instance.level = newLevel
	instance.xp = newXp
	return {
		uid = instance.uid,
		level = instance.level,
		xp = instance.xp,
		xpToNext = Combat.petXpToNext(instance.level),
		levels = levels,
		leveled = instance.level > oldLevel,
	}
end

-- Dano que os pets equipados somam a cada acerto do jogador.
--
-- O TETO É O PONTO CENTRAL: o pet nunca passa de 75% do acerto do jogador.
-- Sem teto, um exército de 8 pets secretos nível 60 batia 200 por acerto
-- enquanto o jogador nível 1 batia 6 — o pet virava o protagonista e o
-- jogador virava espectador da própria luta. Com o teto relativo, o pet
-- ajuda sempre na mesma proporção, em qualquer nível: o jogador nunca
-- perde a sensação de que é ele quem está batendo.
--
-- `playerHit` é o dano do acerto do jogador ANTES dos pets.
function Progress.petDamage(data, playerHit)
	local equipped = data.equipped or {}
	local breakdown = {}
	if #equipped == 0 then
		return 0, breakdown
	end

	local raw = {}
	local sum = 0
	for _, uid in ipairs(equipped) do
		for _, instance in ipairs(data.pets or {}) do
			if instance.uid == uid then
				local damage = Combat.petDamage(instance.rarity or "common", instance.level or 1)
				if damage > 0 then
					raw[#raw + 1] = { uid = instance.uid, damage = damage }
					sum = sum + damage
				end
				break
			end
		end
	end
	if sum <= 0 then
		return 0, breakdown
	end

	-- retorno decrescente: o primeiro pet vale quase tudo, o oitavo quase nada
	local strongest = 0
	for _, entry in ipairs(raw) do
		if entry.damage > strongest then
			strongest = entry.damage
		end
	end
	local effective = strongest + (sum - strongest) * 0.15

	-- 25% de um acerto por pet efetivo, com teto de 75% no conjunto
	local cap = math.floor(math.max(0, playerHit or 0) * Progress.PetMaxShare)
	local total = math.min(math.floor(effective * 0.25), cap)
	if total < 1 then
		return 0, breakdown
	end

	-- reparte o total proporcionalmente, para a UI mostrar quem bateu
	local left = total
	for index, entry in ipairs(raw) do
		local share
		if index == #raw then
			share = left
		else
			share = math.floor(total * (entry.damage / sum))
		end
		if share > 0 then
			breakdown[#breakdown + 1] = { uid = entry.uid, damage = share }
		end
		left = left - share
	end
	return total, breakdown
end

-- XP que o pet ganha ao matar um monstro, dividido entre os equipados.
-- Dividir é de propósito: 8 pets não podem render 8x mais que 1. O jogador
-- escolhe QUAL pet evoluir evoluindo um só, não equipando oito.
function Progress.awardPetKill(data, killXp)
	local equipped = data.equipped or {}
	local count = 0
	for _, uid in ipairs(equipped) do
		if data.pets then
			for _, instance in ipairs(data.pets) do
				if instance.uid == uid then
					count = count + 1
					break
				end
			end
		end
	end
	if count == 0 then
		return {}
	end
	local each = math.max(1, math.floor((killXp or 0) * 0.5 / count))
	local results = {}
	for _, uid in ipairs(equipped) do
		for _, instance in ipairs(data.pets or {}) do
			if instance.uid == uid then
				local r = Progress.addPetXp(instance, each)
				if r then
					results[#results + 1] = r
				end
				break
			end
		end
	end
	return results
end

return Progress
