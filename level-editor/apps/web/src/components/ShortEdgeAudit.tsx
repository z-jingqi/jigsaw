import type { ShortEdge } from "../short-edges";
import { Input } from "./ui/input";

export function ShortEdgeOverlay({ edges, activeKey }: { edges: ShortEdge[]; activeKey: string | null }) {
  return <g pointerEvents="none" aria-hidden="true">{edges.map((edge) => <g key={edge.key} data-short-edge={edge.key}>
    <line x1={edge.start[0]} y1={edge.start[1]} x2={edge.end[0]} y2={edge.end[1]} stroke="#fff" strokeWidth={10} vectorEffect="non-scaling-stroke" />
    <line x1={edge.start[0]} y1={edge.start[1]} x2={edge.end[0]} y2={edge.end[1]} stroke={edge.key === activeKey ? "#7c3aed" : "#e11d48"} strokeWidth={5} vectorEffect="non-scaling-stroke" />
    <circle cx={edge.start[0]} cy={edge.start[1]} r={5} fill="#e11d48" />
  </g>)}</g>;
}

export function ShortEdgePanel(props: {
  edges: ShortEdge[]; threshold: number; onThreshold: (value: number) => void;
  includeSampling: boolean; onIncludeSampling: (value: boolean) => void;
  activeKey: string | null; onSelect: (edge: ShortEdge) => void;
}) {
  const { edges, threshold, onThreshold, includeSampling, onIncludeSampling, activeKey, onSelect } = props;
  const visible = edges.filter((edge) => includeSampling || !edge.sampling);
  const samplingCount = edges.filter((edge) => edge.sampling).length;
  return <section className="my-4 rounded-lg border border-border p-3" aria-label="短边检测">
    <h3 className="font-semibold">短边检测 · {visible.length} 条</h3>
    <label className="mt-3 flex items-center gap-2">小于
      <Input aria-label="短边阈值（原图像素）" className="h-8 w-20" type="number" min={0.01} max={1000} step={0.1} value={threshold} onChange={(event) => onThreshold(Number(event.target.value))} />
      <span>原图像素</span>
    </label>
    <label className="my-3 flex items-start gap-2"><input type="checkbox" checked={includeSampling} onChange={(event) => onIncludeSampling(event.target.checked)} />显示疑似曲线/共线采样段（{samplingCount}）</label>
    <p className="mb-2 text-xs text-muted-foreground">共享边只计一次；点击定位碎片。采样识别为启发式，严格检查时请勾选全部分段。仅提示，不自动改变形状。</p>
    <div className="max-h-56 overflow-auto">{visible.length ? visible.map((edge) => <button type="button" key={edge.key} aria-pressed={activeKey === edge.key} className="mb-1 w-full rounded border border-border px-2 py-1 text-left text-xs hover:bg-secondary aria-pressed:bg-secondary" onClick={() => onSelect(edge)}>
      <span className="block break-all">{edge.owners.map((owner) => `${owner.pieceId} · 边 ${owner.pointIndex + 1}`).join(" / ")}</span>
      <span>{edge.length.toFixed(2)} px{edge.length < 0.0001 ? " · 重复顶点" : edge.sampling ? " · 疑似采样段" : ""}</span>
    </button>) : <p className="py-2 text-xs text-muted-foreground">当前阈值下未发现短边。</p>}</div>
  </section>;
}
