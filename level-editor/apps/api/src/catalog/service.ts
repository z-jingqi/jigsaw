import { safeId } from "../lib/sanitize.js";
import { withReservedI18n } from "../lib/strings.js";

export function makeEmptyCatalog() {
	return {
		schema: "jigsaw.catalog.v1",
		version: 1,
		default_locale: "zh-cn",
		locales: ["zh-cn"],
		topics: [],
	};
}

export function normalizeCatalog(input: any) {
	const catalog = {
		...makeEmptyCatalog(),
		...(input || {}),
	};
	catalog.topics = [...(catalog.topics || [])]
		.map((topic, topicIndex) => ({
			id: safeId(topic.id),
			name: String(topic.name ?? topic.id),
			name_i18n: topic.name_i18n || {},
			sort_order: Number(topic.sort_order ?? topicIndex),
			cover: String(topic.cover || ""),
			levels: [...(topic.levels || [])]
				.map((level, levelIndex) => ({
					id: safeId(level.id),
					title: String(level.title ?? level.id),
					title_i18n: level.title_i18n || {},
					sort_order: Number(level.sort_order ?? levelIndex),
					path: String(level.path || `res://levels/${topic.id}/${level.id}/level.json`),
					source: String(level.source || `res://levels/${topic.id}/${level.id}/source.png`),
				}))
				.sort((a, b) => a.sort_order - b.sort_order),
		}))
		.sort((a, b) => a.sort_order - b.sort_order);
	return catalog;
}

export function upsertCatalogLevel(catalog: any, topicId: string, levelId: string, title: string, imageFileName = "source.png", topicName = "") {
	const normalized = normalizeCatalog(catalog);
	const level = {
		id: levelId,
		title,
		title_i18n: withReservedI18n({}, title),
		sort_order: 0,
		path: `res://levels/${topicId}/${levelId}/level.json`,
		source: `res://levels/${topicId}/${levelId}/${imageFileName}`,
	};
	const topicIndex = normalized.topics.findIndex((topic: any) => topic.id === topicId);
	if (topicIndex < 0) {
		normalized.topics.push({
			id: topicId,
			name: topicName || topicId,
			name_i18n: withReservedI18n({}, topicName || topicId),
			sort_order: normalized.topics.length,
			cover: "",
			levels: [{ ...level, sort_order: 0 }],
		});
		return normalizeCatalog(normalized);
	}
	const topic = normalized.topics[topicIndex];
	const existingIndex = topic.levels.findIndex((item: any) => item.id === levelId);
	if (existingIndex >= 0) {
		topic.levels[existingIndex] = { ...topic.levels[existingIndex], ...level, sort_order: topic.levels[existingIndex].sort_order };
	} else {
		topic.levels.push({ ...level, sort_order: topic.levels.length });
	}
	return normalizeCatalog(normalized);
}

export function updateCatalogTopicCover(catalog: any, topicId: string, imageFileName: string) {
	const normalized = normalizeCatalog(catalog);
	const topic = normalized.topics.find((item: any) => item.id === topicId);
	if (topic) topic.cover = `res://levels/${topicId}/${imageFileName}`;
	return normalized;
}
