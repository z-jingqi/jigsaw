import type { CSSProperties, ForwardedRef } from "react";
import { forwardRef, useRef } from "react";
import { Minus, Plus, RotateCcw } from "lucide-react";
import { catmullRomPath } from "../../../geometry";
import type { CutLine, CutTemplate, LevelPiece, PieceCell, Point } from "../../../types";
import type { ActualPiecePreview, CutGap, CutIntersection } from "../../../geometry";
import { polylinePath, pointBounds, pointFromTuple } from "../lib/polygonPieces";
import { shapeTension } from "../lib/shapes";
import { clamp, shapeResizeHandles } from "../lib/editor";
import type { DrawingCutState, EditMode, PolygonViewMode, SnapConnectionMarker } from "../types";

type CanvasMaps = {
  cutPath: WeakMap<CutLine, string>;
  piecePath: WeakMap<PieceCell, string>;
  knobPiecePath: WeakMap<LevelPiece, string>;
};

const ZOOM_MIN = 1;
const ZOOM_MAX = 4;
const ZOOM_STEP = 0.05;

type Props = {
  svgRef: ForwardedRef<SVGSVGElement>;
  className?: string;
  viewBox: string;
  background: CSSProperties;
  modeBadge: string;
  zoom: number;
  onZoomChange: (delta: number) => void;
  onSetZoom: (value: number) => void;
  onZoomReset: () => void;

  image: HTMLImageElement | null;
  imageUrl: string;

  activeMode: EditMode;
  polygonView: PolygonViewMode;
  showKnobPieces: boolean;
  cutLineColor: string;
  lineToolActive: boolean;

  cuts: CutLine[];
  pieces: PieceCell[];
  knobPieces: LevelPiece[];
  selectedId: string;
  selectedPieceIds: string[];
  drawingCut: DrawingCutState | null;
  drawingHoverPoint: Point | null;
  actualPreview: ActualPiecePreview | null;
  cutGaps: CutGap[];
  cutIntersections: CutIntersection[];
  snapConnectionMarkers: SnapConnectionMarker[];

  caches: CanvasMaps;

  onCanvasPointerDown: (event: React.PointerEvent<SVGSVGElement>) => void;
  onCanvasPointerMove: (event: React.PointerEvent<SVGSVGElement>) => void;
  onCanvasPointerUp: () => void;
  onCanvasPointerLeave: () => void;
  onCanvasContextMenu: (event: React.MouseEvent<SVGSVGElement>) => void;
  onCanvasDrop: (event: React.DragEvent<SVGSVGElement>) => void;
  onTogglePieceSelection: (pieceId: string) => void;
  onBeginDragCut: (event: React.PointerEvent<SVGElement>, cutId: string, pointIndex: number | null) => void;
  onBeginScaleCut: (event: React.PointerEvent<SVGElement>, cutId: string) => void;
};

function getCutPath(cut: CutLine, cache: WeakMap<CutLine, string>): string {
  const cached = cache.get(cut);
  if (cached) return cached;
  const value =
    cut.type === "preset_shape" ? catmullRomPath(cut.points, shapeTension(cut.template as CutTemplate), true) : polylinePath(cut.points);
  cache.set(cut, value);
  return value;
}

function getPiecePath(piece: PieceCell, cache: WeakMap<PieceCell, string>): string {
  const cached = cache.get(piece);
  if (cached) return cached;
  const value = catmullRomPath(piece.points, 0.15, true);
  cache.set(piece, value);
  return value;
}

function getKnobPiecePath(piece: LevelPiece, cache: WeakMap<LevelPiece, string>): string {
  const cached = cache.get(piece);
  if (cached) return cached;
  const value = catmullRomPath(piece.points.map(pointFromTuple), 0.15, true);
  cache.set(piece, value);
  return value;
}

