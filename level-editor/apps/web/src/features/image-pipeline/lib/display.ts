export function kindLabel(kind: string) {
  return kind === "tablecloth" ? "背景图片" : "拼图图片";
}

export function fileBaseName(name: string) {
  return name.split(/[\\/]/).filter(Boolean).pop() || name;
}

export function displayName(name: string) {
  return fileBaseName(name).replace(/\.[^.]+$/, "");
}

export function nameWithExistingExtension(previousName: string, nextDisplayName: string) {
  const cleanName = nextDisplayName.trim();
  if (!cleanName) return previousName;
  if (/\.[^.\\/]+$/.test(cleanName)) return cleanName;
  const extension = previousName.match(/(\.[^.\\/]+)$/)?.[1] || "";
  return `${cleanName}${extension}`;
}

export function pendingImageRowId(id: string) {
  return `pending-image-${id}`;
}
