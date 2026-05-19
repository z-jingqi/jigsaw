import { readFile, stat } from "node:fs/promises";
import path from "node:path";
import type { ImageInfo } from "../types/image.js";

export async function imageInfoForPath(target: string): Promise<ImageInfo> {
	const [fileStat, bytes] = await Promise.all([stat(target), readFile(target)]);
	const size = imageDimensions(bytes);
	return {
		format: imageFormat(target, bytes),
		width: size.width,
		height: size.height,
		bytes: fileStat.size,
	};
}

export function imageFormat(fileName: string, bytes: Buffer) {
	const ext = path.extname(fileName).toLowerCase();
	if (bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return "PNG";
	if (bytes[0] === 0xff && bytes[1] === 0xd8) return "JPG";
	if (bytes.toString("ascii", 0, 4) === "RIFF" && bytes.toString("ascii", 8, 12) === "WEBP") return "WEBP";
	if (ext === ".jpg" || ext === ".jpeg") return "JPG";
	if (ext === ".webp") return "WEBP";
	if (ext === ".png") return "PNG";
	return ext.replace(/^\./, "").toUpperCase() || "UNKNOWN";
}

export function imageDimensions(bytes: Buffer) {
	if (bytes.length >= 24 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
		return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
	}
	if (bytes.length >= 4 && bytes[0] === 0xff && bytes[1] === 0xd8) {
		const size = jpegDimensions(bytes);
		if (size) return size;
	}
	if (bytes.length >= 30 && bytes.toString("ascii", 0, 4) === "RIFF" && bytes.toString("ascii", 8, 12) === "WEBP") {
		const size = webpDimensions(bytes);
		if (size) return size;
	}
	return { width: 0, height: 0 };
}

function jpegDimensions(bytes: Buffer) {
	let offset = 2;
	while (offset + 9 < bytes.length) {
		if (bytes[offset] !== 0xff) {
			offset += 1;
			continue;
		}
		const marker = bytes[offset + 1];
		offset += 2;
		if (marker === 0xd9 || marker === 0xda) break;
		if (offset + 2 > bytes.length) break;
		const length = bytes.readUInt16BE(offset);
		if (length < 2 || offset + length > bytes.length) break;
		if ((marker >= 0xc0 && marker <= 0xc3) || (marker >= 0xc5 && marker <= 0xc7) || (marker >= 0xc9 && marker <= 0xcb) || (marker >= 0xcd && marker <= 0xcf)) {
			return { width: bytes.readUInt16BE(offset + 5), height: bytes.readUInt16BE(offset + 3) };
		}
		offset += length;
	}
	return null;
}

function webpDimensions(bytes: Buffer) {
	const type = bytes.toString("ascii", 12, 16);
	if (type === "VP8X" && bytes.length >= 30) {
		return {
			width: 1 + bytes.readUIntLE(24, 3),
			height: 1 + bytes.readUIntLE(27, 3),
		};
	}
	if (type === "VP8L" && bytes.length >= 25) {
		const bits = bytes.readUInt32LE(21);
		return {
			width: (bits & 0x3fff) + 1,
			height: ((bits >> 14) & 0x3fff) + 1,
		};
	}
	if (type === "VP8 " && bytes.length >= 30) {
		return {
			width: bytes.readUInt16LE(26) & 0x3fff,
			height: bytes.readUInt16LE(28) & 0x3fff,
		};
	}
	return null;
}