function CanvasZoomSlider({
  zoom,
  onSetZoom,
  onReset,
}: {
  zoom: number;
  onSetZoom: (value: number) => void;
  onReset: () => void;
}) {
  const trackRef = useRef<HTMLDivElement>(null);
  const ratio = clamp((zoom - ZOOM_MIN) / (ZOOM_MAX - ZOOM_MIN), 0, 1);

  function setFromEvent(event: React.PointerEvent<HTMLDivElement>) {
    const track = trackRef.current;
    if (!track) return;
    const rect = track.getBoundingClientRect();
    const r = clamp((rect.bottom - event.clientY) / rect.height, 0, 1);
    const value = ZOOM_MIN + r * (ZOOM_MAX - ZOOM_MIN);
    onSetZoom(clamp(Math.round(value / ZOOM_STEP) * ZOOM_STEP, ZOOM_MIN, ZOOM_MAX));
  }

  function step(direction: 1 | -1) {
    const next = clamp(Math.round((zoom + direction * 0.25) * 100) / 100, ZOOM_MIN, ZOOM_MAX);
    onSetZoom(next);
  }

  return (
    <div className="canvasZoomSlider">
      <button
        type="button"
        className="canvasZoomSliderBtn"
        aria-label="放大"
        onClick={() => step(1)}
        disabled={zoom >= ZOOM_MAX}
      >
        <Plus size={14} />
      </button>
      <div
        ref={trackRef}
        className="canvasZoomSliderTrack"
        onPointerDown={(event) => {
          event.currentTarget.setPointerCapture(event.pointerId);
          setFromEvent(event);
        }}
        onPointerMove={(event) => {
          if (!event.currentTarget.hasPointerCapture(event.pointerId)) return;
          setFromEvent(event);
        }}
        onPointerUp={(event) => {
          if (event.currentTarget.hasPointerCapture(event.pointerId)) {
            event.currentTarget.releasePointerCapture(event.pointerId);
          }
        }}
      >
        <div className="canvasZoomSliderFill" style={{ height: `${ratio * 100}%` }} />
        <div className="canvasZoomSliderThumb" style={{ bottom: `calc(${ratio * 100}% - 6px)` }} />
      </div>
      <button
        type="button"
        className="canvasZoomSliderBtn"
        aria-label="缩小"
        onClick={() => step(-1)}
        disabled={zoom <= ZOOM_MIN}
      >
        <Minus size={14} />
      </button>
      <div className="canvasZoomSliderLabel">{Math.round(zoom * 100)}%</div>
      <button
        type="button"
        className="canvasZoomSliderBtn canvasZoomSliderReset"
        aria-label="重置缩放"
        onClick={onReset}
        disabled={zoom === ZOOM_MIN}
      >
        <RotateCcw size={14} />
      </button>
    </div>
  );
}

function ShapeTransform({
  cut,
  onBeginScale,
}: {
  cut: CutLine;
  onBeginScale: (event: React.PointerEvent<SVGElement>, cutId: string) => void;
}) {
  const bounds = pointBounds(cut.points);
  if (bounds.width <= 0 || bounds.height <= 0) return null;
  return (
    <g className="shapeTransform">
      <rect x={bounds.x} y={bounds.y} width={bounds.width} height={bounds.height} />
      {shapeResizeHandles(cut).map((handle) => (
        <circle
          key={`${cut.id}_${handle.id}`}
          className={`scaleHandle scaleHandle_${handle.id}`}
          cx={handle.x}
          cy={handle.y}
          r={12}
          onPointerDown={(event) => onBeginScale(event, cut.id)}
        />
      ))}
    </g>
  );
}

