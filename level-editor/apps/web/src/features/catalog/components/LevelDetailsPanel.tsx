import type { CSSProperties } from "react";
import { Hexagon, Link2, Puzzle } from "lucide-react";
import type { CatalogLevel, CatalogTopic, LevelConfig, LevelImageConfig } from "../../../types";
import { Field } from "../../../shared/ui/Field";
import { PanelTitle } from "../../../shared/ui/PanelTitle";
import { SelectBox } from "../../../shared/ui/SelectBox";
import { ToggleGroup, ToggleGroupItem } from "../../../components/ui/toggle-group";
import { localized } from "../../../shared/lib/i18n";

type ModePreviewMode = {
  mode: "polygon" | "knob";
  label: string;
  icon: typeof Hexagon;
  image: LevelImageConfig | undefined;
  path: string;
  name: string;
  url: string;
};

type ModePreviewGroup = {
  path: string;
  url: string;
  modes: ModePreviewMode[];
};

type TableclothPreview = {
  type: "color" | "image";
  color: string;
  url: string;
  label: string;
};

type Props = {
  locale: string;
  selectedTopic: CatalogTopic | undefined;
  selectedLevel: CatalogLevel | undefined;
  selectedLevelDraft: LevelConfig | undefined;
  selectedModePreviews: ModePreviewGroup[];
  canMergeSelectedModeImages: boolean;
  onMergeSelectedModeImages: () => void;
  tableclothPreview: TableclothPreview;
  tableclothStyle: CSSProperties;
  backgroundImageOptions: { value: string; label: string }[];
  canUseBackgroundImage: boolean;
  onUpdateDescription: (description: string) => void;
  onUpdateBackground: (background: LevelConfig["background"]) => void;
  fallbackBackground: LevelConfig["background"];
};

export { type ModePreviewMode, type ModePreviewGroup, type TableclothPreview };

