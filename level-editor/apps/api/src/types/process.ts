export type ProcessStepType = "convert_jpg" | "remove_background" | "trim_transparent" | "compress";

export type ProcessStep = {
	type: ProcessStepType;
	tolerance?: number;
	padding?: number;
	quality?: number;
	background?: string;
};
