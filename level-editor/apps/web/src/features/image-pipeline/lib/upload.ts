import type { DataTransferItemWithEntry, FileWithRelativePath, UploadCandidate, WebkitDirectoryEntry, WebkitEntry, WebkitFileEntry } from "../types";

export function cleanFolderName(value: string) {
  return value.trim().replace(/[<>:"/\\|?*\u0000-\u001f]/g, "").replace(/\s+/g, " ").slice(0, 64);
}

export function folderFromPath(pathValue?: string) {
  if (!pathValue) return "";
  const parts = pathValue.split(/[\\/]/).filter(Boolean);
  if (parts.length <= 1) return "";
  return cleanFolderName(parts[parts.length - 2]);
}

export function isImageFile(file: File) {
  return file.type.startsWith("image/") || /\.(png|jpe?g|webp|gif|bmp|avif|svg)$/i.test(file.name);
}

export async function candidatesFromDataTransfer(dataTransfer: DataTransfer): Promise<UploadCandidate[]> {
  const itemEntries = Array.from(dataTransfer.items || [])
    .map((item) => (item as DataTransferItemWithEntry).webkitGetAsEntry?.() as WebkitEntry | null | undefined)
    .filter((entry): entry is WebkitEntry => Boolean(entry));
  const candidates = itemEntries.length
    ? (await Promise.all(itemEntries.map((entry) => candidatesFromEntry(entry, [])))).flat()
    : Array.from(dataTransfer.files || []).map((file) => ({ file, folder: folderFromPath((file as FileWithRelativePath).webkitRelativePath) }));
  return candidates.filter(({ file }) => isImageFile(file));
}

async function candidatesFromEntry(entry: WebkitEntry, ancestors: string[]): Promise<UploadCandidate[]> {
  if (entry.isFile) {
    const file = await fileFromEntry(entry as WebkitFileEntry);
    return isImageFile(file) ? [{ file, folder: cleanFolderName(ancestors[ancestors.length - 1] || "") }] : [];
  }
  if (!entry.isDirectory) return [];
  const nextAncestors = [...ancestors, entry.name];
  const entries = await entriesFromDirectory(entry as WebkitDirectoryEntry);
  const nested = await Promise.all(entries.map((child) => candidatesFromEntry(child, nextAncestors)));
  return nested.flat();
}

function fileFromEntry(entry: WebkitFileEntry) {
  return new Promise<File>((resolve, reject) => entry.file(resolve, reject));
}

async function entriesFromDirectory(entry: WebkitDirectoryEntry) {
  const reader = entry.createReader();
  const entries: WebkitEntry[] = [];
  for (;;) {
    const batch = await new Promise<WebkitEntry[]>((resolve, reject) => reader.readEntries(resolve, reject));
    if (!batch.length) break;
    entries.push(...batch);
  }
  return entries;
}
