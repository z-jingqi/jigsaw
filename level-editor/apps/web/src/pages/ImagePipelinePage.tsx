import { useEffect, useMemo, useState } from "react";
import { DndContext, PointerSensor, closestCenter, useSensor, useSensors, type DragEndEvent } from "@dnd-kit/core";
import { SortableContext, arrayMove, verticalListSortingStrategy, useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { Check, CheckCircle2, ChevronDown, ChevronLeft, ChevronRight, Cloud, Crosshair, FolderPlus, Image as ImageIcon, Pencil, RotateCcw, Trash2, Upload, X } from "lucide-react";
import { useResizableColumns } from "../components/useResizableColumns";
import { uid } from "../geometry";
import type { ImageInfo, PendingImageItem, PendingImageKind, ProcessStep, ProcessStepType, PythonTool } from "../types";

export type ImagePipelineSelectionState = {
  id: string;
  name: string;
  kind: PendingImageKind;
  status: "未处理" | "已处理" | "待确认";
  hasUnconfirmed: boolean;
};

type Props = {
  onSelectionStateChange?: (state: ImagePipelineSelectionState | null) => void;
};

type ExpandedImageItem = {
  url: string;
  title: string;
  info?: ImageInfo;
};

type ExpandedImage = {
  images: ExpandedImageItem[];
  index: number;
};

type UploadCandidate = {
  file: File;
  folder: string;
};

type FileWithRelativePath = File & {
  webkitRelativePath?: string;
};

type WebkitEntry = {
  isFile: boolean;
  isDirectory: boolean;
  name: string;
};

type WebkitFileEntry = WebkitEntry & {
  file: (success: (file: File) => void, error?: (error: DOMException) => void) => void;
};

type WebkitDirectoryEntry = WebkitEntry & {
  createReader: () => {
    readEntries: (success: (entries: WebkitEntry[]) => void, error?: (error: DOMException) => void) => void;
  };
};

type DataTransferItemWithEntry = DataTransferItem & {
  webkitGetAsEntry?: () => unknown;
};

declare global {
  interface Window {
    gapi?: any;
    google?: any;
  }
}

const defaultStepTypes: ProcessStepType[] = ["convert_jpg", "remove_background", "trim_transparent", "compress"];
const viteEnv = (import.meta as unknown as { env?: Record<string, string | undefined> }).env || {};
const googleClientId = viteEnv.VITE_GOOGLE_CLIENT_ID;
const googleApiKey = viteEnv.VITE_GOOGLE_API_KEY;
const googleDriveFolderMime = "application/vnd.google-apps.folder";
const drivePickerMimeTypes = ["image/png", "image/jpeg", "image/webp", "image/gif", "image/svg+xml", googleDriveFolderMime].join(",");
const portraitDeviceSizes = [
  { label: "iPhone SE", width: 375, height: 667 },
  { label: "iPhone 13/14/15", width: 390, height: 844 },
  { label: "iPhone Plus/Max", width: 430, height: 932 },
  { label: "iPad mini", width: 744, height: 1133 },
  { label: "iPad", width: 820, height: 1180 },
  { label: "iPad Air / Pro 11", width: 834, height: 1194 },
  { label: "iPad Pro 12.9", width: 1024, height: 1366 },
];

function createProcessStep(type: ProcessStepType): ProcessStep {
  return {
    id: uid("process"),
    type,
    tolerance: 35,
    padding: 0,
    quality: 88,
    background: "#F6EBD4",
  };
}

function processStepLabel(type: ProcessStepType) {
  if (type === "convert_jpg") return "转 JPG";
  if (type === "remove_background") return "去背景";
  if (type === "trim_transparent") return "裁透明边";
  return "压缩图片";
}

function fallbackPythonTool(type: ProcessStepType): PythonTool {
  return {
    name: `${type}.py`,
    label: processStepLabel(type),
    supported: true,
    description: "已接入图片链式处理。",
    stepType: type,
  };
}

function formatBytes(bytes: number) {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB"];
  let value = bytes;
  let index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index += 1;
  }
  return `${value.toFixed(index === 0 ? 0 : 1)} ${units[index]}`;
}

