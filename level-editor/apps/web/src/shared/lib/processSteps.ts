import { uid } from "../../geometry";
import type { ProcessStep, ProcessStepType, PythonTool } from "../../types";

export const defaultStepTypes: ProcessStepType[] = ["convert_jpg", "remove_background", "trim_transparent", "compress"];

export function createProcessStep(type: ProcessStepType): ProcessStep {
  return {
    id: uid("process"),
    type,
    tolerance: 35,
    padding: 0,
    quality: 88,
    background: "#F6EBD4",
  };
}

export function processStepLabel(type: ProcessStepType) {
  if (type === "convert_jpg") return "转 JPG";
  if (type === "remove_background") return "去背景";
  if (type === "trim_transparent") return "裁透明边";
  return "压缩图片";
}

export function fallbackPythonTool(type: ProcessStepType, description = "已接入图片链式处理。"): PythonTool {
  return {
    name: `${type}.py`,
    label: processStepLabel(type),
    supported: true,
    description,
    stepType: type,
  };
}
