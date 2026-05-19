import { useEffect, useMemo, useRef, useState } from "react";
import { DndContext, PointerSensor, closestCenter, useSensor, useSensors, type DragEndEvent } from "@dnd-kit/core";
import { SortableContext, arrayMove, verticalListSortingStrategy } from "@dnd-kit/sortable";
import { Check, Cloud, Crosshair, FolderPlus, Image as ImageIcon, Pencil, RotateCcw, Trash2, Upload, X } from "lucide-react";
import { toast } from "sonner";
import { useResizableColumns } from "../components/useResizableColumns";
import type { PendingImageItem, PendingImageKind, ProcessStep, ProcessStepType, PythonTool } from "../types";
import { PanelTitle } from "../shared/ui/PanelTitle";
import { defaultStepTypes, createProcessStep, fallbackPythonTool } from "../shared/lib/processSteps";
import { ExpandedImageModal } from "../features/image-pipeline/components/ExpandedImageModal";
import { FolderGroup } from "../features/image-pipeline/components/FolderGroup";
import { ImageKindSection } from "../features/image-pipeline/components/ImageKindSection";
import { ImagePreviewCard } from "../features/image-pipeline/components/ImagePreviewCard";
import { ProcessStepRow } from "../features/image-pipeline/components/ProcessStepRow";
import { PythonToolRow } from "../features/image-pipeline/components/PythonToolRow";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "../components/ui/dropdown-menu";
import { WithTooltip } from "../components/ui/tooltip";
import { googleApiKey, googleClientId, drivePickerMimeTypes } from "../features/image-pipeline/constants";
import { driveSkipMessage, loadScriptOnce } from "../features/image-pipeline/lib/drive";
import { displayName, fileBaseName, kindLabel, nameWithExistingExtension, pendingImageRowId } from "../features/image-pipeline/lib/display";
import { candidatesFromDataTransfer, cleanFolderName, folderFromPath, isImageFile } from "../features/image-pipeline/lib/upload";
import type { ExpandedImage, ExpandedImageItem, FileWithRelativePath, ImagePipelineSelectionState, UploadCandidate } from "../features/image-pipeline/types";
export type { ImagePipelineSelectionState } from "../features/image-pipeline/types";

type Props = {
  onSelectionStateChange?: (state: ImagePipelineSelectionState | null) => void;
};

declare global {
  interface Window {
    gapi?: any;
    google?: any;
  }
}

function canUseStep(type: ProcessStepType, item?: PendingImageItem) {
  if (!item || item.processed_path) return false;
  if (type === "compress") return !item.compression_stable;
  return !(item.applied_step_types || []).includes(type);
}

function disabledStepReason(type: ProcessStepType, item?: PendingImageItem) {
  if (!item) return "未选择图片";
  if (item.processed_path) return "请先确认或放弃当前处理结果";
  if (type === "compress" && item.compression_stable) return "压缩后大小不再变化";
  if (type !== "compress" && (item.applied_step_types || []).includes(type)) return "已使用";
  return "";
}

