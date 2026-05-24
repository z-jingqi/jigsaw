import type { PendingImageItem, ProcessStepType } from "../../../types";

export function canUseStep(type: ProcessStepType, item?: PendingImageItem) {
  if (!item || item.processed_path) return false;
  if (type === "compress") return !item.compression_stable;
  return !(item.applied_step_types || []).includes(type);
}

export function disabledStepReason(type: ProcessStepType, item?: PendingImageItem) {
  if (!item) return "未选择图片";
  if (item.processed_path) return "请先确认或放弃当前处理结果";
  if (type === "compress" && item.compression_stable) return "压缩后大小不再变化";
  if (type !== "compress" && (item.applied_step_types || []).includes(type)) return "已使用";
  return "";
}
