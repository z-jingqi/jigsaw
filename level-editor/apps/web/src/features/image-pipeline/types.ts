import type { ImageInfo, PendingImageKind } from "../../types";

export type ImagePipelineSelectionState = {
  id: string;
  name: string;
  kind: PendingImageKind;
  status: "未处理" | "已处理" | "待确认";
  hasUnconfirmed: boolean;
};

export type ExpandedImageItem = {
  url: string;
  title: string;
  name: string;
  info?: ImageInfo;
};

export type ExpandedImage = {
  images: ExpandedImageItem[];
  index: number;
};

export type UploadCandidate = {
  file: File;
  folder: string;
};

export type FileWithRelativePath = File & {
  webkitRelativePath?: string;
};

export type WebkitEntry = {
  isFile: boolean;
  isDirectory: boolean;
  name: string;
};

export type WebkitFileEntry = WebkitEntry & {
  file: (success: (file: File) => void, error?: (error: DOMException) => void) => void;
};

export type WebkitDirectoryEntry = WebkitEntry & {
  createReader: () => {
    readEntries: (success: (entries: WebkitEntry[]) => void, error?: (error: DOMException) => void) => void;
  };
};

export type DataTransferItemWithEntry = DataTransferItem & {
  webkitGetAsEntry?: () => unknown;
};
