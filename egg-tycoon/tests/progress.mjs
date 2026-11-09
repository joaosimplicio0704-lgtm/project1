// progress.mjs — Progress.luau rodando contra um save de verdade.
//
// O Combat puro já está coberto em combat.mjs. Aqui o alvo é a CAMADA que
// escreve no save do jogador, onde os erros custam caro:
//
// 1. Save antigo (sem level/xp) não pode quebrar. Quem já jogava antes
//    continua jogando; se `ensure` falhar, o jogo não abre para ninguém.
//
// 2. XP de cada fonte tem que valer o que promete. Se chocar ovo não der
//    XP, o jogador não vê motivo para chocar.
//
// 3. Pet não pode evoluir de graça nem deixar de evoluir. O dano do pet
//    tem que subir com o nível — é a única razão para evoluir o pet.
//
// 4. 8 pets equipados não podem render 8x o XP de 1 pet.
//
// Uso: node tests/progress.mjs

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

const combatSrc = read("src/shared/Combat.luau")
	.replace(/^return Combat\s*$/m, "")
	.replace(/math\.clamp\(/g, "__clamp(");

const progressSrc = read("src/server/Progress.luau")
	.replace(/^local ReplicatedStorage = game:GetService\("ReplicatedStorage"\)$/m, "")
	.replace(/^local Combat = require\(ReplicatedStorage\.Shared\.Combat\)$/m, "")
	.replace(/^return Progress\s*$/m, "");

const lua = await Lua.create({ sandbox: true });

const script = String.raw`
__clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local ReplicatedStorage = { Shared = {} }
${combatSrc}
${progressSrc}

__out = {}

-- 1. save antigo: só moedas, sem level/xp
local old = { coins = 0 }
Progress.ensure(old)
__out.oldLevel = old.level
__out.oldXp = old.xp
__out.oldLevelUps = old.levelUps

-- save corrompido: string e negativo
local bad = { level = "abc", xp = -50 }
Progress.ensure(bad)
__out.badLevel = bad.level
__out.badXp = bad.xp

-- save com level 0 e levelUps negativo (ja aconteceu em save corrompido)
local zero = { level = 0, xp = 0, levelUps = -3 }
Progress.ensure(zero)
__out.zeroLevel = zero.level
__out.zeroLevelUps = zero.levelUps

-- 2. XP por fonte
__out.hatchXp = Progress.Sources.hatch
__out.mineXp = Progress.Sources.mine
__out.rebirthXp = Progress.Sources.rebirth
__out.tapXp = Progress.Sources.tap
__out.unknownXp = Progress.awardSource({ coins = 0 }, "naoExiste")

local d = { coins = 0, level = 1, xp = 0, stats = {} }
local before = d.xp
Progress.awardSource(d, "hatch")
__out.hatchGained = d.xp - before
__out.statsHatch = d.stats.xpFrom.hatch

-- 3. level up pelo Progress, nao pelo Combat direto
local d2 = { coins = 0, level = 1, xp = 0, stats = {} }
local info = Progress.addXp(d2, 999999, "kill")
__out.infoLevel = info.level
__out.infoLeveled = info.leveled
__out.infoLevels = d2.levelUps
__out.infoLevelValue = d2.level
__out.toNextPositive = Progress.toNext(d2) > 0
__out.snapLevel = Progress.snapshot(d2).level
__out.snapToNext = Progress.snapshot(d2).xpToNext

-- 4. pet: nasce no nivel 1, sobe com XP
local pet = { uid = "p1", rarity = "rare", level = 0, xp = 0 }
Progress.ensurePet(pet)
__out.petLevelStart = pet.level
local petUp = Progress.addPetXp(pet, Combat.petXpToNext(1))
__out.petLevelAfter = pet.level
__out.petLeveled = petUp.leveled
__out.petXpLeft = pet.xp

-- dano do pet sobe com o nivel. Medido no mesmo jogador (nv1), senao o
-- teto relativo esconde a diferenca: comparar pet nv1 e nv10 com o jogador
-- tambem subindo confunde nivel do pet com nivel do jogador.
local data1 = { pets = { { uid = "a", rarity = "rare", level = 1 } }, equipped = { "a" } }
local data10 = { pets = { { uid = "a", rarity = "rare", level = 10 } }, equipped = { "a" } }
local dmg1 = Progress.petDamage(data1, 100)
local dmg10 = Progress.petDamage(data10, 100)
__out.petDmg1 = dmg1
__out.petDmg10 = dmg10

-- 5. 8 pets nao rendem 8x
local many = { pets = {}, equipped = {} }
for i = 1, 8 do
  local uid = "u" .. i
  many.pets[i] = { uid = uid, rarity = "common", level = 1, xp = 0 }
  many.equipped[i] = uid
end
local one = { pets = { { uid = "u1", rarity = "common", level = 1, xp = 0 } }, equipped = { "u1" } }
Progress.awardPetKill(one, 100)
Progress.awardPetKill(many, 100)
__out.onePetXp = one.pets[1].xp
__out.manyPetXp = many.pets[1].xp
__out.eightPetsDmg = Progress.petDamage(many, Combat.playerDamage(10, 1))

-- 6. pet sem equipar nao da dano
local none = { pets = { { uid = "z", rarity = "secret", level = 50 } }, equipped = {} }
__out.noPetDmg = Progress.petDamage(none, 10)

-- 7. pet que nao existe no save (uid fantasma) nao explode
local ghost = { pets = {}, equipped = { "sumiu" } }
__out.ghostDmg = Progress.petDamage(ghost, 10)
__out.ghostRewards = #Progress.awardPetKill(ghost, 100)

-- 9. o pet NAO pode substituir o jogador. Com 8 pets secretos nivel 60 o
-- dano somado tem que continuar MENOR que um acerto do jogador no nivel 1.
-- Sem este assert, subir o multiplicador do pet em Progress.petDamage
-- deixava o jogador parado olhando o pet jogar — e nenhum teste reclamava.
local army = { pets = {}, equipped = {} }
for i = 1, 8 do
  local uid = "s" .. i
  army.pets[i] = { uid = uid, rarity = "secret", level = 60 }
  army.equipped[i] = uid
end
__out.armyDmg = Progress.petDamage(army, Combat.playerDamage(1, 1))

-- retorno decrescente medido com o MESMO jogador: 8 pets comuns nivel 1
-- contra 1 pet comum nivel 1. Se 8 valerem perto de 8x, equipar mais pet
-- virou a unica estrategia e a escolha de qual pet evoluir morre.
local solo = { pets = { { uid = "a", rarity = "common", level = 1 } }, equipped = { "a" } }
local team = { pets = {}, equipped = {} }
for i = 1, 8 do
  local uid = "t" .. i
  team.pets[i] = { uid = uid, rarity = "common", level = 1 }
  team.equipped[i] = uid
end
__out.soloDmg = Progress.petDamage(solo, 1000)
__out.teamDmg = Progress.petDamage(team, 1000)
__out.playerDmgNv1 = Combat.playerDamage(1, 1)
__out.playerDmgNv10 = Combat.playerDamage(10, 1)

-- 8. vida: dano de pet nunca e negativo nem fracionario
__out.dmgInteiro = dmg10 == math.floor(dmg10)
return "ok"
`;

try {
	lua.execute(script);
} catch (error) {
	console.error("progress FALHOU ao carregar:", String(error).slice(0, 400));
	process.exit(1);
}

const out = (name) => {
	const v = lua.globals.get("__out").get(name);
	if (v == null) return v;
	if (typeof v === "number" || typeof v === "boolean") return v;
	if (typeof v === "string") return v;
	return Number(String(v));
};

// 1. save antigo e corrompido
check(out("oldLevel") === 1, `save antigo ficou nível ${out("oldLevel")}`);
check(out("oldXp") === 0, `save antigo ficou com ${out("oldXp")} XP`);
check(out("oldLevelUps") === 0, `save antigo ficou com ${out("oldLevelUps")} level ups`);
check(out("badLevel") === 1, `save corrompido ("abc") virou nível ${out("badLevel")}`);
check(out("badXp") === 0, `XP negativo virou ${out("badXp")}`);
check(out("zeroLevel") === 1, `nível 0 não foi corrigido (${out("zeroLevel")})`);
check(out("zeroLevelUps") === -3, `levelUps negativo virou ${out("zeroLevelUps")} — ensure não deve inventar valor`);

// 2. fontes de XP
check(out("hatchXp") >= 20, `chocar ovo dá só ${out("hatchXp")} XP`);
check(out("mineXp") >= 10, `minerar dá só ${out("mineXp")} XP`);
check(out("rebirthXp") > out("hatchXp") * 5, "renascer não dá bem mais XP que chocar");
check(out("tapXp") === 0, `o toque dá ${out("tapXp")} XP (deveria ser 0: toque dá moeda)`);
check(out("unknownXp") == null, "fonte de XP desconhecida não devolveu nil");
check(out("hatchGained") >= 20, `chocar ovo creditou só ${out("hatchGained")} de XP`);
check(out("statsHatch") >= 20, `estatística de XP por fonte não registrou (${out("statsHatch")})`);

// 3. level up pela camada do Progress
check(out("infoLevel") > 1, `XP gigante não subiu de nível (${out("infoLevel")})`);
check(out("infoLeveled") === true, "info.leveled não marcou o level up");
check(out("infoLevels") === out("infoLevelValue") - 1, `contador de level ups (${out("infoLevels")}) não bate com o nível alcançado (${out("infoLevelValue")})`);
check(out("toNextPositive") === true, "faltou XP para o próximo nível depois de subir");
check(out("snapToNext") > 0, "snapshot não informa quanto falta para o próximo nível");

// 4. pet
check(out("petLevelStart") === 1, `pet nasceu no nível ${out("petLevelStart")}`);
check(out("petLevelAfter") === 2, `pet com XP exato não subiu (${out("petLevelAfter")})`);
check(out("petLeveled") === true, "level up do pet não foi sinalizado");
check(out("petXpLeft") === 0, `sobrou ${out("petXpLeft")} de XP do pet`);
check(out("petDmg10") > out("petDmg1"), `pet nível 10 não bate mais que nível 1: ${out("petDmg1")} -> ${out("petDmg10")}`);

// 5. dividir XP entre pets
check(out("manyPetXp") < out("onePetXp"), `8 pets rendem o mesmo XP de 1 (${out("manyPetXp")} vs ${out("onePetXp")})`);
check(
	out("manyPetXp") * 8 < out("onePetXp") * 8,
	`8 pets rendem mais que 8x o XP de 1 pet (${out("manyPetXp") * 8} vs ${out("onePetXp") * 8})`,
);
check(out("eightPetsDmg") > 0, "8 pets equipados não somam dano");
check(
	out("teamDmg") < out("soloDmg") * 4,
	`8 pets valem ${out("teamDmg")} contra ${out("soloDmg")} de 1 pet (mais de 4x) — equipar virou a única estratégia`,
);
check(out("teamDmg") > out("soloDmg"), "8 pets não somam NADA a mais que 1 pet (retorno decrescente virou retorno zero)");

// 6. pet não equipado
check(out("noPetDmg") === 0, `pet não equipado deu ${out("noPetDmg")} de dano`);
check(out("ghostDmg") === 0, `uid fantasma deu ${out("ghostDmg")} de dano`);
check(out("ghostRewards") === 0, "uid fantasma gerou recompensa de pet");
check(out("dmgInteiro") === true, "dano do pet não é inteiro (barra de vida mostraria 12.3)");
check(
	out("armyDmg") < out("playerDmgNv1"),
	`exército de 8 pets secretos nv60 dá ${out("armyDmg")} de dano, mais que o acerto do jogador nv1 (${out("playerDmgNv1")}) — o pet virou o protagonista`,
);
// o teto relativo: o pet nunca passa de 75% do acerto do jogador, em nenhum nível
check(out("petDmg10") <= 75, `pet deu ${out("petDmg10")} de 100, acima do teto de 75%`);
check(out("petDmg1") > 0, "pet equipado no nível 1 não dá dano nenhum (o pet virou enfeite)");

if (problems.length > 0) {
	console.error("progress FALHOU:");
	for (const p of problems) console.error("  - " + p);
	process.exit(1);
}
console.log(
	`progress ok — save antigo vira nv1, chocar=${out("hatchXp")} XP, pet nv10 bate ${out("petDmg10")} (nv1 ${out("petDmg1")}), 8 pets dividem XP`,
);
