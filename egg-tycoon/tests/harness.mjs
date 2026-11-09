// tests/harness.mjs — utilidades comuns dos testes.
// Carrega o host falso (tests/host.luau) e empacota os módulos Luau num chunk
// só, trocando `require` por IIFE. É o suficiente porque os testes rodam no
// mesmo ambiente de um jeito que o Roblox não rodaria — mas barato e rápido.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Lua } from "@luau-rs/luau";

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

export const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");

export const HOST = read("tests/host.luau");

// Remove só as linhas que pegam serviços e os require de módulo: o resto do
// código (que é o que interessa) roda igual.
const stripModuleRequires = (src) =>
	src
		.split("\n")
		// Qualquer `local X = require(...)` cai: X já vive no chunk.
		// Fazer antes do replace inline, senão `local Net = require(...Net)`
		// vira `local Net = Net` e a variável se sombreia com nil.
		.filter((line) => !/^\s*local \w+ = require\(/.test(line))
		// require(ReplicatedStorage.Shared.X) inline -> X (já está no chunk)
		.map((line) => line.replace(/require\(\s*ReplicatedStorage\.Shared\.(\w+)\s*\)/g, "$1"))
		.join("\n");

// Um módulo vira IIFE nomeada. Dependências já precisam estar no chunk.
export const moduleCode = (name, file) => `local ${name} = (function()\n${stripModuleRequires(read(file))}\nend)()\n`;

export const sharedModules = (names) =>
	names.map((name) => moduleCode(name, `src/shared/${name}.luau`)).join("\n");

export const serverModules = (names) =>
	names.map((name) => moduleCode(name, `src/server/${name}.luau`)).join("\n");

export const clientModules = (names) =>
	names.map((name) => moduleCode(name, `src/client/${name}.luau`)).join("\n");

// Um único chunk: locais de um execute() não sobrevivem para o próximo.
export const chunk = (...parts) => parts.filter(Boolean).join("\n");

export async function createLua(options = {}) {
	const lua = await Lua.create({ sandbox: true });
	// O host.luau chama hostprint; sem isso, qualquer print derruba o teste.
	const quiet = options.quiet ?? true;
	lua.globals.set(
		"hostprint",
		lua.createFunction((...args) => {
			if (!quiet) console.log(args.map((a) => String(a)).join("\t"));
		}),
	);
	return lua;
}

// Executa e devolve o erro com a mensagem limpa (sem o dump gigante que o
// Luau às vezes imprime).
export function run(lua, code, label) {
	try {
		lua.execute(code);
	} catch (error) {
		const message = String(error?.message ?? error);
		throw new Error(`${label}: ${message.slice(0, 1200)}`);
	}
}

// Converte o que vem de lua.globals para JS puro.
// Tabelas Lua chegam como LuaTable, cujo único acessor público é entries().
export function fromLua(value) {
	if (value == null || typeof value !== "object") return value;
	if (Array.isArray(value)) return value.map(fromLua);
	if (value instanceof Map) return Object.fromEntries([...value.entries()].map(([k, v]) => [String(k), fromLua(v)]));

	if (typeof value.entries === "function") {
		const entries = [...value.entries()];
		const isArray = entries.length > 0 && entries.every(([key], index) => Number(key) === index + 1);
		if (isArray) return entries.map(([, val]) => fromLua(val));
		if (entries.length === 0) return {};
		return Object.fromEntries(entries.map(([key, val]) => [String(key), fromLua(val)]));
	}
	return value;
}

// Conta instâncias por classe a partir da raiz do Workspace do host falso.
export const COUNT_SCRIPT = String.raw`
local function walk(node, out)
  for _, child in ipairs(node:GetChildren()) do
    local cls = child.ClassName
    out[cls] = (out[cls] or 0) + 1
    walk(child, out)
  end
end
__counts = {}
walk(game:GetService("Workspace"), __counts)
`;
