import { catmullRomPath, presetShapePoints } from "../../../geometry";
import type { CutTemplate } from "../../../types";
import { WithTooltip } from "../../../components/ui/tooltip";

export const presetTemplates: CutTemplate[] = [
  "circle",
  "star",
  "zigzag",
  "crescent",
  "rectangle",
  "trapezoid",
  "sector",
  "heart",
  "triangle",
  "diamond",
  "pentagon",
  "hexagon",
  "octagon",
  "parallelogram",
  "arrow",
  "cross",
  "shield",
  "leaf",
  "semicircle",
];

export function ShapeButton({ template, onClick }: { template: CutTemplate; onClick: () => void }) {
  return (
    <WithTooltip label={templateName(template)}>
      <button
        className="shapeButton"
        draggable
        onClick={onClick}
        onDragStart={(event) => {
          event.dataTransfer.setData("application/x-jigcat-shape", template);
          event.dataTransfer.effectAllowed = "copy";
        }}
        aria-label={templateName(template)}
      >
        <svg viewBox="0 0 64 64" className="h-10 w-full" aria-hidden="true">
          <path d={shapeIconPath(template)} />
        </svg>
      </button>
    </WithTooltip>
  );
}

function shapeIconPath(template: CutTemplate) {
  return catmullRomPath(presetShapePoints(template, { x: 0, y: 0, width: 64, height: 64 }), shapeTension(template), true);
}

export function shapeTension(template: CutTemplate) {
  return ["star", "zigzag", "knob", "rectangle", "trapezoid", "triangle", "diamond", "pentagon", "hexagon", "octagon", "parallelogram", "arrow", "cross", "shield"].includes(template) ? 0 : 0.25;
}

export function templateName(template: CutTemplate) {
  const names: Record<CutTemplate, string> = {
    knob: "凹凸",
    round: "圆形凸起",
    circle: "圆形",
    star: "五角星",
    blob: "圆润块",
    zigzag: "折线",
    crescent: "月牙",
    rectangle: "矩形",
    trapezoid: "梯形",
    sector: "扇形",
    heart: "桃心",
    triangle: "三角形",
    diamond: "菱形",
    pentagon: "五边形",
    hexagon: "六边形",
    octagon: "八边形",
    parallelogram: "平行四边形",
    arrow: "箭头",
    cross: "十字",
    shield: "盾牌",
    leaf: "叶形",
    semicircle: "半圆",
  };
  return names[template];
}
