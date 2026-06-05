import { withReservedI18n } from "../lib/strings.js";
import { defaultImagePreset } from "../catalog/service.js";

export type LevelImage = {
	path: string;
	width: number;
	height: number;
	aspect_ratio: number;
	preset: string;
};

export function makeLevelJson(topicId: string, groupId: string, levelId: string, title: string, description = "", image?: Partial<LevelImage>) {
	const width = Number(image?.width || 0);
	const height = Number(image?.height || 0);
	const aspect = Number(image?.aspect_ratio || (width && height ? width / height : defaultImagePreset.aspect_ratio));
	const levelImage: LevelImage = {
		path: String(image?.path || `res://levels/${topicId}/${groupId}/${levelId}/source.jpg`),
		width,
		height,
		aspect_ratio: aspect,
		preset: String(image?.preset || defaultImagePreset.id),
	};
	return {
		version: 3,
		id: levelId,
		topic_id: topicId,
		group_id: groupId,
		title,
		title_i18n: withReservedI18n({}, title),
		description,
		description_i18n: withReservedI18n({}, description),
		image: levelImage,
		background: { type: "color", color: "#F6EBD4" },
		modes: {
			polygon: { pieces: [], generator: null },
			knob: { rows: 8, cols: 8, knob_size: 0.24, pieces: [] },
			swap: { auto: true, max_pieces: 25 },
		},
	};
}

export function normalizeLevelJson(input: any, topicId: string, groupId: string, levelId: string) {
	const title = String(input?.title || levelId);
	const description = String(input?.description || "");
	const imageInput = input?.image || {};
	const base = makeLevelJson(topicId, groupId, levelId, title, description, imageInput);
	return {
		...base,
		...input,
		version: 3,
		id: levelId,
		topic_id: topicId,
		group_id: groupId,
		title,
		title_i18n: withReservedI18n(input?.title_i18n || {}, title),
		description,
		description_i18n: withReservedI18n(input?.description_i18n || {}, description),
		image: {
			...base.image,
			...(input?.image || {}),
			path: String(input?.image?.path || base.image.path),
			width: Number(input?.image?.width || 0),
			height: Number(input?.image?.height || 0),
			aspect_ratio: Number(input?.image?.aspect_ratio || base.image.aspect_ratio),
			preset: String(input?.image?.preset || defaultImagePreset.id),
		},
		background: { ...base.background, ...(input?.background || {}) },
		modes: normalizeModes(input?.modes),
	};
}

export function normalizeModes(input: any) {
	const modes = input && typeof input === "object" ? input : {};
	return {
		...(modes.polygon ? { polygon: { pieces: Array.isArray(modes.polygon.pieces) ? modes.polygon.pieces : [], generator: modes.polygon.generator ?? null } } : {}),
		...(modes.knob
			? {
					knob: {
						rows: Number(modes.knob.rows || 8),
						cols: Number(modes.knob.cols || 8),
						knob_size: Number(modes.knob.knob_size || 0.24),
						pieces: Array.isArray(modes.knob.pieces) ? modes.knob.pieces : [],
					},
				}
			: {}),
		...(modes.swap ? { swap: { auto: modes.swap.auto !== false, max_pieces: Number(modes.swap.max_pieces || 25) } } : {}),
	};
}
