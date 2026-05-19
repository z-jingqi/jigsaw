import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

export async function readJson<T>(target: string, fallback: T): Promise<T> {
	try {
		return JSON.parse(await readFile(target, "utf8")) as T;
	} catch {
		return fallback;
	}
}

export async function writeJson(target: string, data: unknown) {
	await mkdir(path.dirname(target), { recursive: true });
	await writeFile(target, `${JSON.stringify(data, null, "\t")}\n`, "utf8");
}
