import type { RefObject } from "react";
import { Cloud, Crosshair, FolderPlus, Image as ImageIcon, Pencil, Trash2, Upload } from "lucide-react";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "../../../components/ui/dropdown-menu";
import { WithTooltip } from "../../../components/ui/tooltip";
import { PanelTitle } from "../../../shared/ui/PanelTitle";
import type { PendingImageItem, PendingImageKind } from "../../../types";
import { ImageKindSection } from "./ImageKindSection";

type Props = {
  uploadInputRef: RefObject<HTMLInputElement | null>;
  uploadKind: PendingImageKind;
  uploadMenuOpen: boolean;
  onUploadMenuOpenChange: (open: boolean) => void;
  onChooseUploadKind: (kind: PendingImageKind) => void;
  onUploadFromDrop: (event: React.DragEvent, kind: PendingImageKind) => void;
  onUploadFromFileList: (files: FileList | null, kind: PendingImageKind) => void;
  driveImporting: boolean;
  driveMenuOpen: boolean;
  onDriveMenuOpenChange: (open: boolean) => void;
  onChooseDriveKind: (kind: PendingImageKind) => void;
  folderMenuOpen: boolean;
  onFolderMenuOpenChange: (open: boolean) => void;
  onOpenCreateFolderDialog: (kind: PendingImageKind) => void;
  selectedPending: PendingImageItem | undefined;
  onLocateSelectedPending: () => void;
  treeEditMode: boolean;
  onToggleTreeEditMode: () => void;
  hasSelection: boolean;
  onDeleteSelected: () => void;
  pendingImages: PendingImageItem[];
  folders: string[];
  renderPuzzleGroups: () => React.ReactNode;
  renderBackgroundGroups: () => React.ReactNode;
};

export function PendingImagesAside({
  uploadInputRef,
  uploadKind,
  uploadMenuOpen,
  onUploadMenuOpenChange,
  onChooseUploadKind,
  onUploadFromDrop,
  onUploadFromFileList,
  driveImporting,
  driveMenuOpen,
  onDriveMenuOpenChange,
  onChooseDriveKind,
  folderMenuOpen,
  onFolderMenuOpenChange,
  onOpenCreateFolderDialog,
  selectedPending,
  onLocateSelectedPending,
  treeEditMode,
  onToggleTreeEditMode,
  hasSelection,
  onDeleteSelected,
  pendingImages,
  folders,
  renderPuzzleGroups,
  renderBackgroundGroups,
}: Props) {
  return (
    <aside className="flex min-h-0 flex-col border-r border-stone-300 bg-paper">
      <div className="flex items-start gap-3 border-b border-stone-300 p-4">
        <ImageIcon className="mt-1 text-clay" size={22} />
        <div>
          <h1 className="text-xl font-semibold">图片处理</h1>
          <p className="text-sm text-muted">待处理图片 / 工具链</p>
        </div>
      </div>
      <div className="min-h-0 flex-1 overflow-auto p-4 pt-0">
        <section className="mt-5 grid gap-3">
          <PanelTitle>上传</PanelTitle>
          <DropdownMenu open={uploadMenuOpen} onOpenChange={onUploadMenuOpenChange}>
            <DropdownMenuTrigger asChild>
              <button
                className="fileButton"
                onMouseEnter={() => onUploadMenuOpenChange(true)}
                onDragOver={(event) => {
                  event.preventDefault();
                  event.currentTarget.classList.add("border-clay");
                }}
                onDragLeave={(event) => event.currentTarget.classList.remove("border-clay")}
                onDrop={(event) => onUploadFromDrop(event, uploadKind)}
              >
                <Upload size={16} />
                上传
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent onMouseLeave={() => onUploadMenuOpenChange(false)}>
              <DropdownMenuItem onSelect={() => onChooseUploadKind("image")}>拼图图片</DropdownMenuItem>
              <DropdownMenuItem onSelect={() => onChooseUploadKind("tablecloth")}>背景图片</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
          <input
            ref={uploadInputRef}
            hidden
            multiple
            type="file"
            accept="image/*"
            onChange={(event) => {
              onUploadFromFileList(event.target.files, uploadKind);
              event.currentTarget.value = "";
            }}
            {...({ webkitdirectory: "", directory: "" } as Record<string, string>)}
          />
        </section>

        <section className="mt-5 grid gap-3">
          <PanelTitle>Google Drive</PanelTitle>
          <DropdownMenu open={driveMenuOpen} onOpenChange={onDriveMenuOpenChange}>
            <DropdownMenuTrigger asChild>
              <button className="btnPrimary" disabled={driveImporting} onMouseEnter={() => onDriveMenuOpenChange(true)}>
                <Cloud size={16} />
                {driveImporting ? "连接中..." : "Google Drive"}
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent onMouseLeave={() => onDriveMenuOpenChange(false)}>
              <DropdownMenuItem onSelect={() => onChooseDriveKind("image")}>拼图图片</DropdownMenuItem>
              <DropdownMenuItem onSelect={() => onChooseDriveKind("tablecloth")}>背景图片</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
          <DropdownMenu open={folderMenuOpen} onOpenChange={onFolderMenuOpenChange}>
            <DropdownMenuTrigger asChild>
              <button className="btn w-full" onMouseEnter={() => onFolderMenuOpenChange(true)}>
                <FolderPlus size={16} />
                创建文件夹
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent onMouseLeave={() => onFolderMenuOpenChange(false)}>
              <DropdownMenuItem onSelect={() => onOpenCreateFolderDialog("image")}>拼图图片</DropdownMenuItem>
              <DropdownMenuItem onSelect={() => onOpenCreateFolderDialog("tablecloth")}>背景图片</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </section>

        <section className="mt-5 grid gap-3">
          <div className="flex items-center justify-between gap-2">
            <div />
            <div className="flex items-center gap-2">
              <WithTooltip label="定位当前图片">
                <button className="iconBtn" disabled={!selectedPending} onClick={onLocateSelectedPending} aria-label="定位当前图片">
                  <Crosshair size={16} />
                </button>
              </WithTooltip>
              <WithTooltip label={treeEditMode ? "退出编辑模式" : "编辑文件夹树"}>
                <button
                  className={treeEditMode ? "iconBtnActive" : "iconBtn"}
                  onClick={onToggleTreeEditMode}
                  aria-label={treeEditMode ? "退出编辑模式" : "编辑文件夹树"}
                >
                  <Pencil size={16} />
                </button>
              </WithTooltip>
              {treeEditMode && hasSelection && (
                <WithTooltip label="删除所选">
                  <button className="iconBtnDanger" onClick={onDeleteSelected} aria-label="删除所选">
                    <Trash2 size={16} />
                  </button>
                </WithTooltip>
              )}
            </div>
          </div>
          <div className="grid gap-3 pr-1">
            {pendingImages.length || folders.length ? (
              <>
                <ImageKindSection title="拼图图片" empty={!pendingImages.some((item) => item.kind !== "tablecloth")}>
                  {renderPuzzleGroups()}
                </ImageKindSection>
                <ImageKindSection title="背景图片" empty={!pendingImages.some((item) => item.kind === "tablecloth")}>
                  {renderBackgroundGroups()}
                </ImageKindSection>
              </>
            ) : (
              <div className="rounded-md border border-dashed border-stone-300 bg-white/70 px-3 py-4 text-sm text-muted">暂无图片。</div>
            )}
          </div>
        </section>
      </div>
    </aside>
  );
}