function imageInfoText(info?: ImageInfo) {
  if (!info) return "未知格式 / 未知尺寸 / 0 B";
  const size = info.width && info.height ? `${info.width} x ${info.height}` : "未知尺寸";
  return `${info.format} / ${size} / ${formatBytes(info.bytes)}`;
}

function kindLabel(kind: PendingImageKind) {
  return kind === "tablecloth" ? "桌布" : "关卡图片";
}

function displayName(name: string) {
  return name.replace(/\.[^.]+$/, "");
}

function nameWithExistingExtension(previousName: string, nextDisplayName: string) {
  const cleanName = nextDisplayName.trim();
  if (!cleanName) return previousName;
  if (/\.[^.\\/]+$/.test(cleanName)) return cleanName;
  const extension = previousName.match(/(\.[^.\\/]+)$/)?.[1] || "";
  return `${cleanName}${extension}`;
}

function pendingImageRowId(id: string) {
  return `pending-image-${id}`;
}

function loadScriptOnce(src: string) {
  return new Promise<void>((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(`script[src="${src}"]`);
    if (existing?.dataset.loaded === "true") {
      resolve();
      return;
    }
    const script = existing || document.createElement("script");
    script.src = src;
    script.async = true;
    script.onload = () => {
      script.dataset.loaded = "true";
      resolve();
    };
    script.onerror = () => reject(new Error(`failed to load ${src}`));
    if (!existing) document.head.appendChild(script);
  });
}

