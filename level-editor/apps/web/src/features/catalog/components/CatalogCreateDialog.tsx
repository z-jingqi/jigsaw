import { Check, X } from "lucide-react";
import type { CatalogTopic } from "../../../types";
import { Field } from "../../../shared/ui/Field";
import { localized } from "../../../shared/lib/i18n";
import { idFromEnglishName } from "../../../shared/lib/ids";

type Props = {
  open: "topic" | "level" | null;
  locale: string;
  topics: CatalogTopic[];
  topicName: string;
  topicId: string;
  levelTitle: string;
  levelDescription: string;
  levelTopicId: string;
  onTopicNameChange: (value: string) => void;
  onTopicIdChange: (value: string) => void;
  onLevelTitleChange: (value: string) => void;
  onLevelDescriptionChange: (value: string) => void;
  onLevelTopicIdChange: (value: string) => void;
  onCreateTopic: () => void;
  onCreateLevel: () => void;
  onClose: () => void;
};

export function CatalogCreateDialog({
  open,
  locale,
  topics,
  topicName,
  topicId,
  levelTitle,
  levelDescription,
  levelTopicId,
  onTopicNameChange,
  onTopicIdChange,
  onLevelTitleChange,
  onLevelDescriptionChange,
  onLevelTopicIdChange,
  onCreateTopic,
  onCreateLevel,
  onClose,
}: Props) {
  if (!open) return null;
  const onConfirm = open === "topic" ? onCreateTopic : onCreateLevel;
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/35 px-4">
      <div className="w-full max-w-md rounded-md border border-stone-300 bg-paper p-5 text-ink shadow-xl">
        <div className="flex items-start justify-between gap-4">
          <h2 className="text-lg font-semibold">{open === "topic" ? "创建主题" : "创建关卡"}</h2>
          <button className="iconBtn !min-h-8" onClick={onClose} aria-label="关闭">
            <X size={16} />
          </button>
        </div>
        <div className="mt-4 grid gap-3">
          {open === "topic" ? (
            <>
              <Field label="主题名">
                <input
                  className="input"
                  autoFocus
                  value={topicName}
                  onChange={(event) => onTopicNameChange(event.target.value)}
                  onKeyDown={(event) => {
                    if (event.key === "Enter") onCreateTopic();
                  }}
                />
              </Field>
              <Field label="英文名称">
                <input
                  className="input"
                  value={topicId}
                  onChange={(event) => onTopicIdChange(idFromEnglishName(event.target.value, "topic", []))}
                  onKeyDown={(event) => {
                    if (event.key === "Enter") onCreateTopic();
                  }}
                />
              </Field>
            </>
          ) : (
            <>
              <Field label="主题">
                <select className="input" value={levelTopicId} onChange={(event) => onLevelTopicIdChange(event.target.value)}>
                  {topics.map((topic) => (
                    <option key={topic.id} value={topic.id}>{localized(topic.name_i18n, locale, topic.name)}</option>
                  ))}
                </select>
              </Field>
              <Field label="关卡名">
                <input className="input" autoFocus value={levelTitle} onChange={(event) => onLevelTitleChange(event.target.value)} />
              </Field>
              <Field label="介绍">
                <textarea className="input min-h-24" value={levelDescription} onChange={(event) => onLevelDescriptionChange(event.target.value)} />
              </Field>
            </>
          )}
          <div className="mt-2 grid grid-cols-2 gap-2">
            <button className="btn" onClick={onClose}>取消</button>
            <button className="btnPrimary" onClick={onConfirm}>
              <Check size={16} />
              创建
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
