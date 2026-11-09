// lighting.mjs — a luz do build não pode mentir.
//
// DOIS problemas reais que este teste existe para impedir:
//
// 1. DUAS FONTES DE VERDADE. default.project.json tinha Brightness 3.1
//    cravado, e World.luau também ajustava a luz em runtime. O JSON ganhava
//    no arquivo .rbxlx, então eu "reduzia a luz" no Lua e nada mudava no
//    build que o jogador abre. Aqui os dois são comparados.
//
// 2. SATURAÇÃO. O jogador viu o mapa branco. A conta é simples: brilho do
//    sol x exposição x luzes extras. Se passar do limite, a cor chapada
//    some. Este teste falha antes de abrir no Studio.
//
// Uso: node tests/lighting.mjs

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");

const problems = [];
const project = JSON.parse(read("default.project.json"));
const light = project.tree.Lighting.$properties;
const world = read("src/server/World.luau");

function num(source, key, fallback = null) {
	const m = source.match(new RegExp(`Lighting\\.${key}\\s*=\\s*([-\\d.]+)`));
	return m ? Number(m[1]) : fallback;
}

// 1. JSON e código falam a mesma coisa
const codeBrightness = num(world, "Brightness");
const codeClock = num(world, "ClockTime");
const codeExposure = num(world, "ExposureCompensation");

if (codeBrightness === null) {
	problems.push("World.luau não define Lighting.Brightness");
} else if (Math.abs(codeBrightness - light.Brightness) > 0.001) {
	problems.push(
		`Brightness divergente: World.luau=${codeBrightness} default.project.json=${light.Brightness} (o JSON é o que vai no build)`,
	);
}
if (codeClock !== null && Math.abs(codeClock - light.ClockTime) > 0.001) {
	problems.push(`ClockTime divergente: code=${codeClock} json=${light.ClockTime}`);
}
if (codeExposure !== null && Math.abs(codeExposure - light.ExposureCompensation) > 0.001) {
	problems.push(`ExposureCompensation divergente: code=${codeExposure} json=${light.ExposureCompensation}`);
}

// 2. Ganho total: se passar de 1.25 a cor chapada começa a estourar
const gain = (light.Brightness / 1.35) * (1 + light.ExposureCompensation);
if (gain > 1.25) {
	problems.push(
		`luz estourada: ganho ${gain.toFixed(2)} (limite 1.25). Brilho ${light.Brightness} + exposição ${light.ExposureCompensation} lava as cores em branco`,
	);
}
if (gain < 0.45) {
	problems.push(`luz escura demais: ganho ${gain.toFixed(2)} (mínimo 0.45) — sombra vira breu`);
}

// 3. Luz central do bioma não pode ser holofote.
// Range grande a partir de um ponto só pega a ilha inteira de frente.
const sunRange = world.match(/sun\.Range\s*=\s*math\.max\((\d+(?:\.\d+)?),\s*biome\.radius\s*\*\s*([\d.]+)\)/);
if (!sunRange) {
	problems.push("não achei o Range da luz do bioma — o padrão mudou? confira a saturação na mão");
} else {
	const fixed = Number(sunRange[1]);
	const ratio = Number(sunRange[2]);
	if (ratio > 0.6) {
		problems.push(`luz do bioma cobre ${(ratio * 100).toFixed(0)}% do raio (máx 60%) — é holofote, não ambiente`);
	}
	if (fixed > 60) {
		problems.push(`Range mínimo da luz do bioma é ${fixed} (máx 60)`);
	}
}

const sunBright = world.match(/sun\.Brightness\s*=\s*math\.min\(spec\.intensity,\s*([\d.]+)\)/);
if (!sunBright) {
	problems.push("a luz do bioma não está limitada por math.min — spec.intensity volta a estourar");
} else if (Number(sunBright[1]) > 0.8) {
	problems.push(`luz do bioma limitada em ${sunBright[1]} (máx 0.8): acima disso vira branco`);
}

// 4. Nenhuma PointLight do mapa pode ter alcance absurdo.
// O preview procura essas; aqui a gente nem deixa chegar no build.
const ranges = [...world.matchAll(/\.Range\s*=\s*(\d+)/g)].map((m) => Number(m[1]));
const wide = ranges.filter((r) => r > 150);
if (wide.length > 0) {
	problems.push(`PointLight com alcance ${wide.join(", ")} (máx 150) — uma luz dessas lava a ilha inteira`);
}

if (problems.length > 0) {
	console.error("lighting FALHOU:");
	for (const p of problems) console.error("  - " + p);
	process.exit(1);
}
console.log(
	`lighting ok — brilho ${light.Brightness} + exposição ${light.ExposureCompensation} = ganho ${gain.toFixed(2)}, luz do bioma a ${(Number(sunRange[2]) * 100).toFixed(0)}% do raio`,
);
