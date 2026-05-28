import { withReservedI18n } from "../lib/strings.js";

export function normalizeDefaultImage(image: any, topicId: string, levelId: string) {
	return {
		...(image || {}),
		path: String(image?.path || `res://levels/${topicId}/${levelId}/source.png`),
		name: String(image?.name || "source.png"),
		width: Number(image?.width || 0),
		height: Number(image?.height || 0),
	};
}

export function normalizeLevelImageModes(level: any, topicId: string, levelId: string) {
	const defaultImage = normalizeDefaultImage(level.assets?.default_image || level.image, topicId, levelId);
	level.image = defaultImage;
	level.assets = {
		...(level.assets || {}),
		default_image: defaultImage,
	};
	level.modes = level.modes || {};
	for (const mode of ["polygon", "knob", "swap"] as const) {
		const modeData = level.modes[mode] || {};
		const configured = modeData.image;
		const configuredPath = typeof configured === "string" ? configured : configured?.path || "";
		level.modes[mode] = {
			...modeData,
			image: configuredPath ? configured : defaultImage,
		};
	}
}

export function normalizeLevelForModeSave(
	existingLevel: any,
	incomingLevel: any,
	topicId: string,
	levelId: string,
	mode: "polygon" | "knob" | "swap",
	modeImage: { path: string; name: string; width: number; height: number },
	title: string,
	description: string,
	sharedModes: Array<"polygon" | "knob" | "swap"> = [mode],
) {
	const modesSharingImage = new Set<"polygon" | "knob" | "swap">([...sharedModes, mode]);
	const base = {
		...existingLevel,
		id: levelId,
		topic_id: topicId,
		locale: String(incomingLevel.locale || existingLevel.locale || "zh-cn"),
		title,
		description,
		title_i18n: withReservedI18n({ ...(existingLevel.title_i18n || {}), ...(incomingLevel.title_i18n || {}) }, title),
		description_i18n: withReservedI18n({ ...(existingLevel.description_i18n || {}), ...(incomingLevel.description_i18n || {}) }, description),
		background: { ...(existingLevel.background || {}), ...(incomingLevel.background || {}) },
		grid: { ...(existingLevel.grid || {}), ...(incomingLevel.grid || {}) },
		runtime_layout: { ...(existingLevel.runtime_layout || {}), ...(incomingLevel.runtime_layout || {}) },
		component_overrides: { ...(existingLevel.component_overrides || {}), ...(incomingLevel.component_overrides || {}) },
		modes: {
			...(existingLevel.modes || {}),
			[mode]: {
				...(existingLevel.modes?.[mode] || {}),
				...(incomingLevel.modes?.[mode] || {}),
				image: modeImage,
			},
		},
	};
	for (const sharedMode of modesSharingImage) {
		base.modes[sharedMode] = {
			...(existingLevel.modes?.[sharedMode] || {}),
			...(incomingLevel.modes?.[sharedMode] || {}),
			image: modeImage,
		};
	}
	base.image = modeImage;
	base.assets = { ...(base.assets || {}), default_image: modeImage };
	if (mode === "polygon") {
		base.editor = { ...(existingLevel.editor || {}), ...(incomingLevel.editor || {}) };
	} else {
		base.editor = existingLevel.editor || incomingLevel.editor || { outline: [], cuts: [], shapes: [], pieces: [] };
	}
	// cut_color 是关卡级别的设置（polygon / knob 共享），无论保存哪种模式都让 incoming 的颜色覆盖 existing。
	if (incomingLevel.editor && typeof incomingLevel.editor.cut_color === "string" && incomingLevel.editor.cut_color) {
		base.editor = { ...base.editor, cut_color: incomingLevel.editor.cut_color };
	}
	normalizeLevelImageModes(base, topicId, levelId);
	return base;
}

export function makeLevelJson(topicId: string, levelId: string, title: string, description: string, imageFileName = "source.png", tableclothFileName = "") {
	const image = {
		path: `res://levels/${topicId}/${levelId}/${imageFileName}`,
		name: imageFileName,
		width: 0,
		height: 0,
	};
	const background = tableclothFileName
		? { type: "image", color: "#ead8bd", path: `res://levels/${topicId}/${levelId}/${tableclothFileName}` }
		: { type: "color", color: "#ead8bd", path: "" };
	return {
		schema: "jigsaw.level.v1",
		version: 1,
		id: levelId,
		topic_id: topicId,
		locale: "zh-cn",
		title,
		description,
		title_i18n: withReservedI18n({}, title),
		description_i18n: withReservedI18n({}, description),
		image,
		assets: tableclothFileName ? { default_image: image, cover: background.path } : { default_image: image },
		background,
		grid: { cols: 8, rows: 8, piece_size: 190 },
		runtime_layout: {
			coordinate_space: "source_pixels",
			target: "mobile_portrait",
			min_viewport: [360, 640],
			board_margin_ratio: 1,
			hud_height_ratio: 0,
			side_margin_ratio: 0,
			bottom_margin_ratio: 0,
		},
		component_overrides: {},
		modes: {
			polygon: { image, pieces: [] },
			knob: { image, cols: 8, rows: 8, piece_size: 190, knob_size: 0.24, pieces: [] },
			swap: { image, cols: 3, rows: 4 },
		},
		editor: { outline: [], cuts: [], shapes: [], pieces: [] },
	};
}
