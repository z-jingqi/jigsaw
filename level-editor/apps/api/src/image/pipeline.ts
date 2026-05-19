import { copyFile, mkdir, readFile } from "node:fs/promises";
import path from "node:path";
import { safeColor } from "../lib/sanitize.js";
import { clampInt } from "../lib/strings.js";
import type { PendingImageItem } from "../types/pending.js";
import type { ProcessStep, ProcessStepType } from "../types/process.js";
import { execTool } from "./python-tools.js";

export function normalizeProcessStep(value: any): ProcessStep {
	const type = String(value?.type || "");
	if (type !== "convert_jpg" && type !== "remove_background" && type !== "trim_transparent" && type !== "compress") {
		throw new Error(`unsupported processing step: ${type}`);
	}
	return {
		type,
		tolerance: clampInt(value?.tolerance, 0, 441, 35),
		padding: clampInt(value?.padding, 0, 256, 0),
		quality: clampInt(value?.quality, 1, 100, 88),
		background: safeColor(value?.background || "#F6EBD4"),
	};
}

export function isProcessStepType(value: unknown): value is ProcessStepType {
	return value === "convert_jpg" || value === "remove_background" || value === "trim_transparent" || value === "compress";
}

export function normalizeStepTypeList(value: unknown): ProcessStepType[] {
	if (!Array.isArray(value)) return [];
	return uniqueStepTypes(value.filter(isProcessStepType));
}

export function uniqueStepTypes(values: ProcessStepType[]) {
	return [...new Set(values)];
}

export function canRunPendingStep(item: PendingImageItem, type: ProcessStepType) {
	if (type === "compress") return !item.compression_stable;
	return !(item.applied_step_types || []).includes(type);
}

export async function runImagePipeline(input: string, workDir: string, steps: ProcessStep[]) {
	let current = input;
	for (const [index, step] of steps.entries()) {
		const outDir = path.join(workDir, `step-${index}`);
		await mkdir(outDir, { recursive: true });
		const parsed = path.parse(current);
		if (step.type === "remove_background") {
			await execTool("remove_solid_background.py", [
				current,
				"-o",
				outDir,
				"--suffix",
				"",
				"--tolerance",
				String(step.tolerance ?? 35),
			]);
			current = await outputOrCopied(current, path.join(outDir, `${parsed.name}.png`));
			continue;
		}
		if (step.type === "trim_transparent") {
			await execTool("trim_transparent_image.py", [
				current,
				"-o",
				outDir,
				"--padding",
				String(step.padding ?? 0),
			]);
			current = await outputOrCopied(current, path.join(outDir, parsed.base));
			continue;
		}
		if (step.type === "convert_jpg") {
			if ([".jpg", ".jpeg"].includes(path.extname(current).toLowerCase())) {
				continue;
			}
			await execTool("convert_to_jpg.py", [
				current,
				"-o",
				outDir,
				"--suffix",
				"",
				"--quality",
				String(step.quality ?? 88),
				"--background",
				step.background || "#F6EBD4",
				"--overwrite",
			]);
			current = await outputOrCopied(current, path.join(outDir, `${parsed.name}.jpg`));
			continue;
		}
		if (step.type === "compress") {
			await execTool("compress_images.py", [
				current,
				"-o",
				outDir,
				"--jpeg-quality",
				String(step.quality ?? 88),
			]);
			current = await outputOrCopied(current, path.join(outDir, parsed.base));
		}
	}
	return current;
}

async function outputOrCopied(input: string, output: string) {
	const target = path.resolve(output);
	try {
		await readFile(target);
		return target;
	} catch {
		await copyFile(input, target);
		return target;
	}
}
