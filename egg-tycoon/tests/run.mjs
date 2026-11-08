// run.mjs — roda tests/spec.luau fora do Roblox.
// Dependências viram GLOBAIS (não locals) para que os módulos se enxerguem
// como fariam via require.
import { Lua } from "@luau-rs/luau";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");

// Vector3 com aritmética de verdade: Biomes.spawnPoint soma/subtrai vetores e
// usa .Magnitude/.Unit. Um stub só com X/Y/Z quebra o teste de geometria.
const SHIM = `
Color3 = {
  fromRGB = function(r, g, b) return { r = r, g = g, b = b } end,
  new = function(r, g, b) return { r = r, g = g, b = b } end,
}
local V3 = {}
V3.__add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, V3) end
V3.__sub = function(a, b) return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, V3) end
V3.__mul = function(a, n) return setmetatable({ X = a.X * n, Y = a.Y * n, Z = a.Z * n }, V3) end
V3.__index = function(v, key)
  if key == "Magnitude" then
    return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
  elseif key == "Unit" then
    local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
    if m == 0 then return setmetatable({ X = 0, Y = 0, Z = 0 }, V3) end
    return setmetatable({ X = v.X / m, Y = v.Y / m, Z = v.Z / m }, V3)
  end
  return nil
end
Vector3 = {
  new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end,
  zero = function() return setmetatable({ X = 0, Y = 0, Z = 0 }, V3) end,
}
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
	module("Biomes", "src/shared/Biomes.luau"),
	module("Format2", "src/shared/Format.luau"),
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