export function LevelDetailsPanel({
  locale,
  selectedTopic,
  selectedLevel,
  selectedLevelDraft,
  selectedModePreviews,
  canMergeSelectedModeImages,
  onMergeSelectedModeImages,
  tableclothPreview,
  tableclothStyle,
  backgroundImageOptions,
  canUseBackgroundImage,
  onUpdateDescription,
  onUpdateBackground,
  fallbackBackground,
}: Props) {
  const draftBackground = selectedLevelDraft?.background;
  const isImageBackground = draftBackground?.type === "image";

  return (
    <main className="min-h-0 overflow-auto p-6">
      <div className="mx-auto grid max-w-3xl gap-5">
        <section className="grid gap-3">
          <PanelTitle>主题</PanelTitle>
          {selectedTopic ? (
            <div className="rounded-md border border-stone-300 bg-white/70 px-3 py-2 text-sm text-ink">
              {localized(selectedTopic.name_i18n, locale, selectedTopic.name)}
            </div>
          ) : (
            <div className="rounded-md border border-dashed border-stone-300 bg-white/70 px-3 py-4 text-sm text-muted">请选择或创建主题。</div>
          )}
        </section>

        <section className="grid gap-3">
          <PanelTitle>关卡信息</PanelTitle>
          {selectedTopic && selectedLevel ? (
            <>
              <div className="rounded-md border border-stone-300 bg-white/70 px-3 py-2 text-sm text-ink">
                {localized(selectedLevel.title_i18n, locale, selectedLevel.title)}
              </div>
              <Field label="介绍">
                <textarea
                  className="input min-h-32"
                  value={localized(selectedLevelDraft?.description_i18n, locale, selectedLevelDraft?.description || "")}
                  onChange={(event) => onUpdateDescription(event.target.value)}
                />
              </Field>
              <section className="grid gap-3">
                <PanelTitle>关卡背景</PanelTitle>
                <div className="flex flex-wrap items-center gap-3">
                  <ToggleGroup
                    type="single"
                    value={canUseBackgroundImage ? draftBackground?.type || "color" : "color"}
                    onValueChange={(value: string) => {
                      if (value !== "color" && !(value === "image" && canUseBackgroundImage)) return;
                      const base = draftBackground || fallbackBackground;
                      onUpdateBackground({
                        ...base,
                        type: value as "color" | "image",
                        path: value === "image" ? base.path || backgroundImageOptions[0]?.value || "" : base.path || "",
                      });
                    }}
                  >
                    <ToggleGroupItem value="color">纯色</ToggleGroupItem>
                    <ToggleGroupItem value="image" disabled={!canUseBackgroundImage}>
                      图片
                    </ToggleGroupItem>
                  </ToggleGroup>
                  {canUseBackgroundImage && isImageBackground && draftBackground ? (
                    <div className="w-64">
                      <SelectBox
                        value={draftBackground.path || backgroundImageOptions[0]?.value || ""}
                        options={backgroundImageOptions}
                        onValueChange={(path: string) => onUpdateBackground({ ...draftBackground, type: "image", path })}
                        placeholder="选择背景图片"
                      />
                    </div>
                  ) : (
                    <input
                      className="input h-10 w-24 p-1"
                      type="color"
                      value={draftBackground?.color || "#F6EBD4"}
                      onChange={(event) =>
                        onUpdateBackground({
                          ...(draftBackground || fallbackBackground),
                          type: "color",
                          color: event.target.value,
                        })
                      }
                    />
                  )}
                </div>
                <div className="overflow-hidden rounded-md border border-stone-300 bg-white/70">
                  <div className="flex items-center justify-between border-b border-stone-200 px-3 py-2 text-sm font-medium text-ink">
                    <span>桌布预览</span>
                    <span className="text-xs font-normal text-muted">{tableclothPreview.label}</span>
                  </div>
                  <div className="p-4" style={tableclothStyle}>
                    <div className="grid min-h-28 place-items-center rounded-md border border-dashed border-stone-300/70 bg-white/35 px-4 text-xs text-ink/70 shadow-inner">
                      图片会在桌布内侧留出间距
                    </div>
                  </div>
                </div>
              </section>
              <section className="grid gap-3">
                <div className="flex items-center justify-between gap-2">
                  <PanelTitle>模式图片</PanelTitle>
                  {canMergeSelectedModeImages && (
                    <button className="btn !min-h-8 px-2 py-1 text-xs" onClick={onMergeSelectedModeImages}>
                      <Link2 size={14} />
                      合并同图
                    </button>
                  )}
                </div>
                <div className="grid gap-3 sm:grid-cols-2">
                  {selectedModePreviews.map((preview) => (
                    <div key={preview.path} className="overflow-hidden rounded-md border border-stone-300 bg-white/70">
                      <div className="flex items-center gap-2 border-b border-stone-200 px-3 py-2 text-sm font-medium">
                        {preview.modes.map((mode) => {
                          const Icon = mode.icon;
                          return (
                            <span key={mode.mode} className="inline-flex items-center gap-1">
                              <Icon size={15} />
                              {mode.label}
                            </span>
                          );
                        })}
                        {preview.modes.length > 1 && <span className="ml-auto rounded bg-clay/10 px-2 py-0.5 text-xs text-clay">同图</span>}
                      </div>
                      <div className="grid min-h-48 place-items-center p-4" style={tableclothStyle}>
                        <div className="grid h-44 w-full place-items-center rounded-md bg-white/20 p-4 shadow-inner backdrop-blur-[1px]">
                          <img className="h-full w-full object-contain drop-shadow-[0_3px_10px_rgba(90,58,34,0.18)]" src={preview.url} alt={`${preview.modes.map((mode) => mode.label).join("/")}图片`} />
                        </div>
                      </div>
                    </div>
                  ))}
                  {!selectedModePreviews.length && <div className="rounded-md border border-dashed border-stone-300 bg-white/70 px-3 py-4 text-sm text-muted">暂无模式图片</div>}
                </div>
              </section>
            </>
          ) : (
            <div className="rounded-md border border-dashed border-stone-300 bg-white/70 px-3 py-4 text-sm text-muted">请选择或创建关卡。</div>
          )}
        </section>
      </div>
    </main>
  );
}

export const modePreviewIcons = { polygon: Hexagon, knob: Puzzle } as const;
