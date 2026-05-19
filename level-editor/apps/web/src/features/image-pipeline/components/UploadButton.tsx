import { Upload } from "lucide-react";
import type { PendingImageKind } from "../../../types";

export function UploadButton({
  label,
  onFiles,
  onDropFiles,
}: {
  label: string;
  onFiles: (files?: FileList | null, kind?: PendingImageKind) => void;
  onDropFiles: (event: React.DragEvent, kind?: PendingImageKind) => Promise<void>;
}) {
  return (
    <label
      className="fileButton"
      onDragOver={(event) => {
        event.preventDefault();
        event.currentTarget.classList.add("border-clay");
      }}
      onDragLeave={(event) => event.currentTarget.classList.remove("border-clay")}
      onDrop={(event) => void onDropFiles(event, label.includes("背景") ? "tablecloth" : "image")}
    >
      <Upload size={16} />
      {label}
      <input
        hidden
        multiple
        type="file"
        accept="image/*"
        onChange={(event) => onFiles(event.target.files, label.includes("背景") ? "tablecloth" : "image")}
        {...({ webkitdirectory: "", directory: "" } as Record<string, string>)}
      />
    </label>
  );
}
