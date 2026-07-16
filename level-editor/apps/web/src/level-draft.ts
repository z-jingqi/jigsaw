import type { LevelCatalog, LevelConfig, SelectedLevel } from "./types";

export function levelDetailsSignature(level: LevelConfig | null) {
  if (!level) return "";
  return JSON.stringify({
    title: level.title,
    title_i18n: level.title_i18n,
    background: level.background,
  });
}

export function restoreCatalogLevelSummary(catalog: LevelCatalog, target: SelectedLevel, level: LevelConfig) {
  return {
    ...catalog,
    topics: catalog.topics.map((topic) =>
      topic.id === target.topicId
        ? {
            ...topic,
            groups: topic.groups.map((group) =>
              group.id === target.groupId
                ? {
                    ...group,
                    levels: group.levels.map((item) =>
                      item.id === target.levelId
                        ? {
                            ...item,
                            title: level.title,
                            title_i18n: level.title_i18n,
                            background_color: level.background.color,
                          }
                        : item,
                    ),
                  }
                : group,
            ),
          }
        : topic,
    ),
  };
}
