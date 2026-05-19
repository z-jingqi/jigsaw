export const defaultLocale = "zh-cn";

export function localized(value: Record<string, string> | undefined, locale: string, fallback: string) {
  return value?.[locale] ?? value?.["zh-Hans"] ?? value?.en ?? fallback;
}

export function reservedI18n(value: Record<string, string> | undefined, primary: string, locale = defaultLocale) {
  return {
    ...(value || {}),
    [locale]: value?.[locale] ?? primary,
  };
}
