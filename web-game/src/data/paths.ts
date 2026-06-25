export function resPathToUrl(path?: string): string | undefined {
  if (!path) return undefined;
  if (path.startsWith("res://")) {
    return `/${path.slice("res://".length)}`;
  }
  return path;
}

export function normalizeColor(value: string | undefined, fallback: string): string {
  if (!value) return fallback;
  if (/^#[0-9a-f]{6}$/i.test(value)) return value;
  return fallback;
}