function ImagePipelinePage({ onSelectionStateChange }: Props) {
  const [pendingImages, setPendingImages] = useState<PendingImageItem[]>([]);
  const [folders, setFolders] = useState<string[]>([]);
  const [selectedImageIds, setSelectedImageIds] = useState<Set<string>>(() => new Set());
  const [selectedFolders, setSelectedFolders] = useState<Set<string>>(() => new Set());
  const [newFolderName, setNewFolderName] = useState("");
  const [creatingFolder, setCreatingFolder] = useState(false);
  const [createFolderKind, setCreateFolderKind] = useState<PendingImageKind>("image");
  const [folderMenuOpen, setFolderMenuOpen] = useState(false);
  const [treeEditMode, setTreeEditMode] = useState(false);
  const [collapsedFolders, setCollapsedFolders] = useState<Set<string>>(() => new Set());
  const [editingImageId, setEditingImageId] = useState("");
  const [editingFolder, setEditingFolder] = useState("");
  const [dragOverFolder, setDragOverFolder] = useState<string | null>(null);
  const [driveImporting, setDriveImporting] = useState(false);
  const [driveKind, setDriveKind] = useState<PendingImageKind>("image");
  const [uploadKind, setUploadKind] = useState<PendingImageKind>("image");
  const [uploadMenuOpen, setUploadMenuOpen] = useState(false);
  const [driveMenuOpen, setDriveMenuOpen] = useState(false);
  const [pythonTools, setPythonTools] = useState<PythonTool[]>([]);
  const [selectedPendingId, setSelectedPendingId] = useState("");
  const [steps, setSteps] = useState<ProcessStep[]>(() => defaultStepTypes.map(createProcessStep));
  const [processing, setProcessing] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const [rejecting, setRejecting] = useState(false);
  const [expandedImage, setExpandedImage] = useState<ExpandedImage | null>(null);
  const [pendingSelectionId, setPendingSelectionId] = useState("");
  const uploadInputRef = useRef<HTMLInputElement | null>(null);
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 6 } }));
  const columns = useResizableColumns({ initialLeft: 360, initialRight: 380, minLeft: 300, maxLeft: 520, minRight: 320, maxRight: 560, minCenter: 460 });

  function setMessage(message: string) {
    toast(message);
  }

  useEffect(() => {
    void loadPendingImages();
    void loadPythonTools();
  }, []);

  useEffect(() => {
    if (!expandedImage) return undefined;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") setExpandedImage(null);
      if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
        event.preventDefault();
        setExpandedImage((current) => {
          if (!current || current.images.length < 2) return current;
          const delta = event.key === "ArrowLeft" ? -1 : 1;
          return { ...current, index: (current.index + delta + current.images.length) % current.images.length };
        });
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [expandedImage]);

  const selectedPending = pendingImages.find((item) => item.id === selectedPendingId) || pendingImages[0];
  const hasAnyUnconfirmed = useMemo(() => pendingImages.some((item) => item.processed_path), [pendingImages]);
  const puzzleGroupedImages = useMemo(() => {
    const groups = new Map<string, PendingImageItem[]>();
    groups.set("", []);
    for (const folder of folders) groups.set(folder, []);
    for (const item of pendingImages.filter((image) => image.kind !== "tablecloth")) {
      const folder = item.folder || "";
      groups.set(folder, [...(groups.get(folder) || []), item]);
    }
    return groups;
  }, [folders, pendingImages]);
  const backgroundGroupedImages = useMemo(() => {
    const groups = new Map<string, PendingImageItem[]>();
    groups.set("", []);
    for (const folder of folders) groups.set(folder, []);
    for (const item of pendingImages.filter((image) => image.kind === "tablecloth")) {
      const folder = item.folder || "";
      groups.set(folder, [...(groups.get(folder) || []), item]);
    }
    return groups;
  }, [folders, pendingImages]);
  const hasSelection = selectedImageIds.size > 0 || selectedFolders.size > 0;
  const selectedStepTypes = useMemo(() => new Set(steps.map((step) => step.type)), [steps]);
  const inactiveTools = useMemo(
    () => pythonTools.filter((tool) => !tool.stepType || !selectedStepTypes.has(tool.stepType)),
    [pythonTools, selectedStepTypes],
  );
  const usableSteps = useMemo(() => steps.filter((step) => canUseStep(step.type, selectedPending)), [selectedPending, steps]);
  const hasProcessedPreview = Boolean(selectedPending?.processed_path && selectedPending.processed_url);

  useEffect(() => {
    if (!selectedPending) {
      onSelectionStateChange?.(null);
      return;
    }
    onSelectionStateChange?.({
      id: selectedPending.id,
      name: displayName(selectedPending.name),
      kind: selectedPending.kind,
      status: selectedPending.processed_path ? "待确认" : selectedPending.processed ? "已处理" : "未处理",
      hasUnconfirmed: hasAnyUnconfirmed,
    });
  }, [hasAnyUnconfirmed, onSelectionStateChange, selectedPending]);

  useEffect(() => {
    if (!hasAnyUnconfirmed) return undefined;
    const onBeforeUnload = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = "";
    };
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, [hasAnyUnconfirmed]);

  useEffect(() => {
    if (treeEditMode) return;
    setSelectedImageIds(new Set());
    setSelectedFolders(new Set());
  }, [treeEditMode]);

  async function loadPendingImages(preferredId?: string) {
    try {
      const response = await fetch("/api/pending-images");
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as { ok?: boolean; items?: PendingImageItem[]; folders?: string[] };
      const items = data.items || [];
      setPendingImages(items);
      setFolders(data.folders || []);
      setSelectedImageIds((current) => new Set([...current].filter((id) => items.some((item) => item.id === id))));
      setSelectedFolders((current) => new Set([...current].filter((folder) => (data.folders || []).includes(folder))));
      setSelectedPendingId((current) => preferredId || (current && items.some((item) => item.id === current) ? current : items[0]?.id || ""));
    } catch (error) {
      setMessage(error instanceof Error ? `加载待处理图片失败：${error.message}` : "加载待处理图片失败");
    }
  }

  async function loadPythonTools() {
    try {
      const response = await fetch("/api/python-tools");
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as { ok?: boolean; tools?: PythonTool[] };
      setPythonTools(data.tools || []);
    } catch (error) {
      setMessage(error instanceof Error ? `加载 Python 工具失败：${error.message}` : "加载 Python 工具失败");
    }
  }

  async function uploadPending(candidates: UploadCandidate[], kind: PendingImageKind = "image") {
    if (!candidates.length) {
      setMessage("没有可上传的图片文件。");
      return;
    }
    const form = new FormData();
    form.append("kind", kind);
    candidates.forEach(({ file, folder }) => {
      form.append("files", file);
      form.append("folders", folder);
    });
    try {
      const response = await fetch("/api/pending-images", { method: "POST", body: form });
      const data = (await response.json()) as {
        ok?: boolean;
        items?: PendingImageItem[];
        skipped?: Array<{ name: string; folder: string; reason: string }>;
        skipped_count?: number;
        error?: string;
      };
      if (!response.ok || !data.ok) throw new Error(data.error || `HTTP ${response.status}`);
      const items = data.items || [];
      const skippedCount = data.skipped_count || data.skipped?.length || 0;
      await loadPendingImages(items[0]?.id);
      if (!items.length && skippedCount) {
        setMessage(`没有新增图片，已跳过 ${skippedCount} 个同名文件。`);
      } else if (skippedCount) {
        setMessage(`已上传 ${items.length} 张图片，跳过 ${skippedCount} 个同名文件。`);
      } else {
        setMessage(`已上传 ${items.length} 张图片。`);
      }
    } catch (error) {
      setMessage(error instanceof Error ? `上传失败：${error.message}` : "上传失败");
    }
  }

  async function importGoogleDriveFiles(accessToken: string, files: Array<{ id: string; name?: string }>, kind: PendingImageKind = "image") {
    if (!files.length) {
      setMessage("没有选择 Drive 图片。");
      return;
    }
    setDriveImporting(true);
    try {
      const response = await fetch("/api/google-drive/import", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ accessToken, kind, files }),
      });
      const data = (await response.json()) as {
        ok?: boolean;
        items?: PendingImageItem[];
        skipped?: Array<{ name: string; folder: string; reason: string }>;
        skipped_count?: number;
        error?: string;
      };
      if (!response.ok || !data.ok) throw new Error(data.error || `HTTP ${response.status}`);
      await loadPendingImages(data.items?.[0]?.id);
      const skippedMessage = driveSkipMessage(data.skipped);
      setMessage(skippedMessage || `已从 Google Drive 导入 ${data.items?.length || 0} 张图片，跳过 ${data.skipped_count || 0} 张。`);
    } catch (error) {
      setMessage(error instanceof Error ? `Google Drive 导入失败：${error.message}` : "Google Drive 导入失败");
    } finally {
      setDriveImporting(false);
    }
  }

  async function openGooglePicker(kind: PendingImageKind = driveKind) {
    if (!googleClientId || !googleApiKey) {
      setMessage("请先配置 VITE_GOOGLE_CLIENT_ID 和 VITE_GOOGLE_API_KEY。");
      return;
    }
    setDriveImporting(true);
    try {
      await Promise.all([
        loadScriptOnce("https://apis.google.com/js/api.js"),
        loadScriptOnce("https://accounts.google.com/gsi/client"),
      ]);
      await new Promise<void>((resolve, reject) => {
        if (!window.gapi) {
          reject(new Error("Google API 未加载"));
          return;
        }
        window.gapi.load("picker", { callback: resolve });
      });
      const tokenClient = window.google.accounts.oauth2.initTokenClient({
        client_id: googleClientId,
        scope: [
          "https://www.googleapis.com/auth/drive.readonly",
          "https://www.googleapis.com/auth/drive.metadata.readonly",
        ].join(" "),
        callback: (tokenResponse: { access_token?: string; error?: string }) => {
          if (tokenResponse.error || !tokenResponse.access_token) {
            setDriveImporting(false);
            setMessage(tokenResponse.error || "Google 授权失败。");
            return;
          }
          const docsView = new window.google.picker.DocsView(window.google.picker.ViewId.DOCS)
            .setIncludeFolders(true)
            .setSelectFolderEnabled(true)
            .setMimeTypes(drivePickerMimeTypes);
          const picker = new window.google.picker.PickerBuilder()
            .setDeveloperKey(googleApiKey)
            .setOAuthToken(tokenResponse.access_token)
            .addView(docsView)
            .enableFeature(window.google.picker.Feature.MULTISELECT_ENABLED)
            .setCallback((data: any) => {
              if (data.action === window.google.picker.Action.CANCEL) {
                setDriveImporting(false);
                return;
              }
              if (data.action !== window.google.picker.Action.PICKED) return;
              const files = (data.docs || [])
                .map((doc: any) => ({
                  id: String(doc.id || ""),
                  name: String(doc.name || doc.title || ""),
                  mimeType: String(doc.mimeType || ""),
                }))
                .filter((file: { id: string }) => file.id);
              setMessage(`已选择 ${files.length} 个 Drive 项目，正在导入...`);
              void importGoogleDriveFiles(tokenResponse.access_token as string, files, kind);
            })
            .build();
          picker.setVisible(true);
        },
      });
      tokenClient.requestAccessToken({ prompt: "" });
    } catch (error) {
      setDriveImporting(false);
      setMessage(error instanceof Error ? `Google Picker 加载失败：${error.message}` : "Google Picker 加载失败");
    }
  }

  function uploadFromFileList(files?: FileList | null, kind: PendingImageKind = "image") {
    const allFiles = Array.from(files || []);
    const candidates = allFiles
      .filter(isImageFile)
      .map((file) => ({
        file,
        folder: folderFromPath((file as FileWithRelativePath).webkitRelativePath),
      }));
    if (!allFiles.length || !candidates.length) {
      setMessage("没有可上传的图片文件。");
      return;
    }
    void uploadPending(candidates, kind);
  }

  function chooseUploadKind(kind: PendingImageKind) {
    setUploadKind(kind);
    setUploadMenuOpen(false);
    window.setTimeout(() => uploadInputRef.current?.click(), 0);
  }

  function chooseDriveKind(kind: PendingImageKind) {
    setDriveKind(kind);
    setDriveMenuOpen(false);
    void openGooglePicker(kind);
  }

  async function uploadFromDrop(event: React.DragEvent, kind: PendingImageKind = "image") {
    event.preventDefault();
    event.currentTarget.classList.remove("border-clay");
    const candidates = await candidatesFromDataTransfer(event.dataTransfer);
    if (!candidates.length) {
      setMessage("没有可上传的图片文件。");
      return;
    }
    void uploadPending(candidates, kind);
  }

  async function renamePending(id: string, name: string) {
    const previous = pendingImages.find((item) => item.id === id);
    const cleanName = nameWithExistingExtension(previous?.name || "", name);
    if (!cleanName || previous?.name === cleanName) {
      setEditingImageId("");
      return;
    }
    try {
      const response = await fetch(`/api/pending-images/${id}`, {
        method: "PATCH",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ name: cleanName }),
      });
      const data = (await response.json()) as { ok?: boolean; item?: PendingImageItem; error?: string };
      if (!response.ok || !data.ok || !data.item) throw new Error(data.error || `HTTP ${response.status}`);
      setPendingImages((current) => current.map((item) => (item.id === id ? data.item as PendingImageItem : item)));
      setEditingImageId("");
      setMessage("已重命名。");
    } catch (error) {
      setMessage(error instanceof Error ? `重命名失败：${error.message}` : "重命名失败");
    }
  }

  async function renameFolder(oldName: string, nextName: string) {
    const cleanName = cleanFolderName(nextName);
    if (!cleanName || cleanName === oldName) {
      setEditingFolder("");
      return;
    }
    try {
      const response = await fetch("/api/pending-folders", {
        method: "PATCH",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ oldName, newName: cleanName }),
      });
      const data = (await response.json()) as { ok?: boolean; items?: PendingImageItem[]; folders?: string[]; error?: string };
      if (!response.ok || !data.ok) throw new Error(data.error || `HTTP ${response.status}`);
      setPendingImages(data.items || []);
      setFolders(data.folders || []);
      setSelectedFolders((current) => {
        const next = new Set([...current].filter((folder) => folder !== oldName));
        if (current.has(oldName)) next.add(cleanName);
        return next;
      });
      setCollapsedFolders((current) => {
        const next = new Set([...current].filter((folder) => folder !== oldName));
        if (current.has(oldName)) next.add(cleanName);
        return next;
      });
      setEditingFolder("");
      setMessage("已重命名文件夹。");
    } catch (error) {
      setMessage(error instanceof Error ? `重命名文件夹失败：${error.message}` : "重命名文件夹失败");
    }
  }

  async function createFolder() {
    const folder = cleanFolderName(newFolderName);
    if (!folder) {
      setMessage("请输入文件夹名称。");
      return;
    }
    try {
      const response = await fetch("/api/pending-folders", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ name: folder }),
      });
      const data = (await response.json()) as { ok?: boolean; folders?: string[]; error?: string };
      if (!response.ok || !data.ok) throw new Error(data.error || `HTTP ${response.status}`);
      setFolders(data.folders || []);
      setNewFolderName("");
      setCreatingFolder(false);
      setCollapsedFolders((current) => {
        const next = new Set(current);
        next.delete(folder);
        return next;
      });
      setMessage(`已创建${kindLabel(createFolderKind)}文件夹。`);
    } catch (error) {
      setMessage(error instanceof Error ? `创建文件夹失败：${error.message}` : "创建文件夹失败");
    }
  }

  async function moveImages(ids: string[], folder: string) {
    if (!ids.length) return;
    try {
      const response = await fetch("/api/pending-images/batch-update", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ ids, folder: folder || null }),
      });
      const data = (await response.json()) as { ok?: boolean; items?: PendingImageItem[]; folders?: string[]; error?: string };
      if (!response.ok || !data.ok) throw new Error(data.error || `HTTP ${response.status}`);
      setPendingImages(data.items || []);
      setFolders(data.folders || []);
      setMessage(folder ? `已移动到 ${folder}。` : "已移动到最外层。");
    } catch (error) {
      setMessage(error instanceof Error ? `移动失败：${error.message}` : "移动失败");
    }
  }

  async function deleteSelected() {
    if (!hasSelection) return;
    try {
      const response = await fetch("/api/pending-images/batch-delete", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ imageIds: [...selectedImageIds], folders: [...selectedFolders] }),
      });
      const data = (await response.json()) as { ok?: boolean; items?: PendingImageItem[]; folders?: string[]; error?: string };
      if (!response.ok || !data.ok) throw new Error(data.error || `HTTP ${response.status}`);
      const items = data.items || [];
      setPendingImages(items);
      setFolders(data.folders || []);
      setSelectedImageIds(new Set());
      setSelectedFolders(new Set());
      setSelectedPendingId((current) => (current && items.some((item) => item.id === current) ? current : items[0]?.id || ""));
      setMessage("已删除所选内容。");
    } catch (error) {
      setMessage(error instanceof Error ? `删除失败：${error.message}` : "删除失败");
    }
  }

  function toggleImageSelection(id: string, checked: boolean) {
    setSelectedImageIds((current) => {
      const next = new Set(current);
      if (checked) next.add(id);
      else next.delete(id);
      return next;
    });
  }

  function toggleFolderSelection(folder: string, checked: boolean) {
    setSelectedFolders((current) => {
      const next = new Set(current);
      if (checked) next.add(folder);
      else next.delete(folder);
      return next;
    });
  }

  function dragImageIds(item: PendingImageItem) {
    return selectedImageIds.has(item.id) ? [...selectedImageIds] : [item.id];
  }

  function resetStepsToDefault() {
    setSteps(defaultStepTypes.map(createProcessStep));
    setMessage("工具链已恢复默认值。");
  }

  function requestSelectPending(id: string) {
    if (id === selectedPending?.id) return;
    if (selectedPending?.processed_path) {
      setPendingSelectionId(id);
      return;
    }
    setSelectedPendingId(id);
  }

  function confirmPendingSelection() {
    if (pendingSelectionId) setSelectedPendingId(pendingSelectionId);
    setPendingSelectionId("");
  }

  function cancelCreateFolder() {
    setNewFolderName("");
    setCreatingFolder(false);
  }

  function openCreateFolderDialog(kind: PendingImageKind) {
    setCreateFolderKind(kind);
    setNewFolderName("");
    setCreatingFolder(true);
    setFolderMenuOpen(false);
  }

  function toggleFolderCollapse(folder: string) {
    setCollapsedFolders((current) => {
      const next = new Set(current);
      if (next.has(folder)) next.delete(folder);
      else next.add(folder);
      return next;
    });
  }

  function locateSelectedPending() {
    if (!selectedPending) return;
    const folder = selectedPending.folder || "";
    if (folder) {
      setCollapsedFolders((current) => {
        const next = new Set(current);
        next.delete(folder);
        return next;
      });
    }
    window.setTimeout(() => {
      document.getElementById(pendingImageRowId(selectedPending.id))?.scrollIntoView({ block: "center", behavior: "smooth" });
    }, 0);
  }

  function expandedImagesForSelected(): ExpandedImageItem[] {
    if (!selectedPending?.url) return [];
    const name = fileBaseName(selectedPending.name);
    const images: ExpandedImageItem[] = [{ title: hasProcessedPreview ? "处理前" : "当前图片", name, url: selectedPending.url, info: selectedPending.source_info }];
    if (hasProcessedPreview && selectedPending.processed_url) {
      images.push({ title: "处理后", name, url: selectedPending.processed_url, info: selectedPending.processed_info });
    }
    return images;
  }

  function openExpandedImage(index: number) {
    const images = expandedImagesForSelected();
    if (!images.length) return;
    setExpandedImage({ images, index: Math.min(Math.max(index, 0), images.length - 1) });
  }

  function switchExpandedImage(delta: number) {
    setExpandedImage((current) => {
      if (!current || current.images.length < 2) return current;
      const nextIndex = current.index + delta;
      if (nextIndex < 0 || nextIndex >= current.images.length) return current;
      return { ...current, index: nextIndex };
    });
  }

  function stepPayload() {
    return usableSteps.map(({ id: _id, ...step }) => step);
  }

  async function processSelected() {
    if (!selectedPending) {
      setMessage("请先选择一张待处理图片。");
      return;
    }
    if (selectedPending.processed_path) {
      setMessage("这张图片有待确认的处理结果，请先对比并确认。");
      return;
    }
    if (!usableSteps.length) {
      setMessage("当前没有可用的处理工具。");
      return;
    }
    setProcessing(true);
    try {
      const response = await fetch(`/api/pending-images/${selectedPending.id}/process`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ steps: stepPayload() }),
      });
      const data = (await response.json()) as { ok?: boolean; item?: PendingImageItem; error?: string };
      if (!response.ok || !data.ok || !data.item) throw new Error(data.error || `HTTP ${response.status}`);
      setPendingImages((current) => current.map((item) => (item.id === data.item?.id ? data.item as PendingImageItem : item)));
      setMessage("处理完成，请对比后确认是否使用处理后的图片。");
    } catch (error) {
      setMessage(error instanceof Error ? `处理失败：${error.message}` : "处理失败");
    } finally {
      setProcessing(false);
    }
  }

  async function confirmProcessed() {
    if (!selectedPending?.processed_path) {
      setMessage("当前图片没有待确认的处理结果。");
      return;
    }
    setConfirming(true);
    try {
      const response = await fetch(`/api/pending-images/${selectedPending.id}/confirm-processed`, { method: "POST" });
      const data = (await response.json()) as { ok?: boolean; item?: PendingImageItem; error?: string };
      if (!response.ok || !data.ok || !data.item) throw new Error(data.error || `HTTP ${response.status}`);
      setPendingImages((current) => current.map((item) => (item.id === data.item?.id ? data.item as PendingImageItem : item)));
      setMessage("已确认处理结果，原图已删除并替换为处理后的图片。");
    } catch (error) {
      setMessage(error instanceof Error ? `确认失败：${error.message}` : "确认失败");
    } finally {
      setConfirming(false);
    }
  }

  async function rejectProcessed() {
    if (!selectedPending?.processed_path) {
      setMessage("当前图片没有待放弃的处理结果。");
      return;
    }
    setRejecting(true);
    try {
      const response = await fetch(`/api/pending-images/${selectedPending.id}/reject-processed`, { method: "POST" });
      const data = (await response.json()) as { ok?: boolean; item?: PendingImageItem; error?: string };
      if (!response.ok || !data.ok || !data.item) throw new Error(data.error || `HTTP ${response.status}`);
      setPendingImages((current) => current.map((item) => (item.id === data.item?.id ? data.item as PendingImageItem : item)));
      setMessage("已放弃处理结果，可以继续调整工具后重新处理。");
    } catch (error) {
      setMessage(error instanceof Error ? `放弃失败：${error.message}` : "放弃失败");
    } finally {
      setRejecting(false);
    }
  }

  function addStep(type: ProcessStepType) {
    setSteps((current) => (current.some((step) => step.type === type) ? current : [...current, createProcessStep(type)]));
  }

  function updateStep(id: string, patch: Partial<ProcessStep>) {
    setSteps((current) => current.map((step) => (step.id === id ? { ...step, ...patch } : step)));
  }

  function removeStep(id: string) {
    setSteps((current) => current.filter((step) => step.id !== id));
  }

  function onStepDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || active.id === over.id) return;
    setSteps((current) => {
      const oldIndex = current.findIndex((step) => step.id === active.id);
      const newIndex = current.findIndex((step) => step.id === over.id);
      if (oldIndex < 0 || newIndex < 0) return current;
      return arrayMove(current, oldIndex, newIndex);
    });
  }

  function renderFolderGroups(grouped: Map<string, PendingImageItem[]>, sectionId: string) {
    const rootItems = grouped.get("") || [];
    const visibleFolders = folders.filter((folder) => (grouped.get(folder) || []).length > 0);
    return (
      <>
        {rootItems.length > 0 && (
          <FolderGroup
            folder=""
            label="未分组"
            items={rootItems}
            droppable={false}
            collapsed={false}
            editMode={treeEditMode}
            selectedPendingId={selectedPending?.id || ""}
            selectedImageIds={selectedImageIds}
            selectedFolders={selectedFolders}
            dragOverFolder={dragOverFolder}
            onSelectPending={requestSelectPending}
            onToggleImage={toggleImageSelection}
            onToggleFolder={toggleFolderSelection}
            onToggleCollapsed={toggleFolderCollapse}
            editingImageId={editingImageId}
            editingFolder={editingFolder}
            onStartRenameImage={setEditingImageId}
            onStartRenameFolder={setEditingFolder}
            onRenameImage={renamePending}
            onRenameFolder={renameFolder}
            onMoveImages={moveImages}
            onDragStart={(item, event) => event.dataTransfer.setData("application/x-jigcat-pending-ids", JSON.stringify(dragImageIds(item)))}
            onDragOverFolder={setDragOverFolder}
          />
        )}
        {visibleFolders.map((folder) => (
          <FolderGroup
            key={`${sectionId}:${folder}`}
            folder={folder}
            label={folder}
            items={grouped.get(folder) || []}
            droppable
            collapsed={collapsedFolders.has(folder)}
            editMode={treeEditMode}
            selectedPendingId={selectedPending?.id || ""}
            selectedImageIds={selectedImageIds}
            selectedFolders={selectedFolders}
            dragOverFolder={dragOverFolder}
            onSelectPending={requestSelectPending}
            onToggleImage={toggleImageSelection}
            onToggleFolder={toggleFolderSelection}
            onToggleCollapsed={toggleFolderCollapse}
            editingImageId={editingImageId}
            editingFolder={editingFolder}
            onStartRenameImage={setEditingImageId}
            onStartRenameFolder={setEditingFolder}
            onRenameImage={renamePending}
            onRenameFolder={renameFolder}
            onMoveImages={moveImages}
            onDragStart={(item, event) => event.dataTransfer.setData("application/x-jigcat-pending-ids", JSON.stringify(dragImageIds(item)))}
            onDragOverFolder={setDragOverFolder}
          />
        ))}
      </>
    );
  }

  return (
    <div className="grid h-full min-h-0 overflow-hidden bg-linen text-ink" style={{ gridTemplateColumns: columns.gridTemplateColumns }}>
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
          <DropdownMenu open={uploadMenuOpen} onOpenChange={setUploadMenuOpen}>
            <DropdownMenuTrigger asChild>
              <button
                className="fileButton"
                onMouseEnter={() => setUploadMenuOpen(true)}
                onDragOver={(event) => {
                  event.preventDefault();
                  event.currentTarget.classList.add("border-clay");
                }}
                onDragLeave={(event) => event.currentTarget.classList.remove("border-clay")}
                onDrop={(event) => void uploadFromDrop(event, uploadKind)}
              >
                <Upload size={16} />
                上传
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent onMouseLeave={() => setUploadMenuOpen(false)}>
              <DropdownMenuItem onSelect={() => chooseUploadKind("image")}>拼图图片</DropdownMenuItem>
              <DropdownMenuItem onSelect={() => chooseUploadKind("tablecloth")}>背景图片</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
          <input
            ref={uploadInputRef}
            hidden
            multiple
            type="file"
            accept="image/*"
            onChange={(event) => {
              uploadFromFileList(event.target.files, uploadKind);
              event.currentTarget.value = "";
            }}
            {...({ webkitdirectory: "", directory: "" } as Record<string, string>)}
          />
        </section>

        <section className="mt-5 grid gap-3">
          <PanelTitle>Google Drive</PanelTitle>
          <DropdownMenu open={driveMenuOpen} onOpenChange={setDriveMenuOpen}>
            <DropdownMenuTrigger asChild>
              <button className="btnPrimary" disabled={driveImporting} onMouseEnter={() => setDriveMenuOpen(true)}>
                <Cloud size={16} />
                {driveImporting ? "连接中..." : "Google Drive"}
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent onMouseLeave={() => setDriveMenuOpen(false)}>
              <DropdownMenuItem onSelect={() => chooseDriveKind("image")}>拼图图片</DropdownMenuItem>
              <DropdownMenuItem onSelect={() => chooseDriveKind("tablecloth")}>背景图片</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
          <DropdownMenu open={folderMenuOpen} onOpenChange={setFolderMenuOpen}>
            <DropdownMenuTrigger asChild>
              <button className="btn w-full" onMouseEnter={() => setFolderMenuOpen(true)}>
                <FolderPlus size={16} />
                创建文件夹
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent onMouseLeave={() => setFolderMenuOpen(false)}>
              <DropdownMenuItem onSelect={() => openCreateFolderDialog("image")}>拼图图片</DropdownMenuItem>
              <DropdownMenuItem onSelect={() => openCreateFolderDialog("tablecloth")}>背景图片</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </section>

        <section className="mt-5 grid gap-3">
          <div className="flex items-center justify-between gap-2">
            <div />
            <div className="flex items-center gap-2">
              <WithTooltip label="定位当前图片">
                <button className="iconBtn" disabled={!selectedPending} onClick={locateSelectedPending} aria-label="定位当前图片">
                  <Crosshair size={16} />
                </button>
              </WithTooltip>
              <WithTooltip label={treeEditMode ? "退出编辑模式" : "编辑文件夹树"}>
                <button
                  className={treeEditMode ? "iconBtnActive" : "iconBtn"}
                  onClick={() => setTreeEditMode((current) => !current)}
                  aria-label={treeEditMode ? "退出编辑模式" : "编辑文件夹树"}
                >
                  <Pencil size={16} />
                </button>
              </WithTooltip>
              {treeEditMode && hasSelection && (
                <WithTooltip label="删除所选">
                  <button className="iconBtnDanger" onClick={() => void deleteSelected()} aria-label="删除所选">
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
                  {renderFolderGroups(puzzleGroupedImages, "puzzle")}
                </ImageKindSection>
                <ImageKindSection title="背景图片" empty={!pendingImages.some((item) => item.kind === "tablecloth")}>
                  {renderFolderGroups(backgroundGroupedImages, "background")}
                </ImageKindSection>
              </>
            ) : (
              <>
                <div className="rounded-md border border-dashed border-stone-300 bg-white/70 px-3 py-4 text-sm text-muted">暂无图片。</div>
              </>
            )}
          </div>
        </section>
        </div>
      </aside>

      <div className="cursor-col-resize bg-stone-300/70 transition hover:bg-clay" onPointerDown={columns.startLeftResize} />

      <main className="grid min-h-0 grid-rows-[auto_1fr] overflow-hidden">
        <div className="flex min-h-14 items-center justify-between gap-3 border-b border-stone-300 bg-[#f7efe2] px-4">
          {selectedPending ? (
            <div className="flex min-w-0 flex-1 items-center gap-2 text-sm text-muted">
              <input
                className="min-w-0 flex-1 truncate rounded border border-transparent bg-transparent px-2 py-1 text-ink outline-none transition focus:border-clay focus:bg-white focus:ring-2 focus:ring-clay/20"
                value={displayName(selectedPending.name)}
                onChange={(event) =>
                  setPendingImages((current) => current.map((item) => (item.id === selectedPending.id ? { ...item, name: nameWithExistingExtension(item.name, event.target.value) } : item)))
                }
                onBlur={(event) => void renamePending(selectedPending.id, event.target.value)}
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
                  onOpen={() => openExpandedImage(0)}
                />
                <ImagePreviewCard
                  title="处理后"
                  name={displayName(selectedPending.name)}
                  url={selectedPending.processed_url}
                  info={selectedPending.processed_info}
                  onOpen={() => openExpandedImage(1)}
                />
              </div>
            ) : (
              <div className="grid min-h-full place-items-center">
                <ImagePreviewCard
                  title="当前图片"
                  name={displayName(selectedPending.name)}
                  url={selectedPending.url}
                  info={selectedPending.source_info}
                  onOpen={() => openExpandedImage(0)}
                />
              </div>
            )
          ) : (
            <div className="grid min-h-[360px] w-full place-items-center rounded-md border border-dashed border-stone-300 bg-white/60 text-muted">暂无图片</div>
          )}
        </div>
      </main>

      <div className="cursor-col-resize bg-stone-300/70 transition hover:bg-clay" onPointerDown={columns.startRightResize} />

      <aside className="min-h-0 overflow-auto border-l border-stone-300 bg-paper p-4">
        <section className="grid gap-3">
          <div className="flex items-center justify-between gap-2">
            <PanelTitle>处理链</PanelTitle>
            <button className="btn !min-h-8 px-2 py-1 text-xs" onClick={resetStepsToDefault}>
              <RotateCcw size={14} />
              恢复默认
            </button>
          </div>
          <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onStepDragEnd}>
            <SortableContext items={steps.map((step) => step.id)} strategy={verticalListSortingStrategy}>
              <div className="grid gap-2">
                {steps.map((step) => (
                  <ProcessStepRow
                    key={step.id}
                    step={step}
                    tool={pythonTools.find((candidate) => candidate.stepType === step.type) || fallbackPythonTool(step.type)}
                    disabled={!canUseStep(step.type, selectedPending)}
                    disabledReason={disabledStepReason(step.type, selectedPending)}
                    onUpdate={(patch) => updateStep(step.id, patch)}
                    onEnabledChange={(checked) => {
                      if (!checked) removeStep(step.id);
                    }}
                  />
                ))}
              </div>
            </SortableContext>
          </DndContext>
          <div className="grid gap-2">
            {inactiveTools.map((tool) => (
              <PythonToolRow
                key={tool.name}
                tool={tool}
                disabled={Boolean(tool.stepType && !canUseStep(tool.stepType, selectedPending))}
                disabledReason={tool.stepType ? disabledStepReason(tool.stepType, selectedPending) : ""}
                onEnabledChange={(checked) => {
                  if (checked && tool.stepType) addStep(tool.stepType);
                }}
              />
            ))}
          </div>
          <button className="btnPrimary" disabled={processing || !selectedPending || hasProcessedPreview || !usableSteps.length} onClick={processSelected}>
            <Check size={16} />
            {processing ? "处理中..." : "处理当前图片"}
          </button>
          {selectedPending?.processed_path && (
            <div className="grid grid-cols-2 gap-2">
              <button className="btnPrimary" disabled={confirming} onClick={() => void confirmProcessed()}>
                <Check size={16} />
                {confirming ? "确认中..." : "确认使用"}
              </button>
              <button className="btn" disabled={rejecting} onClick={() => void rejectProcessed()}>
                {rejecting ? "放弃中..." : "放弃并继续"}
              </button>
            </div>
          )}
        </section>

      </aside>

      {expandedImage && (
        <ExpandedImageModal gallery={expandedImage} onClose={() => setExpandedImage(null)} onSwitch={switchExpandedImage} />
      )}
      {creatingFolder && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-black/35 px-4">
          <div className="w-full max-w-md rounded-md border border-stone-300 bg-paper p-5 text-ink shadow-xl">
            <h2 className="text-lg font-semibold">创建{kindLabel(createFolderKind)}文件夹</h2>
            <p className="mt-2 text-sm text-muted">文件夹可用于整理{kindLabel(createFolderKind)}。</p>
            <input
              className="input mt-4"
              autoFocus
              value={newFolderName}
              placeholder="新文件夹"
              onChange={(event) => setNewFolderName(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter") void createFolder();
                if (event.key === "Escape") cancelCreateFolder();
              }}
            />
            <div className="mt-5 grid grid-cols-2 gap-2">
              <button className="btn" onClick={cancelCreateFolder}>
                取消
              </button>
              <button className="btnPrimary" onClick={() => void createFolder()}>
                <Check size={16} />
                创建
              </button>
            </div>
          </div>
        </div>
      )}
      {pendingSelectionId && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-black/35 px-4">
          <div className="w-full max-w-md rounded-md border border-stone-300 bg-paper p-5 text-ink shadow-xl">
            <h2 className="text-lg font-semibold">当前处理结果尚未确认</h2>
            <p className="mt-2 text-sm text-muted">切换图片前，请确认或放弃当前处理结果。继续切换会保留当前待确认结果，但你之后需要回到这张图片处理。</p>
            <div className="mt-5 grid grid-cols-2 gap-2">
              <button className="btn" onClick={() => setPendingSelectionId("")}>
                留在当前
              </button>
              <button className="btnPrimary" onClick={confirmPendingSelection}>
                继续切换
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default ImagePipelinePage;