function cleanFolderName(value: string) {
  return value.trim().replace(/[<>:"/\\|?*\u0000-\u001f]/g, "").replace(/\s+/g, " ").slice(0, 64);
}

function folderFromPath(pathValue?: string) {
  if (!pathValue) return "";
  const parts = pathValue.split(/[\\/]/).filter(Boolean);
  if (parts.length <= 1) return "";
  return cleanFolderName(parts[parts.length - 2]);
}

function isImageFile(file: File) {
  return file.type.startsWith("image/") || /\.(png|jpe?g|webp|gif|bmp|avif|svg)$/i.test(file.name);
}

async function candidatesFromDataTransfer(dataTransfer: DataTransfer): Promise<UploadCandidate[]> {
  const itemEntries = Array.from(dataTransfer.items || [])
    .map((item) => (item as DataTransferItemWithEntry).webkitGetAsEntry?.() as WebkitEntry | null | undefined)
    .filter((entry): entry is WebkitEntry => Boolean(entry));
  const candidates = itemEntries.length
    ? (await Promise.all(itemEntries.map((entry) => candidatesFromEntry(entry, [])))).flat()
    : Array.from(dataTransfer.files || []).map((file) => ({ file, folder: folderFromPath((file as FileWithRelativePath).webkitRelativePath) }));
  return candidates.filter(({ file }) => isImageFile(file));
}

async function candidatesFromEntry(entry: WebkitEntry, ancestors: string[]): Promise<UploadCandidate[]> {
  if (entry.isFile) {
    const file = await fileFromEntry(entry as WebkitFileEntry);
    return isImageFile(file) ? [{ file, folder: cleanFolderName(ancestors[ancestors.length - 1] || "") }] : [];
  }
  if (!entry.isDirectory) return [];
  const nextAncestors = [...ancestors, entry.name];
  const entries = await entriesFromDirectory(entry as WebkitDirectoryEntry);
  const nested = await Promise.all(entries.map((child) => candidatesFromEntry(child, nextAncestors)));
  return nested.flat();
}

function fileFromEntry(entry: WebkitFileEntry) {
  return new Promise<File>((resolve, reject) => entry.file(resolve, reject));
}

async function entriesFromDirectory(entry: WebkitDirectoryEntry) {
  const reader = entry.createReader();
  const entries: WebkitEntry[] = [];
  for (;;) {
    const batch = await new Promise<WebkitEntry[]>((resolve, reject) => reader.readEntries(resolve, reject));
    if (!batch.length) break;
    entries.push(...batch);
  }
  return entries;
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
  const [treeEditMode, setTreeEditMode] = useState(false);
  const [collapsedFolders, setCollapsedFolders] = useState<Set<string>>(() => new Set());
  const [editingImageId, setEditingImageId] = useState("");
  const [editingFolder, setEditingFolder] = useState("");
  const [dragOverFolder, setDragOverFolder] = useState<string | null>(null);
  const [driveImporting, setDriveImporting] = useState(false);
  const [pythonTools, setPythonTools] = useState<PythonTool[]>([]);
  const [selectedPendingId, setSelectedPendingId] = useState("");
  const [steps, setSteps] = useState<ProcessStep[]>(() => defaultStepTypes.map(createProcessStep));
  const [processing, setProcessing] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const [rejecting, setRejecting] = useState(false);
  const [message, setMessage] = useState("");
  const [expandedImage, setExpandedImage] = useState<ExpandedImage | null>(null);
  const [pendingSelectionId, setPendingSelectionId] = useState("");
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 6 } }));
  const columns = useResizableColumns({ initialLeft: 360, initialRight: 380, minLeft: 300, maxLeft: 520, minRight: 320, maxRight: 560, minCenter: 460 });

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
  const groupedImages = useMemo(() => {
    const groups = new Map<string, PendingImageItem[]>();
    groups.set("", []);
    for (const folder of folders) groups.set(folder, []);
    for (const item of pendingImages) {
      const folder = item.folder || "";
      groups.set(folder, [...(groups.get(folder) || []), item]);
    }
    return groups;
  }, [folders, pendingImages]);
  const rootImages = groupedImages.get("") || [];
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
        setMessage(`已上传 ${items.length} 张${kindLabel(kind)}，跳过 ${skippedCount} 个同名文件。`);
      } else {
        setMessage(`已上传 ${items.length} 张${kindLabel(kind)}。`);
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
      const data = (await response.json()) as { ok?: boolean; items?: PendingImageItem[]; skipped_count?: number; error?: string };
      if (!response.ok || !data.ok) throw new Error(data.error || `HTTP ${response.status}`);
      await loadPendingImages(data.items?.[0]?.id);
      setMessage(`已从 Google Drive 导入 ${data.items?.length || 0} 张图片，跳过 ${data.skipped_count || 0} 张。`);
    } catch (error) {
      setMessage(error instanceof Error ? `Google Drive 导入失败：${error.message}` : "Google Drive 导入失败");
    } finally {
      setDriveImporting(false);
    }
  }

  async function openGooglePicker() {
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
        scope: "https://www.googleapis.com/auth/drive.readonly",
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
              void importGoogleDriveFiles(tokenResponse.access_token as string, files, "image");
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
    if (!cleanName) return;
    if (previous?.name === cleanName) return;
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
      setMessage("已创建文件夹。");
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
    const images: ExpandedImageItem[] = [{ title: hasProcessedPreview ? "处理前" : "当前图片", url: selectedPending.url, info: selectedPending.source_info }];
    if (hasProcessedPreview && selectedPending.processed_url) {
      images.push({ title: "处理后", url: selectedPending.processed_url, info: selectedPending.processed_info });
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
      return { ...current, index: (current.index + delta + current.images.length) % current.images.length };
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

  return (
    <div className="grid h-full min-h-0 overflow-hidden bg-linen text-ink" style={{ gridTemplateColumns: columns.gridTemplateColumns }}>
      <aside className="min-h-0 overflow-auto border-r border-stone-300 bg-paper p-4">
        <div className="flex items-start gap-3 border-b border-stone-300 pb-4">
          <ImageIcon className="mt-1 text-clay" size={22} />
          <div>
            <h1 className="text-xl font-semibold">图片处理</h1>
            <p className="text-sm text-muted">待处理素材 / 桌布 / 工具链</p>
          </div>
        </div>

        <section className="mt-5 grid gap-3">
          <PanelTitle>上传</PanelTitle>
          <UploadButton label="批量上传关卡图片" kind="image" onFiles={uploadFromFileList} onDropFiles={uploadFromDrop} />
          <UploadButton label="批量上传桌布图片" kind="tablecloth" onFiles={uploadFromFileList} onDropFiles={uploadFromDrop} />
        </section>

        <section className="mt-5 grid gap-3">
          <PanelTitle>Google Drive</PanelTitle>
          <button className="btnPrimary" disabled={driveImporting} onClick={() => void openGooglePicker()}>
            <Cloud size={16} />
            {driveImporting ? "连接中..." : "选择 Drive 图片/文件夹"}
          </button>
          <p className="text-xs leading-relaxed text-muted">需要在 `.env.local` 配置 Google Client ID 和 API Key。可以选择图片，也可以选择文件夹；文件夹只导入其中的直接图片。</p>
        </section>

        <section className="mt-5 grid gap-3">
          <div className="flex items-center justify-between gap-2">
            <PanelTitle>关卡图片</PanelTitle>
            <div className="flex items-center gap-2">
              <button className="iconBtn" disabled={!selectedPending} onClick={locateSelectedPending} title="定位当前图片" aria-label="定位当前图片">
                <Crosshair size={16} />
              </button>
              <button
                className={treeEditMode ? "iconBtnActive" : "iconBtn"}
                onClick={() => setTreeEditMode((current) => !current)}
                title={treeEditMode ? "退出编辑模式" : "编辑文件夹树"}
                aria-label={treeEditMode ? "退出编辑模式" : "编辑文件夹树"}
              >
                <Pencil size={16} />
              </button>
              {treeEditMode && hasSelection && (
                <button className="iconBtnDanger" onClick={() => void deleteSelected()} title="删除所选" aria-label="删除所选">
                  <Trash2 size={16} />
                </button>
              )}
            </div>
          </div>
          <div className="grid max-h-[52vh] gap-3 overflow-auto pr-1">
            {pendingImages.length || folders.length ? (
              <>
                {rootImages.length > 0 && (
                  <FolderGroup
                    folder=""
                    label="未分组"
                    items={rootImages}
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
                {folders.map((folder) => (
                  <FolderGroup
                    key={folder}
                    folder={folder}
                    label={folder}
                    items={groupedImages.get(folder) || []}
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
                {creatingFolder ? (
                  <div className="grid grid-cols-[1fr_auto_auto] gap-2">
                    <input
                      className="input min-w-0"
                      autoFocus
                      value={newFolderName}
                      placeholder="新文件夹"
                      onChange={(event) => setNewFolderName(event.target.value)}
                      onKeyDown={(event) => {
                        if (event.key === "Enter") void createFolder();
                        if (event.key === "Escape") cancelCreateFolder();
                      }}
                    />
                    <button className="btnPrimary px-3" onClick={cancelCreateFolder} title="取消" aria-label="取消创建文件夹">
                      <X size={16} />
                    </button>
                    <button className="btnPrimary px-3" onClick={() => void createFolder()} title="确认" aria-label="确认创建文件夹">
                      <Check size={16} />
                    </button>
                  </div>
                ) : (
                  <button className="btn w-full" onClick={() => setCreatingFolder(true)}>
                    <FolderPlus size={16} />
                    创建文件夹
                  </button>
                )}
              </>
            ) : (
              <>
                <div className="rounded-md border border-dashed border-stone-300 bg-white/70 px-3 py-4 text-sm text-muted">暂无图片。</div>
                {creatingFolder ? (
                  <div className="grid grid-cols-[1fr_auto_auto] gap-2">
                    <input
                      className="input min-w-0"
                      autoFocus
                      value={newFolderName}
                      placeholder="新文件夹"
                      onChange={(event) => setNewFolderName(event.target.value)}
                      onKeyDown={(event) => {
                        if (event.key === "Enter") void createFolder();
                        if (event.key === "Escape") cancelCreateFolder();
                      }}
                    />
                    <button className="btnPrimary px-3" onClick={cancelCreateFolder} title="取消" aria-label="取消创建文件夹">
                      <X size={16} />
                    </button>
                    <button className="btnPrimary px-3" onClick={() => void createFolder()} title="确认" aria-label="确认创建文件夹">
                      <Check size={16} />
                    </button>
                  </div>
                ) : (
                  <button className="btn w-full" onClick={() => setCreatingFolder(true)}>
                    <FolderPlus size={16} />
                    创建文件夹
                  </button>
                )}
              </>
            )}
          </div>
        </section>
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
              <span className="shrink-0">{kindLabel(selectedPending.kind)}</span>
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

        {message && <div className="mt-4 rounded-md border border-stone-300 bg-white px-3 py-2 text-sm text-ink">{message}</div>}
      </aside>

      {expandedImage && (
        <ExpandedImageModal gallery={expandedImage} onClose={() => setExpandedImage(null)} onSwitch={switchExpandedImage} />
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

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="grid gap-1.5 text-sm text-muted">
      {label}
      {children}
    </label>
  );
}

function PanelTitle({ children }: { children: React.ReactNode }) {
  return <h2 className="text-xs font-semibold uppercase tracking-wide text-muted">{children}</h2>;
}

function UploadButton({
  label,
  kind,
  onFiles,
  onDropFiles,
}: {
  label: string;
  kind: PendingImageKind;
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
      onDrop={(event) => void onDropFiles(event, kind)}
    >
      <Upload size={16} />
      {label}
      <input
        hidden
        multiple
        type="file"
        accept="image/*"
        onChange={(event) => onFiles(event.target.files, kind)}
        {...({ webkitdirectory: "", directory: "" } as Record<string, string>)}
      />
    </label>
  );
}

function FolderGroup({
  folder,
  label,
  items,
  droppable,
  collapsed,
  editMode,
  selectedPendingId,
  selectedImageIds,
  selectedFolders,
  dragOverFolder,
  onSelectPending,
  onToggleImage,
  onToggleFolder,
  onToggleCollapsed,
  editingImageId,
  editingFolder,
  onStartRenameImage,
  onStartRenameFolder,
  onRenameImage,
  onRenameFolder,
  onMoveImages,
  onDragStart,
  onDragOverFolder,
}: {
  folder: string;
  label: string;
  items: PendingImageItem[];
  droppable: boolean;
  collapsed: boolean;
  editMode: boolean;
  selectedPendingId: string;
  selectedImageIds: Set<string>;
  selectedFolders: Set<string>;
  dragOverFolder: string | null;
  onSelectPending: (id: string) => void;
  onToggleImage: (id: string, checked: boolean) => void;
  onToggleFolder: (folder: string, checked: boolean) => void;
  onToggleCollapsed: (folder: string) => void;
  editingImageId: string;
  editingFolder: string;
  onStartRenameImage: (id: string) => void;
  onStartRenameFolder: (folder: string) => void;
  onRenameImage: (id: string, name: string) => void;
  onRenameFolder: (oldName: string, nextName: string) => void;
  onMoveImages: (ids: string[], folder: string) => void;
  onDragStart: (item: PendingImageItem, event: React.DragEvent) => void;
  onDragOverFolder: (folder: string | null) => void;
}) {
  const canSelectFolder = folder !== "";
  const activeDrop = droppable && dragOverFolder === folder;
  return (
    <section
      className={`rounded-md border ${activeDrop ? "border-clay bg-white" : "border-stone-300 bg-white/60"} p-2`}
      onDragOver={(event) => {
        if (!droppable) return;
        event.preventDefault();
        onDragOverFolder(folder);
      }}
      onDragLeave={() => onDragOverFolder(null)}
      onDrop={(event) => {
        if (!droppable) return;
        event.preventDefault();
        onDragOverFolder(null);
        const raw = event.dataTransfer.getData("application/x-jigcat-pending-ids");
        if (!raw) return;
        const ids = JSON.parse(raw) as string[];
        onMoveImages(ids, folder);
      }}
    >
      <div className="mb-2 flex items-center justify-between gap-2 text-sm font-medium text-ink">
        <div className="flex min-w-0 items-center gap-2">
          {canSelectFolder ? (
            <button className="iconBtn !min-h-7 border-0 bg-transparent px-1 py-1 shadow-none" onClick={() => onToggleCollapsed(folder)} aria-label={collapsed ? "展开文件夹" : "收起文件夹"}>
              {collapsed ? <ChevronRight size={16} /> : <ChevronDown size={16} />}
            </button>
          ) : (
            <span className="w-7" />
          )}
          {editMode && canSelectFolder && (
            <input
              className="mr-2 h-4 w-4 shrink-0 accent-clay"
              type="checkbox"
              checked={selectedFolders.has(folder)}
              onChange={(event) => onToggleFolder(folder, event.target.checked)}
            />
          )}
          <InlineEditableName
            value={label}
            editMode={editMode && canSelectFolder}
            editing={editingFolder === folder}
            className="font-medium text-ink"
            onStart={() => onStartRenameFolder(folder)}
            onCommit={(value) => onRenameFolder(folder, value)}
          />
        </div>
        <small className="text-muted">{items.length}</small>
      </div>
      <div className={collapsed ? "hidden" : "grid gap-2"}>
        {items.length ? (
          items.map((item) => (
            <div
              id={pendingImageRowId(item.id)}
              key={item.id}
              className={item.id === selectedPendingId ? "objectActive" : "object"}
              draggable
              onClick={() => onSelectPending(item.id)}
              onDragStart={(event) => onDragStart(item, event)}
            >
              {editMode && (
                <input
                  className="h-4 w-4 shrink-0 accent-clay"
                  type="checkbox"
                  checked={selectedImageIds.has(item.id)}
                  onClick={(event) => event.stopPropagation()}
                  onChange={(event) => onToggleImage(item.id, event.target.checked)}
                />
              )}
              <div className={`flex min-w-0 flex-1 items-center gap-2 text-left ${editMode ? "ml-0" : ""}`}>
                <InlineEditableName
                  value={displayName(item.name)}
                  editMode={editMode}
                  editing={editingImageId === item.id}
                  className={item.processed && !item.processed_path ? "text-emerald-700" : "text-ink"}
                  onStart={() => onStartRenameImage(item.id)}
                  onCommit={(value) => onRenameImage(item.id, value)}
                />
                {item.processed_path && <span className="mr-1 shrink-0 rounded bg-amber-100 px-1.5 py-0.5 text-[11px] font-medium text-amber-700">待确认</span>}
                {item.processed && !item.processed_path && <CheckCircle2 className="mr-1 shrink-0 text-emerald-700" size={16} />}
              </div>
            </div>
          ))
        ) : (
          <div className="rounded border border-dashed border-stone-200 px-3 py-2 text-xs text-muted">{droppable ? "拖拽图片到这里" : "暂无图片"}</div>
        )}
      </div>
    </section>
  );
}

function ImagePreviewCard({
  title,
  name,
  url,
  info,
  onOpen,
}: {
  title: string;
  name: string;
  url: string;
  info?: ImageInfo;
  onOpen: () => void;
}) {
  return (
    <button className="group relative block max-h-[calc(100vh-152px)] max-w-full overflow-hidden rounded-md border border-stone-200 bg-white text-left shadow-sm" onClick={onOpen}>
      <img className="max-h-[calc(100vh-152px)] max-w-full object-contain" src={url} alt={`${title} ${name}`} />
      <div className="absolute bottom-3 left-3 max-w-[calc(100%-24px)] rounded-md bg-black/70 px-3 py-2 text-xs text-white shadow-sm">
        <div className="font-medium">{title}</div>
        <div className="mt-0.5 truncate text-white/80">{name}</div>
        <div className="mt-1 text-white/80">{imageInfoText(info)}</div>
      </div>
      <div className="pointer-events-none absolute inset-0 rounded-md ring-0 ring-clay/60 transition group-hover:ring-2" />
    </button>
  );
}

function InlineEditableName({
  value,
  editMode,
  editing,
  className,
  onStart,
  onCommit,
}: {
  value: string;
  editMode: boolean;
  editing: boolean;
  className?: string;
  onStart: () => void;
  onCommit: (value: string) => void;
}) {
  const [draft, setDraft] = useState(value);

  useEffect(() => {
    if (editing) setDraft(value);
  }, [editing, value]);

  function commit() {
    const next = draft.trim();
    onCommit(next || value);
  }

  if (editing) {
    return (
      <input
        className="input h-8 min-w-0 flex-1 px-2 py-1"
        autoFocus
        value={draft}
        onClick={(event) => event.stopPropagation()}
        onMouseDown={(event) => event.stopPropagation()}
        onChange={(event) => setDraft(event.target.value)}
        onBlur={commit}
        onKeyDown={(event) => {
          if (event.key === "Enter") event.currentTarget.blur();
          if (event.key === "Escape") {
            setDraft(value);
            event.currentTarget.blur();
          }
        }}
      />
    );
  }

  return (
    <span className="group/rename flex min-w-0 flex-1 items-center gap-1">
      <span className={`min-w-0 flex-1 truncate ${className || ""}`}>{value}</span>
      {editMode && (
        <button
          className="editReveal shrink-0 rounded p-1 text-muted transition hover:bg-stone-100 hover:text-clay"
          onClick={(event) => {
            event.stopPropagation();
            onStart();
          }}
          aria-label={`重命名 ${value}`}
          title="重命名"
        >
          <Pencil size={13} />
        </button>
      )}
    </span>
  );
}

function ExpandedImageModal({
  gallery,
  onClose,
  onSwitch,
}: {
  gallery: ExpandedImage;
  onClose: () => void;
  onSwitch: (delta: number) => void;
}) {
  const [deviceIndex, setDeviceIndex] = useState(0);
  const current = gallery.images[gallery.index];
  const canSwitch = gallery.images.length > 1;
  const device = portraitDeviceSizes[deviceIndex] || portraitDeviceSizes[0];
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/70 p-8" onClick={onClose}>
      <div className="relative grid h-[calc(100vh-64px)] w-[calc(100vw-64px)] overflow-hidden rounded-md bg-white shadow-xl" onClick={(event) => event.stopPropagation()}>
        <div className="absolute left-0 right-0 top-0 z-10 flex items-center justify-between gap-4 bg-white/95 px-3 py-2 text-sm text-ink shadow-sm">
          <div className="min-w-0 flex items-center gap-3">
            <div className="font-medium">{current.title}</div>
            <select className="selectTrigger !min-h-9 w-56" value={deviceIndex} onChange={(event) => setDeviceIndex(Number(event.target.value))} aria-label="预览分辨率">
              {portraitDeviceSizes.map((option, index) => (
                <option key={option.label} value={index}>
                  {option.label} {option.width} x {option.height}
                </option>
              ))}
            </select>
          </div>
          <button className="iconBtn !min-h-8 shrink-0" onClick={onClose} aria-label="关闭预览">
            <X size={16} />
          </button>
        </div>
        {canSwitch && (
          <>
            <button className="absolute left-4 top-1/2 z-20 -translate-y-1/2 rounded-md border border-white/40 bg-black/45 p-2 text-white transition hover:bg-black/65" onClick={() => onSwitch(-1)} aria-label="上一张">
              <ChevronLeft size={22} />
            </button>
            <button className="absolute right-4 top-1/2 z-20 -translate-y-1/2 rounded-md border border-white/40 bg-black/45 p-2 text-white transition hover:bg-black/65" onClick={() => onSwitch(1)} aria-label="下一张">
              <ChevronRight size={22} />
            </button>
          </>
        )}
        <div className="grid h-full place-items-center overflow-auto px-16 pb-8 pt-20">
          <div className="grid shrink-0 place-items-center overflow-hidden rounded-md border border-stone-300 bg-[#f7efe2] shadow-sm" style={{ width: device.width, height: device.height }}>
            <img className="h-full w-full object-contain" src={current.url} alt={current.title} />
          </div>
        </div>
      </div>
    </div>
  );
}

function ProcessStepRow({
  step,
  tool,
  disabled,
  disabledReason,
  onUpdate,
  onEnabledChange,
}: {
  step: ProcessStep;
  tool: PythonTool;
  disabled: boolean;
  disabledReason: string;
  onUpdate: (patch: Partial<ProcessStep>) => void;
  onEnabledChange: (checked: boolean) => void;
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: step.id, disabled });
  return (
    <div
      ref={setNodeRef}
      className={`rounded-md border border-stone-300 bg-white p-2 text-sm ${disabled ? "opacity-55" : ""} ${isDragging ? "opacity-70" : ""}`}
      style={{ transform: CSS.Transform.toString(transform), transition }}
    >
      <div className={disabled ? "flex items-center gap-2" : "flex cursor-grab items-center gap-2 active:cursor-grabbing"} {...attributes} {...listeners}>
        <input
          className="h-4 w-4 cursor-default accent-clay"
          type="checkbox"
          checked
          disabled={disabled}
          onPointerDown={(event) => event.stopPropagation()}
          onChange={(event) => onEnabledChange(event.target.checked)}
          aria-label={`启用${tool.label}`}
        />
        <div className="min-w-0 flex-1 font-medium text-ink">{tool.label}</div>
        {disabledReason && <span className="text-xs text-muted">{disabledReason}</span>}
      </div>
      {step.type === "remove_background" && (
        <Field label="容差">
          <input className="input" type="number" min="0" max="441" value={step.tolerance} disabled={disabled} onChange={(event) => onUpdate({ tolerance: Number(event.target.value) })} />
        </Field>
      )}
      {step.type === "trim_transparent" && (
        <Field label="留边">
          <input className="input" type="number" min="0" max="256" value={step.padding} disabled={disabled} onChange={(event) => onUpdate({ padding: Number(event.target.value) })} />
        </Field>
      )}
      {step.type === "convert_jpg" && (
        <div className="mt-2 grid grid-cols-[1fr_56px] gap-2">
          <Field label="质量">
            <input className="input" type="number" min="1" max="100" value={step.quality} disabled={disabled} onChange={(event) => onUpdate({ quality: Number(event.target.value) })} />
          </Field>
          <Field label="底色">
            <input className="input h-10 p-1" type="color" value={step.background} disabled={disabled} onChange={(event) => onUpdate({ background: event.target.value })} />
          </Field>
        </div>
      )}
      {step.type === "compress" && (
        <Field label="质量">
          <input className="input" type="number" min="1" max="100" value={step.quality} disabled={disabled} onChange={(event) => onUpdate({ quality: Number(event.target.value) })} />
        </Field>
      )}
    </div>
  );
}

function PythonToolRow({
  tool,
  disabled,
  disabledReason,
  onEnabledChange,
}: {
  tool: PythonTool;
  disabled: boolean;
  disabledReason: string;
  onEnabledChange: (checked: boolean) => void;
}) {
  return (
    <label
      className={`flex items-start gap-2 rounded-md border px-3 py-2 text-sm ${
        tool.supported && !disabled ? "border-stone-300 bg-stone-100/80 text-ink" : "border-stone-200 bg-stone-100/70 text-muted opacity-70"
      }`}
    >
      <input
        className="mt-0.5 h-4 w-4 accent-clay disabled:accent-stone-300"
        type="checkbox"
        disabled={!tool.supported || !tool.stepType || disabled}
        checked={false}
        onChange={(event) => onEnabledChange(event.target.checked)}
      />
      <span className="min-w-0 flex-1">
        <span className="block font-medium">{tool.label}</span>
        <span className="mt-1 block text-xs text-muted">{disabledReason || tool.description}</span>
      </span>
    </label>
  );
}

export default ImagePipelinePage;
