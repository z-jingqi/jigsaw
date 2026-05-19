const viteEnv = (import.meta as unknown as { env?: Record<string, string | undefined> }).env || {};

export const googleClientId = viteEnv.VITE_GOOGLE_CLIENT_ID;
export const googleApiKey = viteEnv.VITE_GOOGLE_API_KEY;
export const googleDriveFolderMime = "application/vnd.google-apps.folder";
export const drivePickerMimeTypes = ["image/png", "image/jpeg", "image/webp", "image/gif", "image/svg+xml", googleDriveFolderMime].join(",");

export const portraitDeviceSizes = [
  { label: "iPhone SE", width: 375, height: 667 },
  { label: "iPhone 13/14/15", width: 390, height: 844 },
  { label: "iPhone Plus/Max", width: 430, height: 932 },
  { label: "iPad mini", width: 744, height: 1133 },
  { label: "iPad", width: 820, height: 1180 },
  { label: "iPad Air / Pro 11", width: 834, height: 1194 },
  { label: "iPad Pro 12.9", width: 1024, height: 1366 },
];
