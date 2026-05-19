export function nextSequentialId(prefix: string, existingIds: string[]): string {
  const used = new Set(existingIds);
  for (let index = 1; index < 10000; index += 1) {
    const id = `${prefix}_${String(index).padStart(2, "0")}`;
    if (!used.has(id)) return id;
  }
  return `${prefix}_${Date.now().toString(36)}`;
}

export function idFromEnglishName(value: string, fallbackPrefix: string, existingIds: string[] = []) {
  const base =
    value
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9_-]+/g, "_")
      .replace(/^_+|_+$/g, "") || fallbackPrefix;
  const used = new Set(existingIds);
  if (!used.has(base)) return base;
  for (let index = 2; index < 10000; index += 1) {
    const candidate = `${base}_${index}`;
    if (!used.has(candidate)) return candidate;
  }
  return `${base}_${Date.now().toString(36)}`;
}

export function levelKey(topicId: string, levelId: string) {
  return `${topicId}/${levelId}`;
}
