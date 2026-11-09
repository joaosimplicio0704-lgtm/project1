// mine.mjs — prova que a Mina dos Pets é uma MECÂNICA, não um enfeite.
//
// O risco desta mecânica é silencioso: se o bônus de raridade estiver errado,
// o jogo continua rodando e só fica chato — pet lendário acha pedra igual ao
// comum e ninguém percebe até o jogador reclamar. Então aqui a gente mede:
//
//   1. pet melhor acha minério melhor (valor médio sobe com a raridade)
//   2. as probabilidades somam 1 e batem com o sorteio de verdade
//   3. o sorteio é estável: os mesmos números de entrada dão o mesmo resultado
//   4. apressar custa menos que o minério (nunca é armadilha)
//   5. o ciclo do servidor roda ponta a ponta: sai, volta, recolhe, soma
//
// Uso: node tests/mine.mjs

import { Lua } from "@luau-rs/luau";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");

const problems = [];

function check(condition, message) {
	if (!condition) {
		problems.push(message);
	}
}

const HOST = String.raw`
-- Host mínimo: só o que Mine.luau e MineServer.luau precisam.
local __clock = 1000

__clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end

Random = {
  new = function(seed)
    local state = (seed or 1) % 2147483647
    if state <= 0 then state = state + 2147483646 end
    local rng = {}
    function rng:NextNumber()
      state = (state * 16807) % 2147483647
      return state / 2147483647
    end
    return rng
  end,
}

os = { clock = function() return __clock end, time = function() return 0 end }
local function advance(seconds) __clock = __clock + seconds end

task = { wait = function() return 0.1 end }

local created = {}
Instance = {
  new = function(className)
    local inst = { ClassName = className, Children = {} }
    function inst:FindFirstChild(name)
      for _, c in ipairs(self.Children) do if c.Name == name then return c end end
      return nil
    end
    return inst
  end,
}

local shared = {} -- preenchido depois que o modulo carrega

ReplicatedStorage = {}
game = {
  GetService = function(_, name)
    if name == "ReplicatedStorage" then
      return {
        Shared = setmetatable({}, {
          __index = function(_, k) return shared[k] end,
        }),
      }
    end
    return {}
  end,
}
`;

function createLua() {
	return Lua.create({ sandbox: true });
}

