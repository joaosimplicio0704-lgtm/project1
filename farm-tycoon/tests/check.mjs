// check.mjs — parse de todos os .luau do projeto. Falha em erro de sintaxe.
import { Lua } from "@luau-rs/luau";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const walk = (dir, out = []) => {
	for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
		if (entry.name === "node_modules" || entry.name === "build") continue;
		const full = path.join(dir, entry.name);
		if (entry.isDirectory()) walk(full, out);
		else if (entry.name.endsWith(".luau")) out.push(full);
	}
	return out;
};

const files = walk(path.join(root, "src")).concat(walk(path.join(root, "tests")));
const lua = await Lua.create({ sandbox: true });

let bad = 0;
for (const file of files) {
	const source = fs.readFileSync(file, "utf8");
	try {
		const chunk = lua.compile(source);
		if (chunk && chunk.ok === false) throw new Error(chunk.error?.message ?? "compile error");
	} catch (error) {
		bad += 1;
		console.error("FAIL", path.relative(root, file));
		console.error("  " + String(error.message).split("\n").slice(0, 3).join("\n  "));
	}
}

if (bad > 0) {
	console.error(`\n${bad} de ${files.length} arquivos falharam`);
	process.exit(1);
}
console.log(`check ok — ${files.length} arquivos`);
