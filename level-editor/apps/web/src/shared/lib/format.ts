import type { ImageInfo } from "../../types";

export function formatBytes(bytes: number) {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0B";
  const units = ["B", "KB", "MB", "GB"];
  let value = bytes;
  let index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index += 1;
  }
  return `${value.toFixed(index === 0 ? 0 : 1)}${units[index]}`;
}

export function imageInfoText(info?: ImageInfo) {
  if (!info) return "未知尺寸, 0B";
  const size = info.width && info.height ? `${info.width} x ${info.height}` : "未知尺寸";
  return `${size}, ${formatBytes(info.bytes)}`;
}
