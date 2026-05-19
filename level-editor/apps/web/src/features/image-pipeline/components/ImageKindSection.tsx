import type { ReactNode } from "react";

export function ImageKindSection({ title, empty, children }: { title: string; empty: boolean; children: ReactNode }) {
  return (
    <section className="grid gap-2">
      <h3 className="px-1 text-xs font-semibold text-muted">{title}</h3>
      {children}
      {empty && <div className="rounded border border-dashed border-stone-200 px-3 py-2 text-xs text-muted">暂无{title}</div>}
    </section>
  );
}
