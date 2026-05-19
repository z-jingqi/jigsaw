import type { ReactNode } from "react";

export function InlineControl({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="mt-2 grid grid-cols-[56px_1fr] items-center gap-2 text-sm">
      <span className="text-muted">{label}</span>
      {children}
    </label>
  );
}
