import type { PendingImageItem } from "../../../types";
import { ImagePreviewCard } from "./ImagePreviewCard";
import { displayName, nameWithExistingExtension } from "../lib/display";

type Props = {
  selectedPending: PendingImageItem | undefined;
  hasProcessedPreview: boolean;
  onRenamePending: (id: string, name: string) => void;
  onChangePendingName: (id: string, name: string) => void;
  onOpenExpandedImage: (index: number) => void;
};

export function PendingImageCenterPanel({
  selectedPending,
  hasProcessedPreview,
  onRenamePending,
  onChangePendingName,
  onOpenExpandedImage,
}: Props) {
  return (
    <main className="grid min-h-0 grid-rows-[auto_1fr] overflow-hidden">
      <div className="flex min-h-14 items-center justify-between gap-3 border-b border-stone-300 bg-[#f7efe2] px-4">
        {selectedPending ? (
          <div className="flex min-w-0 flex-1 items-center gap-2 text-sm text-muted">
            <input
              className="min-w-0 flex-1 truncate rounded border border-transparent bg-transparent px-2 py-1 text-ink outline-none transition focus:border-clay focus:bg-white focus:ring-2 focus:ring-clay/20"
              value={displayName(selectedPending.name)}
              onChange={(event) => onChangePendingName(selectedPending.id, nameWithExistingExtension(selectedPending.name, event.target.value))}
              onBlur={(event) => onRenamePending(selectedPending.id, event.target.value)}
              aria-label="图片名称"
            />
          </div>
        ) : (
          <div className="min-w-0 truncate text-sm text-muted">选择或上传一张图片</div>
        )}
        {selectedPending?.processed_path && <span className="statusBadge statusBadgePending">待确认</span>}
        {selectedPending?.processed && !selectedPending.processed_path && <span className="statusBadge statusBadgeDone">已处理</span>}
      </div>
      <div className="overflow-auto p-12">
        {selectedPending?.url ? (
          hasProcessedPreview && selectedPending.processed_url ? (
            <div className="grid min-h-full items-center gap-6 lg:grid-cols-2">
              <ImagePreviewCard
                title="处理前"
                name={displayName(selectedPending.name)}
                url={selectedPending.url}
                info={selectedPending.source_info}
                onOpen={() => onOpenExpandedImage(0)}
              />
              <ImagePreviewCard
                title="处理后"
                name={displayName(selectedPending.name)}
                url={selectedPending.processed_url}
                info={selectedPending.processed_info}
                onOpen={() => onOpenExpandedImage(1)}
              />
            </div>
          ) : (
            <div className="grid min-h-full place-items-center">
              <ImagePreviewCard
                title="当前图片"
                name={displayName(selectedPending.name)}
                url={selectedPending.url}
                info={selectedPending.source_info}
                onOpen={() => onOpenExpandedImage(0)}
              />
            </div>
          )
        ) : (
          <div className="grid min-h-[360px] w-full place-items-center rounded-md border border-dashed border-stone-300 bg-white/60 text-muted">暂无图片</div>
        )}
      </div>
    </main>
  );
}
