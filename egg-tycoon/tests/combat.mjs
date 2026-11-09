// combat.mjs — vida, dano, XP, nível e renda offline.
//
// O que este teste protege:
//
// 1. NÍVEL TEM QUE SIGNIFICAR ALGO. Se a curva de XP estiver errada, subir
//    de nível fica impossível (jogo trava) ou trivial (jogo acaba). Aqui a
//    curva é medida: quantos acertos para subir do 1 ao 2? E do 30 ao 31?
//
// 2. MONSTRO TEM QUE ESCALAR. Vida fixa = jogador nível 30 mata em um toque
//    e o combate inteiro vira clique sem graça. Vida infinita = novato não
//    mata nunca. O teste exige que o tempo de matar fique numa faixa.
//
// 3. XP NÃO PODE VAZAR. addXp tem que somar exatamente o que entrou, nível
//    a nível, sem perder nem duplicar XP na virada.
//
// 4. RENDA OFFLINE TEM TETO. Sem teto, sair uma semana quebra a economia
//    do jogo — e o dono do jogo não descobre até alguém explorar.
//
// Uso: node tests/combat.mjs

import { Lua } from "@luau-rs/luau";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");

const problems = [];
const check = (condition, message) => {
	if (!condition) problems.push(message);
};

const HOST = String.raw`
__clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
`;

