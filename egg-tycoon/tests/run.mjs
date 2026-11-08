// run.mjs — roda tests/spec.luau fora do Roblox.
// Dependências viram GLOBAIS (não locals) para que os módulos se enxerguem
// como fariam via require.
import { Lua } from "@luau-rs/luau";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");

const SHIM = `
Color3 = {
  fromRGB = function(r, g, b) return { r = r, g = g, b = b } end,
  new = function(r, g, b) return { r = r, g = g, b = b } end,
}
Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
`;

const withoutRequire = (source) =>
	source
		.split("\n")
		.filter((line) => !/^local \w+ = require\(/.test(line))
		.join("\n");

const module = (name, file) => `${name} = (function()\n${withoutRequire(read(file))}\nend)()\n`;

const script = [
	SHIM,
	`print = hostprint`,
	module("GameConfig", "src/shared/GameConfig.luau"),
	module("Format", "src/shared/Format.luau"),
	module("Pets", "src/shared/Pets.luau"),
	read("tests/spec.luau"),
].join("\n");

const lua = await Lua.create({ sandbox: true });
lua.globals.set(
	"hostprint",
	lua.createFunction((...args) => {
		console.log(args.map((a) => (a === undefined ? "nil" : String(a))).join("\t"));
	}),
);

try {
	lua.execute(script);
} catch (e) {
	console.error("\n" + String((e && e.message) || e).split("\n").slice(0, 10).join("\n"));
	process.exit(1);
}
