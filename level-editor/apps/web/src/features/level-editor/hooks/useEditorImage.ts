import { useEffect, useState } from "react";
import { detectImageOutline, serializePoints } from "../../../geometry";
import type { LevelConfig, OutlineAnalysis } from "../../../types";
import type { AnalysisWorkerHandle } from "./useAnalysisWorker";

type Options = {
  workerHandle: AnalysisWorkerHandle;
  onLevelImageDimensionsDetected: (width: number, height: number) => void;
  onOutlineDetected: (outline: OutlineAnalysis["outline"]) => void;
};

export type EditorImageState = {
  image: HTMLImageElement | null;
  imageUrl: string;
  analysis: OutlineAnalysis;
  loadImage: (src: string, onLoaded?: (image: HTMLImageElement) => void) => void;
  clearImage: () => void;
};

export function useEditorImage({ workerHandle, onLevelImageDimensionsDetected, onOutlineDetected }: Options): EditorImageState {
  const [image, setImage] = useState<HTMLImageElement | null>(null);
  const [imageUrl, setImageUrl] = useState("");
  const [analysis, setAnalysis] = useState<OutlineAnalysis>({ outline: [], edgePoints: [], bounds: null });

  useEffect(() => {
    if (!image) return;
    const nextAnalysis = detectImageOutline(image);
    setAnalysis(nextAnalysis);
    onLevelImageDimensionsDetected(image.naturalWidth, image.naturalHeight);
    onOutlineDetected(nextAnalysis.outline);
  }, [image]);

  useEffect(() => {
    workerHandle.setWorkerImageReady(false);
    if (!image) return;
    const worker = workerHandle.workerRef.current;
    if (!worker || !("createImageBitmap" in window)) return;
    let cancelled = false;
    const requestId = workerHandle.imageRequestIdRef.current + 1;
    workerHandle.imageRequestIdRef.current = requestId;
    void createImageBitmap(image)
      .then((bitmap) => {
        if (cancelled) {
          bitmap.close();
          return;
        }
        worker.postMessage({ type: "setImage", requestId, image: bitmap }, [bitmap]);
      })
      .catch(() => {
        if (workerHandle.imageRequestIdRef.current === requestId) workerHandle.setWorkerImageReady(false);
      });
    return () => {
      cancelled = true;
    };
  }, [image]);

  function loadImage(src: string, onLoaded?: (image: HTMLImageElement) => void) {
    if (!src) {
      clearImage();
      return;
    }
    const next = new Image();
    next.onload = () => {
      setImage(next);
      setImageUrl(src);
      onLoaded?.(next);
    };
    next.onerror = () => {
      clearImage();
    };
    next.src = src;
  }

  function clearImage() {
    setImage(null);
    setImageUrl("");
    setAnalysis({ outline: [], edgePoints: [], bounds: null });
  }

  return { image, imageUrl, analysis, loadImage, clearImage };
}

export function makeOutlineEditorPatch(level: LevelConfig, outline: OutlineAnalysis["outline"]): LevelConfig {
  return {
    ...level,
    editor: {
      ...level.editor,
      outline: serializePoints(outline),
    },
  };
}
