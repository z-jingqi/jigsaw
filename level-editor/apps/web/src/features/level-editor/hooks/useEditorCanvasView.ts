import { useEffect, useMemo, useRef, useState } from "react";
import { clamp } from "../lib/editor";

export type EditorCanvasView = {
  zoom: number;
  setZoom: React.Dispatch<React.SetStateAction<number>>;
  changeZoom: (delta: number) => void;
  resetZoom: () => void;
  /** 用户拖拽画布时手动调整的 viewBox 中心偏移（图像像素空间）。 */
  panBy: (dx: number, dy: number) => void;
  resetPan: () => void;
  viewBox: string;
};

type Args = {
  image: HTMLImageElement | null;
  locked?: boolean;
};

export function useEditorCanvasView({ image, locked = false }: Args): EditorCanvasView {
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });

  // 切换图片时 pan 复位，避免上一张图片的偏移残留到下一张。
  useEffect(() => {
    setPan({ x: 0, y: 0 });
  }, [image]);

  const baseViewBox = useMemo(() => {
    if (!image) return { x: 0, y: 0, width: 1024, height: 1024 };
    const margin = Math.max(48, Math.round(Math.min(image.naturalWidth, image.naturalHeight) * 0.08));
    return {
      x: -margin,
      y: -margin,
      width: image.naturalWidth + margin * 2,
      height: image.naturalHeight + margin * 2,
    };
  }, [image]);

  // focus 永远是图像中心（或默认），不再随选中线段变化；
  // 视野的偏移由用户主动拖拽决定（pan）。
  const focus = useMemo(() => {
    if (image) return { x: image.naturalWidth * 0.5, y: image.naturalHeight * 0.5 };
    return { x: 512, y: 512 };
  }, [image]);

  const liveViewBox = useMemo(() => {
    const width = baseViewBox.width / zoom;
    const height = baseViewBox.height / zoom;
    const minX = baseViewBox.x;
    const minY = baseViewBox.y;
    const maxX = baseViewBox.x + baseViewBox.width - width;
    const maxY = baseViewBox.y + baseViewBox.height - height;
    const x = clamp(focus.x + pan.x - width * 0.5, minX, maxX);
    const y = clamp(focus.y + pan.y - height * 0.5, minY, maxY);
    return `${x} ${y} ${width} ${height}`;
  }, [baseViewBox, focus, zoom, pan]);

  // 拖拽线段过程中临时锁定视野，避免任何 viewBox 重算造成抖动。
  const lastUnlockedViewBoxRef = useRef(liveViewBox);
  if (!locked) lastUnlockedViewBoxRef.current = liveViewBox;
  const viewBox = locked ? lastUnlockedViewBoxRef.current : liveViewBox;

  function changeZoom(delta: number) {
    setZoom((value) => clamp(Math.round((value + delta) * 100) / 100, 1, 4));
  }

  function resetZoom() {
    setZoom(1);
    setPan({ x: 0, y: 0 });
  }

  function panBy(dx: number, dy: number) {
    if (dx === 0 && dy === 0) return;
    setPan((current) => ({ x: current.x + dx, y: current.y + dy }));
  }

  function resetPan() {
    setPan({ x: 0, y: 0 });
  }

  return { zoom, setZoom, changeZoom, resetZoom, panBy, resetPan, viewBox };
}
