import { withReservedI18n } from "../lib/strings.js";

export const defaultImagePreset = {
	id: "mobile_portrait_3x4",
	name: "Mobile portrait 3:4",
	aspect_ratio: 0.75,
	default: true,
};

export function makeEmptyCatalog() {
	return {
		version: 3,
		default_locale: "en",
		locales: ["en", "zh", "ja"],
		image_presets: [defaultImagePreset],
		topics: [],
	};
}

export function normalizeCatalog(input: any) {
	const catalog = {
		...makeEmptyCatalog(),
		...(input || {}),
		version: 3,
	};
	const presets = Array.isArray(input?.image_presets) && input.image_presets.length ? input.image_presets : [defaultImagePreset];
	catalog.image_presets = presets.map((preset: any) => ({
		id: String(preset.id || defaultImagePreset.id),
		name: String(preset.name || preset.id || defaultImagePreset.name),
		aspect_ratio: Number(preset.aspect_ratio || defaultImagePreset.aspect_ratio),
		default: Boolean(preset.default),
	}));
	if (!catalog.image_presets.some((preset: any) => preset.default)) {
		catalog.image_presets[0].default = true;
	}
	catalog.topics = [...(Array.isArray(input?.topics) ? input.topics : [])]
		.map((topic: any, topicIndex: number) => normalizeTopic(topic, topicIndex))
		.sort((a: any, b: any) => a.sort_order - b.sort_order);
	return catalog;
}

export function normalizeTopic(topic: any, index = 0) {
	const topicId = String(topic?.id || `topic_${index + 1}`);
	const groupsInput = Array.isArray(topic?.groups) ? topic.groups : [];
	const legacyLevels = Array.isArray(topic?.levels) && topic.levels.length
		? [{ id: "default", name: "Default", sort_order: 0, levels: topic.levels }]
		: [];
	return {
		id: topicId,
		name: String(topic?.name || topicId),
		name_i18n: withReservedI18n(topic?.name_i18n || {}, String(topic?.name || topicId)),
		sort_order: Number(topic?.sort_order ?? index),
		cover: String(topic?.cover || `res://levels/${topicId}/cover.jpg`),
		groups: [...groupsInput, ...legacyLevels]
			.map((group: any, groupIndex: number) => normalizeGroup(group, topicId, groupIndex))
			.sort((a: any, b: any) => a.sort_order - b.sort_order),
		levels: [],
	};
}

export function normalizeGroup(group: any, topicId: string, index = 0) {
	const groupId = String(group?.id || `group_${index + 1}`);
	return {
		id: groupId,
		name: String(group?.name || groupId),
		name_i18n: withReservedI18n(group?.name_i18n || {}, String(group?.name || groupId)),
		sort_order: Number(group?.sort_order ?? index),
		levels: [...(Array.isArray(group?.levels) ? group.levels : [])]
			.map((level: any, levelIndex: number) => normalizeLevelEntry(level, topicId, groupId, levelIndex))
			.sort((a: any, b: any) => a.sort_order - b.sort_order),
	};
}

export function normalizeLevelEntry(level: any, topicId: string, groupId: string, index = 0) {
	const levelId = String(level?.id || `level_${index + 1}`);
	const title = String(level?.title || levelId);
	return {
		id: levelId,
		title,
		title_i18n: withReservedI18n(level?.title_i18n || {}, title),
		sort_order: Number(level?.sort_order ?? index),
		path: String(level?.path || `res://levels/${topicId}/${groupId}/${levelId}/level.json`),
		source: String(level?.source || `res://levels/${topicId}/${groupId}/${levelId}/source.jpg`),
	};
}

export function flattenTopicLevels(topic: any) {
	return (topic.groups || []).flatMap((group: any) => (group.levels || []).map((level: any) => ({ ...level, group_id: group.id, group_name: group.name })));
}

export function findTopic(catalog: any, topicId: string) {
	return (catalog.topics || []).find((topic: any) => topic.id === topicId);
}

export function findGroup(catalog: any, topicId: string, groupId: string) {
	return findTopic(catalog, topicId)?.groups?.find((group: any) => group.id === groupId);
}

export function updateCatalogTopicCover(catalog: any, topicId: string, imageFileName: string) {
	const normalized = normalizeCatalog(catalog);
	const topic = findTopic(normalized, topicId);
	if (topic) topic.cover = `res://levels/${topicId}/${imageFileName}`;
	return normalized;
}