export const EditorCanvas = forwardRef<SVGSVGElement, Omit<Props, "svgRef">>(function EditorCanvas(props, ref) {
  const {
    className,
    viewBox,
    background,
    modeBadge,
    zoom,
    onZoomChange,
    onSetZoom,
    onZoomReset,
    image,
    imageUrl,
    activeMode,
    polygonView,
    showKnobPieces,
    cutLineColor,
    lineToolActive,
    cuts,
    pieces,
    knobPieces,
    selectedId,
    selectedPieceIds,
    drawingCut,
    drawingHoverPoint,
    actualPreview,
    cutGaps,
    cutIntersections,
    snapConnectionMarkers,
    caches,
    onCanvasPointerDown,
    onCanvasPointerMove,
    onCanvasPointerUp,
    onCanvasPointerLeave,
    onCanvasContextMenu,
    onCanvasDrop,
    onTogglePieceSelection,
    onBeginDragCut,
    onBeginScaleCut,
  } = props;

  return (
    <div className="relative grid min-h-0 place-items-center overflow-hidden p-5" style={background}>
      <div className="canvasModeBadge">{modeBadge}</div>
      <CanvasZoomSlider zoom={zoom} onSetZoom={onSetZoom} onReset={onZoomReset} />
      <svg
        ref={ref}
        className={`${className || "h-[min(calc(100vh-96px),760px)] w-full max-w-[1040px] border border-black/15 bg-white/20"}${lineToolActive ? " editorSvg--lineTool" : ""}`}
        viewBox={viewBox}
        onPointerMove={onCanvasPointerMove}
        onPointerUp={onCanvasPointerUp}
        onPointerLeave={onCanvasPointerLeave}
        onPointerDown={onCanvasPointerDown}
        onContextMenu={onCanvasContextMenu}
        onWheel={(event) => {
          if (!event.deltaY) return;
          event.preventDefault();
          onZoomChange(event.deltaY < 0 ? 0.1 : -0.1);
        }}
        onDragOver={(event) => event.preventDefault()}
        onDrop={onCanvasDrop}
      >
        {image && <image href={imageUrl} x="0" y="0" width={image.naturalWidth} height={image.naturalHeight} preserveAspectRatio="xMidYMid meet" />}
        {activeMode === "polygon" && polygonView !== "edit" && actualPreview?.dataUrl && (
          <image
            href={actualPreview.dataUrl}
            x="0"
            y="0"
            width={image?.naturalWidth || 0}
            height={image?.naturalHeight || 0}
            preserveAspectRatio="none"
          />
        )}
        {activeMode === "polygon" && polygonView === "inspect" &&
          pieces.map((piece) => (
            <path
              key={piece.id}
              className={["pieceSelectable", selectedPieceIds.includes(piece.id) ? "selectedPiece" : ""].filter(Boolean).join(" ")}
              d={getPiecePath(piece, caches.piecePath)}
              onPointerDown={(event) => {
                event.stopPropagation();
                onTogglePieceSelection(piece.id);
              }}
            />
          ))}
        {activeMode === "polygon" && polygonView === "result" &&
          cuts.map((cut) => (
            <path key={cut.id} className="resultCutPath" style={{ stroke: cutLineColor }} d={getCutPath(cut, caches.cutPath)} />
          ))}
        {activeMode === "knob" && showKnobPieces &&
          knobPieces.map((piece) => (
            <path
              key={piece.id}
              className={selectedPieceIds.includes(piece.id) ? "knobPreview selectedPiece" : "knobPreview"}
              style={selectedPieceIds.includes(piece.id) ? undefined : { stroke: cutLineColor }}
              d={getKnobPiecePath(piece, caches.knobPiecePath)}
              onPointerDown={(event) => {
                event.stopPropagation();
                onTogglePieceSelection(piece.id);
              }}
            />
          ))}
        {activeMode === "polygon" && polygonView !== "result" &&
          cuts.map((cut) => (
            <g key={cut.id} className={cut.id === selectedId ? "selected" : ""}>
              <path
                className={cut.type === "preset_shape" ? "shapePath" : "cutPath"}
                style={{ stroke: cutLineColor }}
                d={getCutPath(cut, caches.cutPath)}
                onPointerDown={(event) => onBeginDragCut(event, cut.id, null)}
              />
              {cut.id === selectedId && cut.type === "preset_shape" && <ShapeTransform cut={cut} onBeginScale={onBeginScaleCut} />}
              {cut.id === selectedId && cut.type !== "preset_shape" &&
                cut.points.map((point, index) => (
                  <circle
                    key={`${cut.id}_${index}`}
                    className="handle"
                    cx={point.x}
                    cy={point.y}
                    r={10}
                    onPointerDown={(event) => onBeginDragCut(event, cut.id, index)}
                  />
                ))}
            </g>
          ))}
        {activeMode === "polygon" && polygonView === "edit" &&
          cutGaps.map((gap, index) => (
            <g key={`${gap.cutId}_${index}`} className="gapWarning">
              <line x1={gap.point.x} y1={gap.point.y} x2={gap.nearest.x} y2={gap.nearest.y} />
              <circle cx={gap.point.x} cy={gap.point.y} r={10} />
              <circle className="gapTarget" cx={gap.nearest.x} cy={gap.nearest.y} r={5} />
            </g>
          ))}
        {activeMode === "polygon" && polygonView === "edit" &&
          snapConnectionMarkers.map((marker) => (
            <g key={marker.id} className={`snapConnection snapConnection_${marker.kind}`}>
              <circle className="snapHalo" cx={marker.point.x} cy={marker.point.y} r={16} />
              <circle className="snapDot" cx={marker.point.x} cy={marker.point.y} r={3.5} />
            </g>
          ))}
        {activeMode === "polygon" && drawingCut && (
          <g className="drawingCutPreview">
            {drawingCut.points.length > 0 && (
              <path
                style={{ stroke: cutLineColor }}
                d={polylinePath(drawingHoverPoint ? [...drawingCut.points, drawingHoverPoint] : drawingCut.points)}
              />
            )}
            {drawingCut.points.map((point, index) => (
              <circle key={`${drawingCut.id}_${index}`} cx={point.x} cy={point.y} r={8} />
            ))}
          </g>
        )}
        {activeMode === "polygon" && polygonView === "edit" &&
          cutIntersections.map((intersection, index) => (
            <g key={`${intersection.aCutId}_${intersection.bCutId}_${index}`} className="cutIntersection">
              <path
                d={`M ${intersection.point.x} ${intersection.point.y - 7} L ${intersection.point.x + 7} ${intersection.point.y} L ${intersection.point.x} ${intersection.point.y + 7} L ${intersection.point.x - 7} ${intersection.point.y} Z`}
              />
            </g>
          ))}
      </svg>
    </div>
  );
});
