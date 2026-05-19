import { useMemo, useState } from "react";

type Options = {
  initialLeft: number;
  initialRight: number;
  minLeft?: number;
  maxLeft?: number;
  minRight?: number;
  maxRight?: number;
  minCenter?: number;
};

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

export function useResizableColumns({
  initialLeft,
  initialRight,
  minLeft = 280,
  maxLeft = 520,
  minRight = 300,
  maxRight = 560,
  minCenter = 420,
}: Options) {
  const [leftWidth, setLeftWidth] = useState(initialLeft);
  const [rightWidth, setRightWidth] = useState(initialRight);

  const gridTemplateColumns = useMemo(
    () => `${leftWidth}px 6px minmax(${minCenter}px, 1fr) 6px ${rightWidth}px`,
    [leftWidth, minCenter, rightWidth],
  );

  function startLeftResize(event: React.PointerEvent) {
    const startX = event.clientX;
    const startWidth = leftWidth;
    const onMove = (moveEvent: PointerEvent) => {
      setLeftWidth(clamp(startWidth + moveEvent.clientX - startX, minLeft, maxLeft));
    };
    const onUp = () => {
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
    };
    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
  }

  function startRightResize(event: React.PointerEvent) {
    const startX = event.clientX;
    const startWidth = rightWidth;
    const onMove = (moveEvent: PointerEvent) => {
      setRightWidth(clamp(startWidth + startX - moveEvent.clientX, minRight, maxRight));
    };
    const onUp = () => {
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
    };
    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
  }

  return { gridTemplateColumns, startLeftResize, startRightResize };
}

