export function PolygonPieceLegend(props: { tinyPieceCount: number }) {
  return (
    <div className="mb-4 rounded-md border border-border bg-background/70 p-3" data-testid="polygon-piece-legend">
      <div className="mb-2 text-sm font-semibold text-foreground">显示标记</div>
      <div className="flex flex-wrap gap-x-4 gap-y-2 text-xs text-muted-foreground">
        <span className="inline-flex items-center gap-1.5">
          <span className="h-3.5 w-5 rounded-sm border-2 border-dashed border-red-600 bg-red-500/40" />
          小碎片 {props.tinyPieceCount}
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span className="h-3.5 w-5 rounded-sm border-[3px] border-sky-400 bg-sky-400/10" />
          当前选中
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span className="grid h-4 w-4 place-items-center rounded-full bg-emerald-700 text-[9px] font-bold text-white">✓</span>
          Seed
        </span>
      </div>
    </div>
  );
}
