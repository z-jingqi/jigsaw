export const defaultLocale = "en";

export function localized(value: Record<string, string> | undefined, locale: string, fallback: string) {
  return value?.[locale] ?? value?.en ?? value?.["zh-Hans"] ?? value?.["zh-cn"] ?? value?.ja ?? fallback;
}

export function reservedI18n(value: Record<string, string> | undefined, primary: string, locale = defaultLocale) {
  return {
    ...(value || {}),
    [locale]: value?.[locale] ?? primary,
  };
}
