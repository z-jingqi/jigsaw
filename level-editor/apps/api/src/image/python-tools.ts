import { execFile } from "node:child_process";
import { promisify } from "node:util";
import path from "node:path";
import { projectRoot, toolsDir } from "../config/paths.js";
import type { ProcessStepType } from "../types/process.js";

const execFileAsync = promisify(execFile);

export function pythonToolInfo(name: string) {
	const supported: Record<string, { label: string; stepType: ProcessStepType; description: string }> = {
		"convert_to_jpg.py": {
			label: "转 JPG",
			stepType: "convert_jpg",
			description: "用指定底色合成透明区域，并导出 JPG；已是 JPG 时会跳过。",
		},
		"remove_solid_background.py": {
			label: "去背景",
			stepType: "remove_background",
			description: "移除图片周围的纯色背景，适合透明化原图底色。",
		},
		"trim_transparent_image.py": {
			label: "裁透明边",
			stepType: "trim_transparent",
			description: "裁掉透明边缘，并可保留指定像素的留边。",
		},
		"compress_images.py": {
			label: "压缩图片",
			stepType: "compress",
			description: "在保持图片尺寸和透明度的前提下压缩文件。",
		},
	};
	const info = supported[name];
	if (!info) return null;
	return {
		name,
		label: info.label,
		supported: true,
		description: info.description,
		stepType: info.stepType,
	};
}

export async function execTool(scriptName: string, args: Array<string>) {
	const script = path.join(toolsDir, scriptName);
	const { stderr } = await execPython([script, ...args.map(String)]);
	if (stderr.trim()) {
		console.warn(`[level-editor-api] ${scriptName}: ${stderr.trim()}`);
	}
}

async function execPython(args: string[]) {
	const defaultCandidates = process.platform === "win32" ? ["python", "python3"] : ["python3", "python"];
	const candidates = [process.env.PYTHON, ...defaultCandidates].filter(Boolean) as string[];
	let lastError: unknown = null;
	for (const command of candidates) {
		try {
			return await execFileAsync(command, args, {
				cwd: projectRoot,
				maxBuffer: 1024 * 1024 * 8,
			});
		} catch (error: any) {
			lastError = error;
			if (error?.code !== "ENOENT") throw error;
		}
	}
	throw lastError || new Error("python executable not found");
}
