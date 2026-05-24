import { useEffect, useRef, useState } from "react";
import type { ActualPiecePreview } from "../../../geometry";
import { previewBufferToDataUrl } from "../lib/editor";

type AnalysisWorkerMessage =
  | {
      type: "imageReady";
      requestId: number;
    }
  | {
      type: "analysisResult";
      requestId: number;
      result: Omit<ActualPiecePreview, "dataUrl"> & { previewBuffer: ArrayBuffer };
    };

export type AnalysisWorkerHandle = {
  workerRef: React.MutableRefObject<Worker | null>;
  workerImageReady: boolean;
  setWorkerImageReady: React.Dispatch<React.SetStateAction<boolean>>;
  imageRequestIdRef: React.MutableRefObject<number>;
  analysisRequestIdRef: React.MutableRefObject<number>;
};

export function useAnalysisWorker(onResult: (result: ActualPiecePreview) => void): AnalysisWorkerHandle {
  const workerRef = useRef<Worker | null>(null);
  const imageRequestIdRef = useRef(0);
  const analysisRequestIdRef = useRef(0);
  const [workerImageReady, setWorkerImageReady] = useState(false);
  const onResultRef = useRef(onResult);
  onResultRef.current = onResult;

  useEffect(() => {
    try {
      const worker = new Worker(new URL("../../../actualPieces.worker.ts", import.meta.url), { type: "module" });
      worker.onmessage = (event: MessageEvent<AnalysisWorkerMessage>) => {
        const message = event.data;
        if (message.type === "imageReady") {
          if (message.requestId === imageRequestIdRef.current) setWorkerImageReady(true);
          return;
        }
        if (message.requestId !== analysisRequestIdRef.current) return;
        const { previewBuffer, ...result } = message.result;
        onResultRef.current({
          ...result,
          dataUrl: previewBufferToDataUrl(result.width, result.height, previewBuffer),
        });
      };
      worker.onerror = () => {
        worker.terminate();
        if (workerRef.current === worker) workerRef.current = null;
        setWorkerImageReady(false);
      };
      workerRef.current = worker;
      return () => {
        worker.terminate();
        if (workerRef.current === worker) workerRef.current = null;
      };
    } catch {
      workerRef.current = null;
      return undefined;
    }
  }, []);

  return { workerRef, workerImageReady, setWorkerImageReady, imageRequestIdRef, analysisRequestIdRef };
}
