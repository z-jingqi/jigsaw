export function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="grid gap-1.5 text-sm text-muted">
      {label}
      {children}
    </label>
  );
}
