// mapfile.mjs — valida o .rbxlx final que o jogador baixa do GitHub.
// Abrir no Studio e descobrir que o mapa não veio é o pior cenário possível,
// então este teste lê o ARQUIVO gerado e confere o que precisa existir dentro.
// Uso: node tests/mapfile.mjs
import fs from "node:fs";
import path from "node:path";
import { root } from "./harness.mjs";

const FILE = path.join(root, "build", "EggTycoon.rbxlx");

if (!fs.existsSync(FILE)) {
	console.error(`mapfile FALHOU: ${FILE} não existe — rode "npm run build"`);
	process.exit(1);
}

const xml = fs.readFileSync(FILE, "utf8");
const problems = [];

const count = (pattern) => (xml.match(pattern) ?? []).length;
const items = count(/<Item class="/g);
const parts = count(/<Item class="Part"/g);

const biomes = [...xml.matchAll(/<string name="Name">(Biome_[a-z]+)<\/string>/g)].map((m) => m[1]);
const eggs = [...xml.matchAll(/<string name="Name">(Egg_[a-z]+)<\/string>/g)].map((m) => m[1]);

const hasSpawn = /<Item class="SpawnLocation"/.test(xml);
const clicks = count(/<Item class="ClickDetector"/g);
const scripts = count(/<Item class="(ModuleScript|Script|LocalScript)"/g);

// Parte de tamanho zero: o jogador atravessa e cai no vazio.
const zeroSize =
	xml.match(/<Vector3 name="size">\s*<X>0(?:\.0+)?<\/X>/g)?.length ??
	xml.match(/<Vector3 name="size">\s*<X>0(?:\.0+)?<\/X>/g)?.length ??
	0;

if (!items) problems.push("arquivo sem nenhum <Item> — não é um lugar do Roblox");
if (parts < 2000) problems.push(`partes: ${parts} (esperado >= 2000)`);
if (new Set(biomes).size !== 7) problems.push(`biomas: ${new Set(biomes).size} (esperado 7)`);
if (new Set(eggs).size !== 7) problems.push(`ovos: ${new Set(eggs).size} (esperado 7)`);
if (!hasSpawn) problems.push("sem SpawnLocation — o jogador nasce no vazio");
if (clicks < 20) problems.push(`ClickDetector: ${clicks} (esperado >= 20)`);
if (scripts < 20) problems.push(`scripts: ${scripts} (esperado >= 20) — o jogo não roda`);
if (zeroSize > 0) problems.push(`partes com tamanho zero: ${zeroSize}`);

const mb = (Buffer.byteLength(xml) / 1024 / 1024).toFixed(1);

if (problems.length) {
	console.error("mapfile FALHOU");
	for (const problem of problems) console.error("  - " + problem);
	process.exit(1);
}

console.log(`mapfile ok — ${mb} MB, ${items} itens, ${parts} partes, ${scripts} scripts`);
console.log(`  ${new Set(biomes).size} biomas · ${new Set(eggs).size} ovos · ${clicks} click detectors`);
