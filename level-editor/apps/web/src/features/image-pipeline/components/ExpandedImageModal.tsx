import { useState } from "react";
import { ChevronLeft, ChevronRight, X } from "lucide-react";
import { imageInfoText } from "../../../shared/lib/format";
import { portraitDeviceSizes } from "../constants";
import type { ExpandedImage } from "../types";

export function ExpandedImageModal({
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
  const canGoPrevious = gallery.index > 0;
  const canGoNext = gallery.index < gallery.images.length - 1;
  const device = portraitDeviceSizes[deviceIndex] || portraitDeviceSizes[0];
  const headerInfo = `${current.name} (${imageInfoText(current.info)})`;
  return (
    <div className="fixed inset-0 z-[100] grid place-items-center bg-black/70 p-8" onClick={onClose}>
      <div className="relative grid h-[calc(100vh-64px)] w-[min(calc(100vw-64px),1180px)] overflow-hidden rounded-md bg-white shadow-xl" onClick={(event) => event.stopPropagation()}>
        <div className="absolute left-0 right-0 top-0 z-10 grid grid-cols-[1fr_auto_1fr] items-center gap-4 bg-white/95 px-3 py-2 text-sm text-ink shadow-sm">
          <div className="min-w-0">
            <select className="selectTrigger !min-h-9 w-56" value={deviceIndex} onChange={(event) => setDeviceIndex(Number(event.target.value))} aria-label="预览分辨率">
              {portraitDeviceSizes.map((option, index) => (
                <option key={option.label} value={index}>
                  {option.label} {option.width} x {option.height}
                </option>
              ))}
            </select>
          </div>
          <div className="min-w-0 truncate text-center font-medium">{headerInfo}</div>
          <button className="iconBtn !min-h-8 justify-self-end" onClick={onClose} aria-label="关闭预览">
            <X size={16} />
          </button>
        </div>
        {canGoPrevious && (
          <button className="absolute left-4 top-1/2 z-20 -translate-y-1/2 rounded-md border border-white/40 bg-black/45 p-2 text-white transition hover:bg-black/65" onClick={() => onSwitch(-1)} aria-label="上一张">
            <ChevronLeft size={22} />
          </button>
        )}
        {canGoNext && (
          <button className="absolute right-4 top-1/2 z-20 -translate-y-1/2 rounded-md border border-white/40 bg-black/45 p-2 text-white transition hover:bg-black/65" onClick={() => onSwitch(1)} aria-label="下一张">
            <ChevronRight size={22} />
          </button>
        )}
        <div className="grid h-full place-items-center overflow-auto px-10 pb-8 pt-20">
          <div className="grid shrink-0 place-items-center overflow-hidden rounded-md border border-stone-300 bg-[#f7efe2] shadow-sm" style={{ width: device.width, height: device.height }}>
            <img className="h-full w-full object-contain" src={current.url} alt={current.title} />
          </div>
        </div>
      </div>
    </div>
  );
}
