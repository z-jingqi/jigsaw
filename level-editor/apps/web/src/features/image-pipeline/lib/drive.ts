export function driveSkipMessage(skipped?: Array<{ name: string; folder: string; reason: string }>) {
  const reason = skipped?.[0]?.reason || "";
  if (reason.includes("accessNotConfigured")) {
    return "Google Drive API 未启用，或当前 API Key / OAuth Client 不属于已启用 Drive API 的同一个 Google Cloud 项目。";
  }
  if (reason.includes("insufficient authentication scopes")) {
    return "Google Drive 授权 scope 不足，请重新授权 Drive 访问权限。";
  }
  if (reason.includes("insufficientFilePermissions")) {
    return "当前账号没有读取这个 Drive 文件夹的权限。";
  }
  if (reason.includes("folder_has_no_images")) {
    return "这个 Drive 文件夹中没有可导入的直接图片文件。";
  }
  return reason ? `Google Drive 跳过：${reason}` : "";
}

export function loadScriptOnce(src: string) {
  return new Promise<void>((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(`script[src="${src}"]`);
    if (existing?.dataset.loaded === "true") {
      resolve();
      return;
    }
    const script = existing || document.createElement("script");
    script.src = src;
    script.async = true;
    script.onload = () => {
      script.dataset.loaded = "true";
      resolve();
    };
    script.onerror = () => reject(new Error(`failed to load ${src}`));
    if (!existing) document.head.appendChild(script);
  });
}
