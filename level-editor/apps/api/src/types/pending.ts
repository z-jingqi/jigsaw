import type { ImageInfo } from "./image.js";
import type { ProcessStepType } from "./process.js";

export type PendingImageKind = "image" | "tablecloth";

export type PendingImageItem = {
	id: string;
	name: string;
	kind: PendingImageKind;
	path: string;
	url: string;
	source_info: ImageInfo;
	processed: boolean;
	processed_path?: string;
	processed_url?: string;
	processed_info?: ImageInfo;
	processed_at?: string;
	applied_step_types?: ProcessStepType[];
	pending_step_types?: ProcessStepType[];
	compression_stable?: boolean;
	was_processed_before_preview?: boolean;
	saved_modes?: Array<"polygon" | "knob" | "swap">;
	editor_state?: PendingImageEditorState;
	folder?: string;
	created_at: string;
};

export type PendingImageEditorModeState = {
	dirty?: boolean;
	completed?: boolean;
	saved?: boolean;
	cuts?: Array<any>;
	pieces?: Array<any>;
	knob_pieces?: Array<any>;
	analysis_dirty?: boolean;
};

export type PendingImageEditorState = {
	polygon?: PendingImageEditorModeState;
	knob?: PendingImageEditorModeState;
	swap?: PendingImageEditorModeState;
};

export type PendingImagesData = {
	items: PendingImageItem[];
	folders?: string[];
};
