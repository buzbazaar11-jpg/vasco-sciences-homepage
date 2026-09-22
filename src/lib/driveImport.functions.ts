import { createServerFn } from "@tanstack/react-start";

const GATEWAY = "https://connector-gateway.lovable.dev/google_drive";

type DriveFile = { id: string; name: string; mimeType: string };

function authHeaders() {
  const lovableKey = process.env["LOVABLE_API_KEY"];
  const connKey = process.env["GOOGLE_DRIVE_API_KEY"];
  if (!lovableKey || !connKey) {
    throw new Error("Google Drive connection is not configured for this project.");
  }
  return {
    Authorization: `Bearer ${lovableKey}`,
    "X-Connection-Api-Key": connKey,
  };
}

async function driveList(query: string): Promise<DriveFile[]> {
  const url = new URL(`${GATEWAY}/drive/v3/files`);
  url.searchParams.set("q", query);
  url.searchParams.set("fields", "files(id,name,mimeType)");
  url.searchParams.set("pageSize", "200");
  url.searchParams.set("orderBy", "name");
  const res = await fetch(url.toString(), { headers: authHeaders() });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Google Drive request failed [${res.status}]: ${body}`);
  }
  const json = (await res.json()) as { files?: DriveFile[] };
  return json.files ?? [];
}

function extractFolderId(input: string): string {
  const trimmed = input.trim();
  if (/docs\.google\.com\/(document|spreadsheets|presentation)\//.test(trimmed)) {
    throw new Error(
      "Yeh Google Docs/Sheets ka link hai. Please Google Drive folder ka link dein, jaise: https://drive.google.com/drive/folders/XXXXXXXX",
    );
  }
  const m =
    trimmed.match(/\/folders\/([a-zA-Z0-9_-]+)/) ??
    trimmed.match(/[?&]id=([a-zA-Z0-9_-]+)/) ??
    trimmed.match(/^([a-zA-Z0-9_-]{15,})$/);
  if (!m?.[1]) {
    throw new Error(
      "Folder link samajh nahi aaya. Drive folder kholein aur address bar ka poora link paste karein (…/drive/folders/…).",
    );
  }
  return m[1];
}


export type DriveFolderImage = {
  folderName: string;
  fileId: string;
  fileName: string;
  imageCount: number;
};

/** Lists one representative image per sub-folder of a shared Drive folder. */
export const listDriveProductImages = createServerFn({ method: "GET" })
  .inputValidator((data: { folderUrl: string }) => data)
  .handler(async ({ data }): Promise<DriveFolderImage[]> => {
    const folderId = extractFolderId(data.folderUrl);
    const children = await driveList(`'${folderId}' in parents and trashed = false`);

    const results: DriveFolderImage[] = [];

    const looseImages = children.filter((f) => f.mimeType.startsWith("image/"));
    for (const img of looseImages) {
      results.push({
        folderName: img.name.replace(/\.[^/.]+$/, ""),
        fileId: img.id,
        fileName: img.name,
        imageCount: 1,
      });
    }

    const subFolders = children.filter((f) => f.mimeType === "application/vnd.google-apps.folder");
    for (const folder of subFolders) {
      const files = await driveList(`'${folder.id}' in parents and trashed = false`);
      const images = files.filter((f) => f.mimeType.startsWith("image/"));
      const first = images[0];
      if (!first) continue;
      results.push({
        folderName: folder.name,
        fileId: first.id,
        fileName: first.name,
        imageCount: images.length,
      });
    }

    return results;
  });

/** Downloads one Drive image and returns it as a base64 data URL. */
export const fetchDriveImage = createServerFn({ method: "GET" })
  .inputValidator((data: { fileId: string }) => data)
  .handler(async ({ data }): Promise<{ fileName: string; mimeType: string; dataUrl: string }> => {
    const metaRes = await fetch(
      `${GATEWAY}/drive/v3/files/${data.fileId}?fields=id,name,mimeType`,
      { headers: authHeaders() },
    );
    if (!metaRes.ok) {
      throw new Error(`Google Drive request failed [${metaRes.status}]: ${await metaRes.text()}`);
    }
    const meta = (await metaRes.json()) as DriveFile;

    const fileRes = await fetch(`${GATEWAY}/drive/v3/files/${data.fileId}?alt=media`, {
      headers: authHeaders(),
    });
    if (!fileRes.ok) {
      throw new Error(`Google Drive download failed [${fileRes.status}]: ${await fileRes.text()}`);
    }
    const buf = new Uint8Array(await fileRes.arrayBuffer());
    let binary = "";
    for (let i = 0; i < buf.length; i += 8192) {
      binary += String.fromCharCode(...buf.subarray(i, i + 8192));
    }
    const base64 = btoa(binary);
    const mimeType = meta.mimeType || "image/jpeg";

    return { fileName: meta.name, mimeType, dataUrl: `data:${mimeType};base64,${base64}` };
  });
