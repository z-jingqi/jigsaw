import { useEffect, useState } from "react";
import * as Dialog from "@radix-ui/react-dialog";
import { X } from "lucide-react";
import { Field } from "../../../shared/ui/Field";
import { Input } from "../../../shared/ui/Input";

export function CreateItemDialog({
  open,
  title,
  description,
  nameLabel,
  defaultName,
  onOpenChange,
  onSubmit,
}: {
  open: boolean;
  title: string;
  description?: string;
  nameLabel: string;
  defaultName: string;
  onOpenChange: (open: boolean) => void;
  onSubmit: (name: string) => boolean;
}) {
  const [name, setName] = useState(defaultName);

  useEffect(() => {
    if (!open) return;
    setName(defaultName);
  }, [defaultName, open]);

  function submit(event: React.FormEvent) {
    event.preventDefault();
    const cleanName = name.trim();
    if (!cleanName) return;
    if (onSubmit(cleanName)) onOpenChange(false);
  }

  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className="dialogOverlay" />
        <Dialog.Content className="dialogContent max-w-md">
          <div className="flex items-start justify-between gap-4">
            <div>
              <Dialog.Title className="text-xl font-semibold text-ink">{title}</Dialog.Title>
              {description && <Dialog.Description className="mt-1 text-sm text-muted">{description}</Dialog.Description>}
            </div>
            <Dialog.Close className="iconBtn" aria-label="关闭">
              <X size={18} />
            </Dialog.Close>
          </div>
          <form className="mt-5 grid gap-3" onSubmit={submit}>
            <Field label={nameLabel}>
              <Input value={name} autoFocus onChange={(event) => setName(event.target.value)} />
            </Field>
            <div className="mt-2 flex justify-end gap-2">
              <Dialog.Close className="btn" type="button">
                取消
              </Dialog.Close>
              <button className="btnPrimary" type="submit">
                创建
              </button>
            </div>
          </form>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