// --- Lua: carrega Mine e testa a lógica pura -----------------------------
const lua = await createLua();
const mineSrc = read("src/shared/Mine.luau")
	.replace(/^return Mine\s*$/m, "")
	.replace(/math\.clamp\(/g, "__clamp(");

const script = String.raw`
${HOST}
${mineSrc}

shared.Mine = Mine -- agora sim, o modulo ja existe

__results = {}

-- 1. probabilidades somam 1
for _, rarity in ipairs({ "common", "uncommon", "rare", "epic", "legendary", "secret" }) do
  local c = Mine.chances(rarity)
  local sum = 0
  for _, p in pairs(c) do sum = sum + p end
  __results["sum_" .. rarity] = sum
end

-- 2. valor médio sobe com a raridade
local order = { "common", "uncommon", "rare", "epic", "legendary", "secret" }
-- serializado como texto: a ponte Lua->JS de tabelas é chata e frágil,
-- e o que interessa aqui é só a lista de números
__results.avgText = ""
for _, rarity in ipairs(order) do
  local c = Mine.chances(rarity)
  local ev = 0
  for _, ore in ipairs(Mine.ores) do
    ev = ev + (c[ore.id] or 0) * ore.value
  end
  __results.avgText = __results.avgText .. rarity .. ":" .. string.format("%.2f", ev) .. ";"
end

-- 3. sorteio determinístico: mesmo roll -> mesmo minério
local a = Mine.rollOre("rare", 0.42)
local b = Mine.rollOre("rare", 0.42)
__results.sameRoll = (a.id == b.id)

-- 4. sorteio cobre a faixa: roll 0 e roll 1 não estouram
__results.low = Mine.rollOre("common", 0).id
__results.high = Mine.rollOre("common", 1).id

-- 5. apressar custa menos que o minério
__results.rushCheap = true
for _, ore in ipairs(Mine.ores) do
  if Mine.rushCost(ore) >= ore.value then __results.rushCheap = false end
end

-- 6. O SORTEIO DE VERDADE respeita a raridade.
-- Testar só Mine.chances() não basta: chances() tem conta própria e pode
-- estar certa enquanto rollOre() ignora a raridade. Aqui roda o sorteio
-- real 4000 vezes e compara a média.
__results.simText = ""
for _, rarity in ipairs(order) do
  local total = 0
  local n = 4000
  for i = 1, n do
    local ore = Mine.rollOre(rarity, (i - 0.5) / n)
    total = total + ore.value
  end
  __results.simText = __results.simText .. rarity .. ":" .. string.format("%.2f", total / n) .. ";"
end

-- 7. progresso vai de 0 a 1 e trava
__results.progStart = Mine.progress(0)
__results.progMid = Mine.progress(Mine.TripSeconds / 2)
__results.progEnd = Mine.progress(Mine.TripSeconds * 10)

-- 8. raridade desconhecida não explode (cai no comum)
local okUnknown = pcall(function() return Mine.rollOre("inexistente", 0.5) end)
__results.unknownOk = okUnknown

return "ok"
`;

let ok = null;
try {
	lua.execute(script);
	ok = "ok";
} catch (error) {
	problems.push(`Mine.luau não carregou: ${String(error).slice(0, 400)}`);
}

if (ok !== null) {
	const res = (name) => lua.globals.get("__results").get(name);
	const toNum = (v) => (typeof v === "number" ? v : Number(String(v)));

	// 1. somas
	for (const rarity of ["common", "uncommon", "rare", "epic", "legendary", "secret"]) {
		const sum = toNum(res(`sum_${rarity}`));
		check(Math.abs(sum - 1) < 0.001, `probabilidades de ${rarity} somam ${sum}, não 1`);
	}

	// 2. valor médio crescente
	const avgText = String(res("avgText") ?? "");
	const values = avgText
		.split(";")
		.filter(Boolean)
		.map((chunk) => {
			const [rarity, value] = chunk.split(":");
			return { rarity, value: Number(value) };
		});
	if (values.length < 6) {
		problems.push(`valor médio por raridade não foi calculado: "${avgText}"`);
	} else {
		for (let i = 1; i < values.length; i++) {
			check(
				values[i].value > values[i - 1].value,
				`valor médio não sobe: ${values[i - 1].rarity}=${Math.round(values[i - 1].value)} -> ${values[i].rarity}=${Math.round(values[i].value)}`,
			);
		}
		// pet secreto precisa render bem mais que o comum, senão raridade
		// não significa nada na mina
		const gain = values[values.length - 1].value / values[0].value;
		check(gain > 4, `pet secreto só rende ${gain.toFixed(1)}x o comum (esperado >4x)`);
	}

	// 6b. o sorteio REAL tem que subir com a raridade, não só a tabela
	// de probabilidades. Foi assim que descobri que meu único teste de
	// raridade passava mesmo com rollOre ignorando o bônus.
	const simText = String(res("simText") ?? "");
	const sim = simText
		.split(";")
		.filter(Boolean)
		.map((chunk) => {
			const [rarity, value] = chunk.split(":");
			return { rarity, value: Number(value) };
		});
	if (sim.length < 6) {
		problems.push(`sorteio simulado não rodou: "${simText}"`);
	} else {
		for (let i = 1; i < sim.length; i++) {
			check(
				sim[i].value > sim[i - 1].value * 1.05,
				`sorteio real não sobe de ${sim[i - 1].rarity} (${Math.round(sim[i - 1].value)}) para ${sim[i].rarity} (${Math.round(sim[i].value)})`,
			);
		}
		const realGain = sim[sim.length - 1].value / sim[0].value;
		check(realGain > 4, `no sorteio real pet secreto só rende ${realGain.toFixed(1)}x o comum`);
	}

	check(res("sameRoll") === true, "o sorteio não é estável para o mesmo roll");
	check(String(res("low")) === "stone", `roll 0 deveria dar pedra, deu ${res("low")}`);
	check(String(res("high")) === "crystal", `roll 1 deveria dar cristal, deu ${res("high")}`);
	check(res("rushCheap") === true, "apressar custa igual ou mais que o minério (é armadilha)");
	check(toNum(res("progStart")) === 0, `progresso inicial ${res("progStart")} != 0`);
	check(Math.abs(toNum(res("progMid")) - 0.5) < 0.001, `progresso no meio ${res("progMid")} != 0.5`);
	check(toNum(res("progEnd")) === 1, `progresso final ${res("progEnd")} != 1 (não trava)`);
	check(res("unknownOk") === true, "raridade desconhecida derrubou o sorteio");
}

// --- Ciclo completo do servidor -----------------------------------------
// MineServer.sync / collect usam os.clock() e data do jogador. Aqui o host
// tem relógio controlado, então dá para rodar o ciclo inteiro sem esperar.
const lua2 = await createLua();
const serverSrc = read("src/server/MineServer.luau")
	.replace(/^local ReplicatedStorage = game:GetService\("ReplicatedStorage"\)/m, "")
	.replace(/^local Mine = require\(ReplicatedStorage\.Shared\.Mine\)/m, "")
	.replace(/^return MineServer\s*$/m, "");

const cycle = String.raw`
${HOST}
${mineSrc}
${serverSrc}

shared.Mine = Mine

local GameConfig = {
  pet = function(id)
    local defs = { comum = "common", raro = "legendary" }
    local rarity = defs[id]
    if not rarity then return nil end
    return { id = id, rarity = rarity }
  end,
}

MineServer.init(GameConfig)

__step = "init-data"
local data = {
  coins = 1000000,
  equipped = { 1, 2 },
  pets = {
    { uid = 1, petId = "comum", golden = false },
    { uid = 2, petId = "raro", golden = false },
  },
  stats = { hatched = 0 },
  mine = { dug = {}, best = "", total = 0 },
}

__cycle = {}

-- as duas viagens começam ao mesmo tempo
__step = "sync"
MineServer.sync(nil, data)
local __step = "snapshot-ready"
snap = MineServer.snapshot(nil, data)
__cycle.tripCount = #snap.trips
__cycle.startedProgress = snap.trips[1].progress
__cycle.hiddenBeforeReady = (snap.trips[1].oreId == nil)

-- ainda não voltou: recolher não deve dar nada
__step = "collect-early"
local early, earlyCoins = MineServer.collect(nil, data)
__cycle.earlyCount = #early
__cycle.earlyCoins = earlyCoins

-- espera a viagem terminar
advance(Mine.TripSeconds + 1)
snap = MineServer.snapshot(nil, data)
__cycle.readyCount = 0
for _, trip in ipairs(snap.trips) do
  if trip.ready then __cycle.readyCount = __cycle.readyCount + 1 end
end

-- recolhe tudo
__step = "collect"
local collected, coins = MineServer.collect(nil, data)
__cycle.collected = #collected
__cycle.coins = coins
__cycle.total = data.mine.total
__cycle.hasBest = data.mine.best ~= ""

-- recolher de novo sem esperar tem que dar zero (o pet já saiu)
__step = "collect-again"
local again, againCoins = MineServer.collect(nil, data)
__cycle.again = #again
__cycle.againCoins = againCoins

-- apressar: precisa cobrar e liberar
advance(1)
__step = "rush"
local rushed = MineServer.rush(nil, data, 1)
__cycle.rushOk = rushed
local afterRush = MineServer.snapshot(nil, data)
__cycle.anyReady = false
for _, trip in ipairs(afterRush.trips) do
  if trip.uid == 1 and trip.ready then __cycle.anyReady = true end
end

-- desequipar tira a vaga
data.equipped = { 2 }
__step = "unequip"
MineServer.sync(nil, data)
__cycle.afterUnequip = #MineServer.snapshot(nil, data).trips

return "ok"
`;

function cycleStep() {
	try { return String(lua2.globals.get("__step")); } catch { return "?"; }
}
let cycleOk = null;
try {
	lua2.execute(cycle);
	cycleOk = "ok";
} catch (error) {
	problems.push(`MineServer não rodou em [${String(cycleStep())}]: ${String(error).slice(0, 300)}`);
}

if (cycleOk !== null) {
	const c = (name) => lua2.globals.get("__cycle").get(name);
	const num = (v) => (typeof v === "number" ? v : Number(String(v)));

	check(num(c("tripCount")) === 2, `2 pets equipados deveriam dar 2 viagens, deu ${c("tripCount")}`);
	check(num(c("startedProgress")) < 0.2, "a viagem já começou quase pronta");
	check(c("hiddenBeforeReady") === true, "o minério aparece antes do pet voltar (estraga a surpresa)");
	check(num(c("earlyCount")) === 0, `recolher antes da hora deu ${c("earlyCount")} minérios`);
	check(num(c("earlyCoins")) === 0, "recolher antes da hora pagou moedas");
	check(num(c("readyCount")) === 2, `depois do tempo só ${c("readyCount")}/2 voltaram`);
	check(num(c("collected")) === 2, `recolher tudo pegou ${c("collected")}/2`);
	check(num(c("coins")) > 0, "recolher não pagou nada");
	check(num(c("total")) === 2, `total de viagens ${c("total")} != 2`);
	check(c("hasBest") === true, "o melhor minério não foi registrado");
	check(num(c("again")) === 0, `recolher de novo sem esperar deu ${c("again")} (deveria reiniciar a viagem)`);
	check(c("rushOk") === true, "apressar falhou com moedas de sobra");
	check(c("anyReady") === true, "apressar não liberou o pet");
	check(num(c("afterUnequip")) === 1, `desequipar deixou ${c("afterUnequip")} viagens (esperado 1)`);
}

if (problems.length > 0) {
	console.error("mine FALHOU:");
	for (const p of problems) console.error("  - " + p);
	process.exit(1);
}
console.log("mine ok — raridade manda no minério, ciclo completo funciona");
