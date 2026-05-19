import type { ImageInfo } from "../../../types";
import { imageInfoText } from "../../../shared/lib/format";

export function ImagePreviewCard({
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
