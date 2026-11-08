// run.mjs — roda tests/spec.luau fora do Roblox.
// Shim minimo de Color3 + print roteado pro stdout do node.
// Uso: npm test
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
Vector3 = {
  new = function(x, y, z) return { X = x, Y = y, Z = z } end,
}
`;

const wrap = (name, source) => `local ${name} = (function()\n${source}\nend)()\n`;

const script = [
  SHIM,
  `print = hostprint`,
  wrap("GameConfig", read("src/shared/GameConfig.luau")),
  wrap("Format", read("src/shared/Format.luau")),
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
  console.error("\n" + String((e && e.message) || e).split("\n").slice(0, 8).join("\n"));
  process.exit(1);
}
