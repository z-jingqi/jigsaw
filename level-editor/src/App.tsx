import { useEffect, useMemo, useRef, useState } from "react";
import { Download, FileJson, Magnet, Plus, RefreshCcw, Trash2, Upload } from "lucide-react";
import {
  DEFAULT_BROWSER_IMAGE,
  DEFAULT_IMAGE_PATH,
  catmullRomPath,
  detectImageOutline,
  generateFractureNetwork,
  makeEmptyLevel,
  presetCut,
  samplePath,
  serializePoints,
  snapPoint,
  uid,
} from "./geometry";
import type { CutLine, CutTemplate, LevelConfig, OutlineAnalysis, PieceCell, Point } from "./types";

const snapThreshold = 18;

type DragState = {
  cutId: string;
  pointIndex: number | null;
  start: Point;
  original: CutLine;
};

function App() {
  const [level, setLevel] = useState<LevelConfig>(() => makeEmptyLevel());
  const [image, setImage] = useState<HTMLImageElement | null>(null);
  const [imageUrl, setImageUrl] = useState(DEFAULT_BROWSER_IMAGE);
  const [analysis, setAnalysis] = useState<OutlineAnalysis>({ outline: [], edgePoints: [], bounds: null });
  const [cuts, setCuts] = useState<CutLine[]>([]);
  const [pieces, setPieces] = useState<PieceCell[]>([]);
  const [selectedId, setSelectedId] = useState("");
  const [drag, setDrag] = useState<DragState | null>(null);
  const [targetPieces, setTargetPieces] = useState(14);
  const [snapEnabled, setSnapEnabled] = useState(true);
  const [showPieces, setShowPieces] = useState(true);
  const [jsonText, setJsonText] = useState("");
  const svgRef = useRef<SVGSVGElement | null>(null);

  useEffect(() => {
    loadBrowserImage(DEFAULT_BROWSER_IMAGE, "cat_moon.png", DEFAULT_IMAGE_PATH);
  }, []);

  useEffect(() => {
    if (!image) return;
    const nextAnalysis = detectImageOutline(image);
    setAnalysis(nextAnalysis);
    setLevel((current) => ({
      ...current,
      image: {
        ...current.image,
        width: image.naturalWidth,
        height: image.naturalHeight,
      },
      editor: {
        ...current.editor,
        outline: serializePoints(nextAnalysis.outline),
      },
    }));
  }, [image]);

  const viewBox = useMemo(() => {
    if (!image) return "0 0 1024 1024";
    return `0 0 ${image.naturalWidth} ${image.naturalHeight}`;
  }, [image]);

  const outlinePath = useMemo(() => {
    if (!analysis.outline.length) return "";
    return catmullRomPath(analysis.outline, 0.35, true);
  }, [analysis.outline]);

  const selected = cuts.find((cut) => cut.id === selectedId);
  const snapPoints = useMemo(() => {
    if (!analysis.outline.length) return [];
    return samplePath([...analysis.outline, analysis.outline[0]], Math.min(300, Math.max(100, analysis.outline.length)));
  }, [analysis.outline]);

  function loadBrowserImage(src: string, name: string, godotPath: string) {
    const next = new Image();
    next.onload = () => {
      setImage(next);
      setImageUrl(src);
      setLevel((current) => ({
        ...current,
        image: {
          ...current.image,
          name,
          path: godotPath || current.image.path,
          width: next.naturalWidth,
          height: next.naturalHeight,
        },
      }));
    };
    next.src = src;
  }

  function onUploadImage(file?: File) {
    if (!file) return;
    loadBrowserImage(URL.createObjectURL(file), file.name, level.image.path || DEFAULT_IMAGE_PATH);
  }

  function updateLevel<T extends keyof LevelConfig>(key: T, value: LevelConfig[T]) {
    setLevel((current) => ({ ...current, [key]: value }));
  }

  function updateImagePath(path: string) {
    setLevel((current) => ({ ...current, image: { ...current.image, path } }));
  }

  function updateBackground<K extends keyof LevelConfig["background"]>(key: K, value: LevelConfig["background"][K]) {
    setLevel((current) => ({ ...current, background: { ...current.background, [key]: value } }));
  }

  function autoGenerate() {
    const result = generateFractureNetwork(analysis.outline, analysis.bounds, targetPieces);
    setCuts(result.cuts);
    setPieces(result.pieces);
    setSelectedId(result.cuts[0]?.id || "");
  }

  function addPreset(template: CutTemplate) {
    if (!analysis.bounds) return;
    const next = presetCut(template, analysis.bounds);
    setCuts((current) => [...current, next]);
    setSelectedId(next.id);
  }

  function addBridgeCut() {
    if (!analysis.outline.length) return;
    const a = analysis.outline[Math.floor(analysis.outline.length * 0.12)];
    const b = analysis.outline[Math.floor(analysis.outline.length * 0.62)];
    const next: CutLine = {
      id: uid("cut"),
      type: "fracture",
      template: "classic",
      points: samplePath([a, b], 7),
    };
    setCuts((current) => [...current, next]);
    setSelectedId(next.id);
  }

  function removeSelected() {
    if (!selectedId) return;
    setCuts((current) => current.filter((cut) => cut.id !== selectedId));
    setSelectedId("");
  }

  function svgPoint(event: React.PointerEvent<SVGElement>): Point {
    const svg = svgRef.current;
    if (!svg) return { x: 0, y: 0 };
    const rect = svg.getBoundingClientRect();
    const [minX, minY, width, height] = viewBox.split(" ").map(Number);
    return {
      x: minX + ((event.clientX - rect.left) / rect.width) * width,
      y: minY + ((event.clientY - rect.top) / rect.height) * height,
    };
  }

  function beginDrag(event: React.PointerEvent<SVGElement>, cutId: string, pointIndex: number | null) {
    event.stopPropagation();
    const cut = cuts.find((item) => item.id === cutId);
    if (!cut) return;
    setSelectedId(cutId);
    setDrag({
      cutId,
      pointIndex,
      start: svgPoint(event),
      original: structuredClone(cut),
    });
    event.currentTarget.setPointerCapture(event.pointerId);
  }

  function moveDrag(event: React.PointerEvent<SVGSVGElement>) {
    if (!drag) return;
    const currentPoint = svgPoint(event);
    const dx = currentPoint.x - drag.start.x;
    const dy = currentPoint.y - drag.start.y;
    setCuts((items) =>
      items.map((cut) => {
        if (cut.id !== drag.cutId) return cut;
        const next = structuredClone(drag.original);
        if (drag.pointIndex === null) {
          next.points = next.points.map((point) => ({ x: point.x + dx, y: point.y + dy }));
        } else {
          next.points[drag.pointIndex] = { x: next.points[drag.pointIndex].x + dx, y: next.points[drag.pointIndex].y + dy };
        }
        if (snapEnabled) {
          next.points = next.points.map((point, index) => {
            const isEndpoint = index === 0 || index === next.points.length - 1;
            const canSnap = drag.pointIndex === null ? isEndpoint : drag.pointIndex === index;
            if (!canSnap) return point;
            const hit = snapPoint(point, snapPoints, cuts, snapThreshold, next.id);
            return hit ? { ...hit.point } : point;
          });
        }
        return next;
      }),
    );
  }

  function buildJson() {
    const data: LevelConfig = {
      ...level,
      editor: {
        outline: serializePoints(analysis.outline),
        cuts: cuts
          .filter((cut) => cut.type === "fracture")
          .map((cut) => ({
            id: cut.id,
            type: cut.type,
            template: cut.template,
            points: serializePoints(cut.points),
          })),
        shapes: cuts
          .filter((cut) => cut.type === "preset_shape")
          .map((cut) => ({
            id: cut.id,
            type: cut.type,
            template: cut.template,
            points: serializePoints(cut.points),
          })),
        pieces: pieces.map((piece) => ({ id: piece.id, points: serializePoints(piece.points) })),
      },
    };
    const text = JSON.stringify(data, null, 2);
    setJsonText(text);
    return text;
  }

  function downloadJson() {
    const text = jsonText || buildJson();
    const blob = new Blob([text], { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `${level.id || "level"}.json`;
    a.click();
    URL.revokeObjectURL(a.href);
  }

  function importJson(file?: File) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      const data = JSON.parse(String(reader.result)) as LevelConfig;
      setLevel({ ...makeEmptyLevel(), ...data });
      const importedCuts: CutLine[] = [
        ...(data.editor?.cuts || []).map((cut) => ({ ...cut, points: cut.points.map(([x, y]) => ({ x, y })) })),
        ...(data.editor?.shapes || []).map((shape) => ({ ...shape, points: shape.points.map(([x, y]) => ({ x, y })) })),
      ];
      setCuts(importedCuts);
      setPieces((data.editor?.pieces || []).map((piece) => ({ ...piece, points: piece.points.map(([x, y]) => ({ x, y })) })));
      setSelectedId(importedCuts[0]?.id || "");
      setJsonText(JSON.stringify(data, null, 2));
    };
    reader.readAsText(file);
  }

  return (
    <div className="grid min-h-screen grid-cols-[320px_minmax(720px,1fr)_340px] bg-linen text-ink max-xl:grid-cols-[290px_minmax(520px,1fr)]">
      <aside className="overflow-auto border-r border-stone-300 bg-paper p-4">
        <div className="flex items-start gap-3 border-b border-stone-300 pb-4">
          <FileJson className="mt-1 text-clay" size={22} />
          <div>
            <h1 className="text-xl font-semibold">关卡编辑器</h1>
            <p className="text-sm text-muted">TypeScript · Tailwind · 非网格切割</p>
          </div>
        </div>

        <section className="mt-5 grid gap-3">
          <PanelTitle>关卡</PanelTitle>
          <Field label="标题">
            <input className="input" value={level.title} onChange={(event) => updateLevel("title", event.target.value)} />
          </Field>
          <Field label="介绍">
            <textarea className="input min-h-24" value={level.description} onChange={(event) => updateLevel("description", event.target.value)} />
          </Field>
          <Field label="Godot 图片路径">
            <input className="input" value={level.image.path} onChange={(event) => updateImagePath(event.target.value)} />
          </Field>
          <label className="fileButton">
            <Upload size={16} />
            上传原图预览
            <input hidden type="file" accept="image/*" onChange={(event) => onUploadImage(event.target.files?.[0])} />
          </label>
        </section>

        <section className="mt-6 grid gap-3">
          <PanelTitle>背景</PanelTitle>
          <div className="grid grid-cols-[1fr_56px] gap-2">
            <select className="input" value={level.background.type} onChange={(event) => updateBackground("type", event.target.value as "color" | "image")}>
              <option value="color">纯色</option>
              <option value="image">图片</option>
            </select>
            <input className="h-10 rounded-md border border-stone-300" type="color" value={level.background.color} onChange={(event) => updateBackground("color", event.target.value)} />
          </div>
          <Field label="背景图片路径">
            <input className="input" value={level.background.path} onChange={(event) => updateBackground("path", event.target.value)} />
          </Field>
        </section>

        <section className="mt-6 grid gap-3">
          <PanelTitle>自动生成</PanelTitle>
          <Field label={`目标碎片数：${targetPieces}`}>
            <input type="range" min="6" max="36" value={targetPieces} onChange={(event) => setTargetPieces(Number(event.target.value))} />
          </Field>
          <button className="btnPrimary" onClick={autoGenerate}>
            <RefreshCcw size={16} />
            生成碎片切割线
          </button>
          <button className="btn" onClick={addBridgeCut}>
            <Plus size={16} />
            添加平滑切割线
          </button>
        </section>
      </aside>

      <main className="grid min-w-0 grid-rows-[auto_1fr]">
        <div className="flex min-h-14 items-center gap-2 overflow-auto border-b border-stone-300 bg-[#f7efe2] px-3">
          <button className={snapEnabled ? "btnActive" : "btn"} onClick={() => setSnapEnabled((value) => !value)}>
            <Magnet size={16} />
            边缘吸附
          </button>
          <button className={showPieces ? "btnActive" : "btn"} onClick={() => setShowPieces((value) => !value)}>
            碎片预览
          </button>
          {(["classic", "circle", "star", "blob", "zigzag", "crescent"] as CutTemplate[]).map((template) => (
            <button key={template} className="btn" onClick={() => addPreset(template)}>
              {templateName(template)}
            </button>
          ))}
          <button className="btnDanger" onClick={removeSelected}>
            <Trash2 size={16} />
          </button>
        </div>

        <div className="grid place-items-center p-5" style={{ background: level.background.color }}>
          <svg
            ref={svgRef}
            className="h-[min(calc(100vh-96px),760px)] w-full max-w-[1040px] border border-black/15 bg-white/20"
            viewBox={viewBox}
            onPointerMove={moveDrag}
            onPointerUp={() => setDrag(null)}
            onPointerLeave={() => setDrag(null)}
            onPointerDown={() => setSelectedId("")}
          >
            {image && <image href={imageUrl} x="0" y="0" width={image.naturalWidth} height={image.naturalHeight} preserveAspectRatio="xMidYMid meet" />}
            {showPieces &&
              pieces.map((piece) => <path key={piece.id} className="piecePreview" d={catmullRomPath(piece.points, 0.2, true)} />)}
            {outlinePath && <path className="outlinePath" d={outlinePath} />}
            {cuts.map((cut) => (
              <g key={cut.id} className={cut.id === selectedId ? "selected" : ""}>
                <path
                  className={cut.type === "preset_shape" ? "shapePath" : "cutPath"}
                  d={catmullRomPath(cut.points, cut.type === "preset_shape" ? 0.25 : 0.9, cut.type === "preset_shape")}
                  onPointerDown={(event) => beginDrag(event, cut.id, null)}
                />
                {cut.id === selectedId &&
                  cut.points.map((point, index) => (
                    <circle key={`${cut.id}_${index}`} className="handle" cx={point.x} cy={point.y} r={10} onPointerDown={(event) => beginDrag(event, cut.id, index)} />
                  ))}
              </g>
            ))}
          </svg>
        </div>
      </main>

      <aside className="overflow-auto border-l border-stone-300 bg-paper p-4 max-xl:col-span-2 max-xl:border-l-0 max-xl:border-t">
        <section>
          <PanelTitle>对象</PanelTitle>
          <div className="grid gap-2">
            {cuts.map((cut) => (
              <button key={cut.id} className={cut.id === selectedId ? "objectActive" : "object"} onClick={() => setSelectedId(cut.id)}>
                <span>{templateName(cut.template)}</span>
                <small>{cut.type === "preset_shape" ? "预设图形" : "切割边"}</small>
              </button>
            ))}
          </div>
          {selected && <p className="mt-3 text-sm text-muted">选中：{selected.template}，拖拽整条线或白色节点，端点会吸附到外轮廓/其他分割线。</p>}
        </section>

        <section className="mt-6 grid gap-3">
          <PanelTitle>导出</PanelTitle>
          <button className="btnPrimary" onClick={buildJson}>
            <FileJson size={16} />
            生成 JSON
          </button>
          <button className="btn" onClick={downloadJson}>
            <Download size={16} />
            下载 JSON
          </button>
          <label className="fileButton">
            <Upload size={16} />
            导入 JSON
            <input hidden type="file" accept="application/json,.json" onChange={(event) => importJson(event.target.files?.[0])} />
          </label>
          <textarea className="input min-h-[340px] font-mono text-xs" value={jsonText} onChange={(event) => setJsonText(event.target.value)} spellCheck={false} />
        </section>

        <section className="mt-6 border-t border-stone-300 pt-4 text-sm text-muted">
          <PanelTitle>规则</PanelTitle>
          <p>这里不做自由手绘。自动生成会创建非网格碎片边界；新增线条也是平滑曲线或预设图形，靠吸附来保证连接。</p>
        </section>
      </aside>
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

function templateName(template: CutTemplate) {
  const names: Record<CutTemplate, string> = {
    classic: "经典凹凸",
    round: "圆形凸起",
    circle: "圆形",
    star: "五角星",
    blob: "圆润块",
    zigzag: "折线",
    crescent: "月牙",
  };
  return names[template];
}

export default App;
