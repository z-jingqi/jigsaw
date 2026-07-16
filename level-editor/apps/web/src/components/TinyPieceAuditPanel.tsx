import { ScanSearch } from "lucide-react";
import type { TinyPieceAuditResponse } from "../types";
import { Button } from "./ui/button";

export function TinyPieceAuditPanel(props: {
  totalCount: number;
  selectedCount: number;
  running: boolean;
  summary: TinyPieceAuditResponse | null;
  onSelectAll: () => void;
  onInvertSelection: () => void;
  onSelectLastAbnormal: () => void;
  onRun: () => void;
}) {
  return (
    <div className="border-b border-border px-3 py-3" data-testid="tiny-piece-audit-panel">
      <div className="mb-2 flex items-center justify-between gap-2">
        <span className="flex items-center gap-1.5 text-sm font-medium">
          <ScanSearch size={15} />小碎片检测
        </span>
        <span className="text-xs text-muted-foreground">已选 {props.selectedCount}/{props.totalCount}</span>
      </div>
      <div className="grid grid-cols-3 gap-2">
        <Button size="sm" variant="outline" onClick={props.onSelectAll} disabled={props.totalCount === 0 || props.running}>
          全选
        </Button>
        <Button size="sm" variant="outline" onClick={props.onInvertSelection} disabled={props.totalCount === 0 || props.running}>
          反选
        </Button>
        <Button size="sm" variant="outline" onClick={props.onSelectLastAbnormal} disabled={!props.summary?.abnormalCount || props.running}>
          选中上次异常
        </Button>
        <Button className="col-span-3" size="sm" onClick={props.onRun} disabled={props.selectedCount === 0 || props.running}>
          <ScanSearch size={14} />{props.running ? "检测中…" : "检测选中关卡"}
        </Button>
      </div>
      {props.summary ? (
        <div
          className="mt-2 text-center text-sm font-semibold text-destructive"
          role="status"
          data-testid="tiny-piece-audit-summary"
          aria-label={`异常关卡 ${props.summary.abnormalCount}，检测关卡 ${props.summary.checkedCount}`}
        >
          {props.summary.abnormalCount} / {props.summary.checkedCount}
        </div>
      ) : null}
    </div>
  );
}
