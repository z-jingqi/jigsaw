extends RefCounted
class_name GameStrings

const TEXT := {
	"en": {
		"no_topics": "No topics yet",
		"enter_topic": "Enter theme",
		"all_topics": "All themes",
		"no_levels": "No levels yet",
		"series_progress": "Progress",
		"mode_empty": "This level has no playable modes yet.",
		"start_game": "Start",
		"mode_polygon": "Polygon",
		"mode_knob": "Jigsaw",
		"mode_swap": "Swap",
		"done": "Completed",
		"todo": "Not completed",
		"replay": "Play again",
		"continue": "Continue",
		"in_progress": "In progress",
		"back": "Back",
		"hint": "Hint",
		"shift_row_up": "Row up",
		"shift_row_down": "Row down",
		"return_levels": "Level list",
		"return_topics": "Topics",
		"confirm": "Confirm",
		"settings_title": "Settings",
		"music": "Music",
		"sfx": "Sound effects",
		"haptics": "Haptics",
		"settings_done": "Done",
		"reduce_motion": "Reduce motion",
		"piece_edges": "Piece edge contrast",
		"edge_auto": "Automatic",
		"edge_dark": "Dark",
		"edge_light": "Light",
		"random_rotation": "Random piece rotation (polygon / jigsaw)",
		"random_rotation_next": "Random rotation changes apply the next time you enter a level.",
		"tutorial_swap": "Drag one tile onto another to swap.",
		"tutorial_drag": "Drag matching pieces together to snap.",
		"tutorial_title": "How to play",
		"guide_skip": "Skip",
		"guide_swipe": "Swipe left or right to explore themes",
		"guide_swipe_hint": "←   Swipe   →",
		"guide_enter": "Tap the cover to open its levels",
		"guide_enter_hint": "Tap to play",
		"got_it": "Got it",
		"complete": "Puzzle complete",
		"completed_mode": "Completed: %s",
		"next": "Next",
		"switch_mode": "Other mode"
	},
	"zh": {
		"no_topics": "暂无主题",
		"enter_topic": "进入主题",
		"all_topics": "全部主题",
		"no_levels": "暂无关卡",
		"series_progress": "进度",
		"mode_empty": "这个关卡还没有可玩的模式。",
		"start_game": "开始游戏",
		"mode_polygon": "多边形模式",
		"mode_knob": "经典拼图模式",
		"mode_swap": "方格交换",
		"done": "已完成",
		"todo": "未完成",
		"replay": "再玩一次",
		"continue": "继续",
		"in_progress": "进行中",
		"back": "返回",
		"hint": "提示",
		"shift_row_up": "上移一行",
		"shift_row_down": "下移一行",
		"return_levels": "返回关卡列表",
		"return_topics": "返回主题选择",
		"confirm": "确认",
		"settings_title": "设置",
		"music": "音乐",
		"sfx": "音效",
		"haptics": "震动",
		"settings_done": "完成",
		"reduce_motion": "减少动态效果",
		"piece_edges": "碎片边线对比度",
		"edge_auto": "自动",
		"edge_dark": "深色",
		"edge_light": "浅色",
		"random_rotation": "碎片随机旋转（多边形 / 凹凸）",
		"random_rotation_next": "随机旋转设置将在下次进入关卡时生效。",
		"tutorial_swap": "拖动图片块，交换位置。",
		"tutorial_drag": "拖动碎片拼合，对齐后自动吸附。",
		"tutorial_title": "玩法说明",
		"guide_skip": "跳过",
		"guide_swipe": "左右滑动，探索不同主题",
		"guide_swipe_hint": "←   左右滑动   →",
		"guide_enter": "点击主题封面，进入关卡列表",
		"guide_enter_hint": "点击开始",
		"got_it": "知道了",
		"complete": "拼图完成",
		"completed_mode": "已完成：%s",
		"next": "下一关",
		"switch_mode": "换个模式"
	},
	"ja": {
		"no_topics": "テーマはまだありません",
		"enter_topic": "テーマへ",
		"all_topics": "すべて",
		"no_levels": "レベルはまだありません",
		"series_progress": "進行度",
		"mode_empty": "このレベルにはまだ遊べるモードがありません。",
		"start_game": "スタート",
		"mode_polygon": "ポリゴン",
		"mode_knob": "ジグソー",
		"mode_swap": "入れ替え",
		"done": "完成済み",
		"todo": "未完成",
		"replay": "もう一度",
		"continue": "続きから",
		"in_progress": "進行中",
		"back": "戻る",
		"hint": "ヒント",
		"shift_row_up": "一行上へ",
		"shift_row_down": "一行下へ",
		"return_levels": "レベル一覧",
		"return_topics": "テーマへ",
		"confirm": "確認",
		"settings_title": "設定",
		"music": "音楽",
		"sfx": "効果音",
		"haptics": "振動",
		"settings_done": "完了",
		"reduce_motion": "視差効果を減らす",
		"piece_edges": "ピース境界線",
		"edge_auto": "自動",
		"edge_dark": "濃い色",
		"edge_light": "明るい色",
		"random_rotation": "ピースをランダム回転（ポリゴン / ジグソー）",
		"random_rotation_next": "ランダム回転の変更は次にレベルへ入るときに反映されます。",
		"tutorial_swap": "タイルを重ねて入れ替えます。",
		"tutorial_drag": "ピースを合わせると吸着します。",
		"tutorial_title": "遊び方",
		"guide_skip": "スキップ",
		"guide_swipe": "左右にスワイプしてテーマを選びます",
		"guide_swipe_hint": "←   スワイプ   →",
		"guide_enter": "テーマをタップしてレベルへ進みます",
		"guide_enter_hint": "タップして開始",
		"got_it": "OK",
		"complete": "パズル完成",
		"completed_mode": "完成：%s",
		"next": "次へ",
		"switch_mode": "別モード"
	}
}

var locale := "en"


func set_locale(next_locale: String) -> void:
	locale = normalize_locale(next_locale)


func text(key: String) -> String:
	var table: Dictionary = TEXT.get(locale, TEXT["en"])
	return str(table.get(key, TEXT["en"].get(key, key)))


static func detect_locale() -> String:
	return normalize_locale(OS.get_locale())


static func normalize_locale(value: String) -> String:
	var normalized := value.replace("_", "-").to_lower()
	if normalized.begins_with("zh"):
		return "zh"
	if normalized.begins_with("ja"):
		return "ja"
	return "en"