const combatSrc = read("src/shared/Combat.luau")
	.replace(/^return Combat\s*$/m, "")
	.replace(/math\.clamp\(/g, "__clamp(");

const lua = await Lua.create({ sandbox: true });

const script = String.raw`
${HOST}
${combatSrc}

__out = {}

-- 1. custo de XP por nivel: nao pode ser zero, nem constante
__out.costs = {}
for lv = 1, 40 do
  __out.costs[lv] = Combat.xpToNext(lv)
end

-- 2. quantos acertos para ir do nivel 1 ao 2 (matando gosma)
local dps = Combat.playerDamage(1, 1)
local slime = Combat.monsterMaxHealth("slime", 1)
__out.hitsToKillNv1 = math.ceil(slime / dps)
local reward = Combat.monsterReward("slime", 1)
__out.killsToLevel2 = math.ceil(Combat.xpToNext(1) / reward.xp)

-- 3. no nivel 30, o slime (escalado) ainda leva mais de um toque?
local dps30 = Combat.playerDamage(30, 1)
local slime30 = Combat.monsterMaxHealth("slime", 30)
__out.hitsToKillNv30 = math.ceil(slime30 / dps30)
-- e o tita no nivel 30?
local titan30 = Combat.monsterMaxHealth("titan", 30)
__out.hitsToKillTitanNv30 = math.ceil(titan30 / dps30)

-- 4. XP nao vaza na virada de nivel
local lv, xp, gained = Combat.addXp(1, Combat.xpToNext(1), 0)
__out.exactLevel2 = lv
__out.exactXpLeft = xp
local lv2, xp2, gained2 = Combat.addXp(1, Combat.xpToNext(1) + 7, 0)
__out.overflowLevel = lv2
__out.overflowXp = xp2

-- 5. muito XP de uma vez sobe varios niveis sem loop infinito
local lvBig, xpBig, gainedBig = Combat.addXp(1, 10000000, 0)
__out.bigLevel = lvBig
__out.bigGained = gainedBig

-- 6. XP negativo nao desce nivel
local lvNeg = Combat.addXp(5, -500, 100)
__out.negLevel = lvNeg

-- 7. dano: vida nao fica negativa
local h, dead = Combat.applyDamage(10, 50)
__out.deadHealth = h
__out.deadFlag = dead
local h2, dead2 = Combat.applyDamage(10, 4)
__out.aliveHealth = h2
__out.aliveFlag = dead2

-- 8. pet: nivel aumenta dano, raridade aumenta dano
__out.petCommon1 = Combat.petDamage("common", 1)
__out.petCommon10 = Combat.petDamage("common", 10)
__out.petSecret1 = Combat.petDamage("secret", 1)

-- 9. bonus de nivel cresce e comeca em 1
local b1 = Combat.levelBonus(1)
local b10 = Combat.levelBonus(10)
__out.bonus1 = b1.damage
__out.bonus10 = b10.damage
__out.income10 = b10.income

-- 10. renda offline: teto de 8h
local r1h = Combat.offlineReward(3600, 100)
local r9h = Combat.offlineReward(9 * 3600, 100)
local rWeek = Combat.offlineReward(7 * 24 * 3600, 100)
__out.offline1h = r1h.coins
__out.offlineCapped = r9h.capped
__out.offlineWeek = rWeek.coins
__out.offlineWeekCapped = rWeek.capped
-- offline nunca pode render mais que o online no mesmo tempo
__out.offlineLessThanOnline = r1h.coins < 100 * 3600

-- 11. regeneracao so fora de combate
local regenCombat = Combat.regenerate(50, 100, 1, 1)
local regenIdle = Combat.regenerate(50, 100, 10, 1)
__out.regenInCombat = regenCombat
__out.regenIdle = regenIdle
-- nao passa do maximo
__out.regenCap = Combat.regenerate(99, 100, 10, 10)

-- 12. vida por nivel cresce
__out.hp1 = Combat.playerMaxHealth(1)
__out.hp10 = Combat.playerMaxHealth(10)

-- 13. monstro de cada bioma existe
__out.biomesSemMonstro = 0
local biomes = { "meadow", "forest", "desert", "ice", "shadow", "halloween", "cosmos" }
for _, b in ipairs(biomes) do
  if not Combat.BiomeMonster[b] then __out.biomesSemMonstro = __out.biomesSemMonstro + 1 end
end
return "ok"
`;

try {
	lua.execute(script);
} catch (error) {
	console.error("combat FALHOU ao carregar:", String(error).slice(0, 400));
	process.exit(1);
}

const out = (name) => {
	const v = lua.globals.get("__out").get(name);
	if (v == null) return v;
	if (typeof v === "number" || typeof v === "boolean") return v;
	return Number(String(v));
};

// 1. curva de XP: cresce e nunca é zero
const costs = lua.globals.get("__out").get("costs");
const costList = [];
for (let i = 1; i <= 40; i++) costList.push(Number(String(costs.get(i))));
check(costList[0] > 0, `custo do nível 1 é ${costList[0]}`);
for (let i = 1; i < costList.length; i++) {
	if (!(costList[i] > costList[i - 1])) {
		problems.push(`custo de XP não cresce: nível ${i}=${costList[i - 1]} -> ${i + 1}=${costList[i]}`);
		break;
	}
}
// nível 1 -> 2 tem que ser alcançável em poucos minutos (é o tutorial)
check(costList[0] <= 400, `custo para o nível 2 é ${costList[0]} XP (alto demais para o começo)`);
// nível 40 não pode ser absurdo a ponto de não existir
check(costList[39] < 5000000, `custo do nível 40 é ${costList[39]} (absurdo)`);

// 2. matar no nível 1 é rápido
const hitsNv1 = out("hitsToKillNv1");
check(hitsNv1 >= 2 && hitsNv1 <= 15, `matar um gosma no nível 1 leva ${hitsNv1} acertos (faixa 2-15)`);
const killsToLv2 = out("killsToLevel2");
check(killsToLv2 >= 3 && killsToLv2 <= 30, `subir para o nível 2 exige ${killsToLv2} gosmas (faixa 3-30)`);

// 3. escalonamento: no nível 30 o monstro NÃO morre em um toque
const hitsNv30 = out("hitsToKillNv30");
check(hitsNv30 >= 2, `no nível 30 um gosma morre em ${hitsNv30} acerto(s) — combate virou nada`);
const titanNv30 = out("hitsToKillTitanNv30");
check(titanNv30 >= 5 && titanNv30 <= 400, `titã no nível 30 leva ${titanNv30} acertos (faixa 5-400)`);

// 4. XP não vaza
check(out("exactLevel2") === 2, `XP exato do nível não virou nível 2 (ficou ${out("exactLevel2")})`);
check(out("exactXpLeft") === 0, `sobrou ${out("exactXpLeft")} de XP na virada (deveria ser 0)`);
check(out("overflowLevel") === 2 && out("overflowXp") === 7, `excesso de XP não sobrou: nível ${out("overflowLevel")} xp ${out("overflowXp")}`);

// 5. XP gigante não trava
check(out("bigGained") > 0 && out("bigGained") <= 500, `XP gigante subiu ${out("bigGained")} níveis (trava em 500)`);

// 6. XP negativo não desce nível
check(out("negLevel") === 5, `XP negativo mexeu no nível: ${out("negLevel")}`);

// 7. vida
check(out("deadHealth") === 0, `vida ficou ${out("deadHealth")} ao morrer (deveria ser 0)`);
check(out("deadFlag") === true, "morrer não sinalizou morte");
check(out("aliveHealth") === 6 && out("aliveFlag") === false, `dano normal errado: ${out("aliveHealth")} vida`);

// 8. pet
check(out("petCommon10") > out("petCommon1") * 2, `nível 10 do pet não aumenta o dano: ${out("petCommon1")} -> ${out("petCommon10")}`);
check(out("petSecret1") > out("petCommon1") * 3, `pet secreto não bate mais forte: ${out("petSecret1")} vs ${out("petCommon1")}`);

// 9. bônus
check(Math.abs(out("bonus1") - 1) < 0.001, `bônus do nível 1 é ${out("bonus1")} (deveria ser 1)`);
check(out("bonus10") > out("bonus1"), "bônus de dano não cresce com o nível");
check(out("income10") > 1, "bônus de renda não cresce com o nível");

// 10. offline
check(out("offline1h") > 0, "renda offline de 1 hora é zero");
check(out("offlineCapped") === true, "9 horas não marcou como limitada");
check(out("offlineWeek") === out("offline1h") * 8, `teto de 8h não aplicou: semana=${out("offlineWeek")} vs 8x=${out("offline1h") * 8}`);
check(out("offlineWeekCapped") === true, "uma semana não marcou como limitada");
check(out("offlineLessThanOnline") === true, "renda offline não é menor que a online (ninguém entraria no jogo)");

// 11. regeneração
check(out("regenInCombat") === 50, `regenerou durante o combate (${out("regenInCombat")})`);
check(out("regenIdle") > 50, "não regenerou fora de combate");
check(out("regenCap") === 100, `regeneração passou do máximo: ${out("regenCap")}`);

// 12. vida por nível
check(out("hp10") > out("hp1"), "vida máxima não cresce com o nível");
check(out("hp1") === 100, `vida base é ${out("hp1")} (deveria ser 100)`);

// 13. todo bioma tem monstro
check(out("biomesSemMonstro") === 0, `${out("biomesSemMonstro")} biomas ficaram sem monstro`);

if (problems.length > 0) {
	console.error("combat FALHOU:");
	for (const p of problems) console.error("  - " + p);
	process.exit(1);
}
console.log(
	`combat ok — mata em ${hitsNv1} acertos, nível 2 em ${killsToLv2} gosmas, titã nv30 em ${titanNv30} acertos, offline com teto de 8h`,
);
