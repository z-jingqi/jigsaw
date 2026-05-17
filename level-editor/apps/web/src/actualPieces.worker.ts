import {
  polygonArea,
  simplifyClosedPath,
  traceBoundaryLoops,
  type ActualPiecePreview,
} from "./geometry";
import type { CutLine, PieceCell } from "./types";

type WorkerInput =
  | {
      type: "setImage";
      image: ImageBitmap;
      requestId: number;
    }
  | {
      type: "analyze";
      cuts: CutLine[];
      maxSize: number;
      requestId: number;
    };

type AnalysisResult = Omit<ActualPiecePreview, "dataUrl"> & {
  previewBuffer: ArrayBuffer;
};

type WorkerScope = {
  onmessage: ((event: MessageEvent<WorkerInput>) => void | Promise<void>) | null;
  postMessage(message: unknown, transfer?: Transferable[]): void;
};

const workerScope = self as unknown as WorkerScope;

let sourceImage: ImageBitmap | null = null;

workerScope.onmessage = async (event: MessageEvent<WorkerInput>) => {
  const message = event.data;
  if (message.type === "setImage") {
    sourceImage?.close();
    sourceImage = message.image;
    workerScope.postMessage({ type: "imageReady", requestId: message.requestId });
    return;
  }

  if (!sourceImage) {
    workerScope.postMessage({ type: "analysisResult", requestId: message.requestId, result: emptyResult() });
    return;
  }

  const result = analyzeActualPiecesInWorker(sourceImage, message.cuts, message.maxSize);
  workerScope.postMessage({ type: "analysisResult", requestId: message.requestId, result }, [result.previewBuffer]);
};

function emptyResult(): AnalysisResult {
  return {
    count: 0,
    width: 1,
    height: 1,
    pieces: [],
    minArea: 0,
    smallPieceIds: [],
    previewBuffer: new Uint8ClampedArray(4).buffer,
  };
}

function analyzeActualPiecesInWorker(image: ImageBitmap, cuts: CutLine[], maxSize: number): AnalysisResult {
  const scale = Math.min(maxSize / image.width, maxSize / image.height, 1);
  const width = Math.max(1, Math.round(image.width * scale));
  const height = Math.max(1, Math.round(image.height * scale));
  const imageCanvas = new OffscreenCanvas(width, height);
  const imageCtx = imageCanvas.getContext("2d", { willReadFrequently: true });
  if (!imageCtx) return emptyResult();
  imageCtx.clearRect(0, 0, width, height);
  imageCtx.drawImage(image, 0, 0, width, height);
  const imageData = imageCtx.getImageData(0, 0, width, height);
  const visible = new Uint8Array(width * height);
  for (let i = 0; i < width * height; i += 1) visible[i] = imageData.data[i * 4 + 3] > 18 ? 1 : 0;

  const barrierCanvas = new OffscreenCanvas(width, height);
  const barrierCtx = barrierCanvas.getContext("2d", { willReadFrequently: true });
  if (!barrierCtx) return emptyResult();
  barrierCtx.clearRect(0, 0, width, height);
  barrierCtx.strokeStyle = "#fff";
  barrierCtx.lineCap = "butt";
  barrierCtx.lineJoin = "miter";
  barrierCtx.lineWidth = Math.max(1, Math.round(scale));
  for (const cut of cuts) {
    if (cut.points.length < 2) continue;
    barrierCtx.beginPath();
    barrierCtx.moveTo(cut.points[0].x * scale, cut.points[0].y * scale);
    for (let i = 1; i < cut.points.length; i += 1) barrierCtx.lineTo(cut.points[i].x * scale, cut.points[i].y * scale);
    if (cut.type === "preset_shape") barrierCtx.closePath();
    barrierCtx.stroke();
  }
  const barrierData = barrierCtx.getImageData(0, 0, width, height).data;
  for (let i = 0; i < width * height; i += 1) {
    if (barrierData[i * 4 + 3] > 0) visible[i] = 0;
  }

  const preview = new Uint8ClampedArray(width * height * 4);
  const visited = new Uint8Array(width * height);
  const colors = [
    [111, 157, 103],
    [217, 147, 63],
    [93, 141, 174],
    [186, 114, 129],
    [154, 132, 80],
    [137, 116, 176],
    [89, 152, 145],
    [199, 124, 46],
  ];
  const neighbors = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ];
  let count = 0;
  let minArea = Number.POSITIVE_INFINITY;
  const pieces: PieceCell[] = [];
  const smallPieceIds: string[] = [];

  for (let start = 0; start < visible.length; start += 1) {
    if (!visible[start] || visited[start]) continue;
    const color = colors[count % colors.length];
    const pieceId = `piece_${String(count + 1).padStart(2, "0")}`;
    const componentPixels: number[] = [];
    count += 1;
    const stack = [start];
    visited[start] = 1;
    while (stack.length) {
      const index = stack.pop() as number;
      componentPixels.push(index);
      preview[index * 4] = color[0];
      preview[index * 4 + 1] = color[1];
      preview[index * 4 + 2] = color[2];
      preview[index * 4 + 3] = 88;
      const x = index % width;
      const y = Math.floor(index / width);
      for (const [dx, dy] of neighbors) {
        const nx = x + dx;
        const ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        const nextIndex = ny * width + nx;
        if (!visible[nextIndex] || visited[nextIndex]) continue;
        visited[nextIndex] = 1;
        stack.push(nextIndex);
      }
    }

    const area = componentPixels.length / Math.max(1e-6, scale * scale);
    minArea = Math.min(minArea, area);
    if (area < 900) smallPieceIds.push(pieceId);

    const componentMask = new Uint8Array(width * height);
    for (const index of componentPixels) componentMask[index] = 1;
    const loops = traceBoundaryLoops(componentMask, width, height);
    const largestLoop = loops.sort((a, b) => Math.abs(polygonArea(b)) - Math.abs(polygonArea(a)))[0] || [];
    if (largestLoop.length >= 4) {
      const raw = largestLoop.map((point) => ({ x: point.x / scale, y: point.y / scale }));
      const simplified = simplifyClosedPath(raw, Math.max(1.5, 2.2 / Math.max(scale, 1e-6)));
      pieces.push({ id: pieceId, points: simplified });
    }
  }

  return {
    count,
    width,
    height,
    pieces,
    minArea: Number.isFinite(minArea) ? minArea : 0,
    smallPieceIds,
    previewBuffer: preview.buffer,
  };
}
