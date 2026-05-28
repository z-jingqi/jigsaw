import { X } from "lucide-react";
import { Field } from "../../../shared/ui/Field";
import { Input } from "../../../shared/ui/Input";
import { SelectBox, type SelectOption } from "../../../shared/ui/SelectBox";
import { Textarea } from "../../../shared/ui/Textarea";
import { ToggleGroup, ToggleGroupItem } from "../../../components/ui/toggle-group";
import { idFromEnglishName } from "../../../shared/lib/ids";
import { displayPendingImageName } from "../lib/editor";
import type { PendingImageItem } from "../../../types";
import type { EditMode, SaveModeDialogState } from "../types";

type Props = {
  state: SaveModeDialogState;
  topicOptions: SelectOption[];
  saveLevelOptions: SelectOption[];
  backgroundImages: PendingImageItem[];
  backgroundImageOptions: SelectOption[];
  canUseBackgroundImage: boolean;
  activePendingImage: PendingImageItem | null;
  activeMode: EditMode;
  onChange: (next: SaveModeDialogState) => void;
  onClose: () => void;
  onSave: () => void;
  onTopicChange: (topicId: string) => void;
  onLevelChange: (levelId: string) => void;
};

export function EditorSaveDialog({
  state,
  topicOptions,
  saveLevelOptions,
  backgroundImages,
  backgroundImageOptions,
  canUseBackgroundImage,
  activePendingImage,
  activeMode,
  onChange,
  onClose,
  onSave,
  onTopicChange,
  onLevelChange,
}: Props) {
  if (!state.open) return null;
  const activeModeLabel = activeMode === "polygon" ? "多边形" : activeMode === "knob" ? "凹凸" : "方格交换";

  const setBackgroundType = (value: string) => {
    if (value === "color") onChange({ ...state, newBackgroundType: "color" });
    if (value === "image" && canUseBackgroundImage) {
      onChange({
        ...state,
        newBackgroundType: "image",
        newBackgroundPath: state.newBackgroundPath || backgroundImages[0]?.path || "",
      });
    }
  };

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/35 px-4">
      <div className="w-full max-w-lg rounded-lg border border-stone-300 bg-paper p-5 text-ink shadow-xl">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h2 className="text-xl font-semibold">保存当前模式</h2>
            <p className="mt-1 text-sm text-muted">当前图片会复制到目标关卡文件夹。</p>
          </div>
          <button className="iconBtn" onClick={onClose} aria-label="关闭">
            <X size={18} />
          </button>
        </div>
        <div className="mt-5 grid gap-3">
          <div className="grid grid-cols-2 gap-2">
            <button
              className={state.targetMode === "existing" ? "btnActive" : "btn"}
              onClick={() => onChange({ ...state, targetMode: "existing" })}
            >
              选择关卡
            </button>
            <button
              className={state.targetMode === "new" ? "btnActive" : "btn"}
              onClick={() => onChange({ ...state, targetMode: "new" })}
            >
              新增关卡
            </button>
          </div>
          {state.targetMode === "existing" ? (
            <>
              <Field label="主题">
                <SelectBox value={state.topicId} options={topicOptions} onValueChange={onTopicChange} placeholder="选择主题" />
              </Field>
              <Field label="关卡">
                <SelectBox value={state.levelId} options={saveLevelOptions} onValueChange={onLevelChange} placeholder="选择关卡" />
              </Field>
            </>
          ) : (
            <>
              <label className="flex items-center gap-2 text-sm text-ink">
                <input
                  className="h-4 w-4 accent-clay"
                  type="checkbox"
                  checked={state.newTopic}
                  onChange={(event) => onChange({ ...state, newTopic: event.target.checked })}
                />
                新增主题
              </label>
              {state.newTopic ? (
                <>
                  <Field label="主题">
                    <Input value={state.newTopicName} onChange={(event) => onChange({ ...state, newTopicName: event.target.value })} />
                  </Field>
                  <Field label="英文名称">
                    <Input
                      value={state.newTopicId}
                      onChange={(event) => onChange({ ...state, newTopicId: idFromEnglishName(event.target.value, "topic", []) })}
                    />
                  </Field>
                </>
              ) : (
                <Field label="主题">
                  <SelectBox
                    value={state.topicId}
                    options={topicOptions}
                    onValueChange={(topicId) => onChange({ ...state, topicId })}
                    placeholder="选择主题"
                  />
                </Field>
              )}
              <Field label="关卡">
                <Input value={state.newLevelTitle} onChange={(event) => onChange({ ...state, newLevelTitle: event.target.value })} />
              </Field>
              <Field label="关卡介绍">
                <Textarea
                  className="min-h-20"
                  value={state.newLevelDescription}
                  onChange={(event) => onChange({ ...state, newLevelDescription: event.target.value })}
                />
              </Field>
              <div className="grid gap-2 rounded-md border border-stone-200 bg-white/60 p-3">
                <div className="text-sm font-medium text-ink">关卡背景</div>
                <div className="flex flex-wrap items-center gap-3">
                  <ToggleGroup type="single" value={state.newBackgroundType} onValueChange={setBackgroundType}>
                    <ToggleGroupItem value="color">纯色</ToggleGroupItem>
                    <ToggleGroupItem value="image" disabled={!canUseBackgroundImage}>
                      图片
                    </ToggleGroupItem>
                  </ToggleGroup>
                  {state.newBackgroundType === "image" && canUseBackgroundImage ? (
                    <div className="w-64">
                      <SelectBox
                        value={state.newBackgroundPath}
                        options={backgroundImageOptions}
                        onValueChange={(newBackgroundPath) => onChange({ ...state, newBackgroundPath })}
                        placeholder="选择背景图片"
                      />
                    </div>
                  ) : (
                    <input
                      className="h-9 w-24 rounded border border-stone-300 bg-white p-1"
                      type="color"
                      value={state.newBackgroundColor}
                      onChange={(event) => onChange({ ...state, newBackgroundColor: event.target.value })}
                      aria-label="背景颜色"
                    />
                  )}
                  {!canUseBackgroundImage && <span className="text-xs text-muted">暂无背景图片</span>}
                </div>
              </div>
            </>
          )}
          <div className="px-1 py-1 text-sm text-muted">
            写入模式：{activeModeLabel}；图片：
            {activePendingImage ? displayPendingImageName(activePendingImage) : "未选择"}
          </div>
        </div>
        <div className="mt-5 grid grid-cols-2 gap-2">
          <button className="btn" onClick={onClose}>
            取消
          </button>
          <button className="btnPrimary" onClick={onSave}>
            保存
          </button>
        </div>
      </div>
    </div>
  );
}
