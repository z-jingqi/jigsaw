#!/usr/bin/env python3
"""Prepare JigCat design assets and mock level data.

This script is intentionally project-specific. It normalizes the current design
drop from the user's Downloads folder into Godot-friendly asset names, trims
transparent UI art, converts playable images to compressed JPEG, and writes a
fresh swap-only catalog. List thumbnails are generated lazily at runtime.
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path
from typing import Any

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = Path("/Users/57block/Downloads/jigcat")
CREAM_RGB = (246, 235, 212)


UI_ASSETS = {
    "title.png": "assets/ui/title.png",
    "关卡名称背景横幅.png": "assets/ui/level_name_banner.png",
    "橄榄枝.png": "assets/ui/olive_branch.png",
    "多边形模式-已完成.png": "assets/icons/status/mode_polygon_done.png",
    "多边形模式-未完成.png": "assets/icons/status/mode_polygon_todo.png",
    "凹凸模式-已完成.png": "assets/icons/status/mode_knob_done.png",
    "凹凸模式-未完成.png": "assets/icons/status/mode_knob_todo.png",
    "交换模式-已完成.png": "assets/icons/status/mode_swap_done.png",
    "交换模式-未完成.png": "assets/icons/status/mode_swap_todo.png",
}


TOPICS = [
    {
        "id": "cats",
        "name": "猫系列",
        "cover_src": "猫系列封面.png",
        "levels": [
            {
                "id": "calico_cat",
                "title": "三花猫",
                "src": "Calico Cat.png",
                "description": "柔和花影里的三花猫，像一段安静又明亮的午后时光。",
            },
            {
                "id": "astronaut_cat",
                "title": "宇航员猫",
                "src": "宇航员猫.png",
                "description": "戴上头盔的小猫准备出发，把好奇心带到星星之间。",
            },
        ],
    },
    {
        "id": "dogs",
        "name": "狗系列",
        "cover_src": "狗系列封面.png",
        "levels": [
            {
                "id": "shiba",
                "title": "柴犬",
                "src": "柴犬.png",
                "description": "柴犬在暖光里望向远处，神情轻快而专注。",
            },
            {
                "id": "golden_retriever",
                "title": "金毛",
                "src": "金毛.png",
                "description": "金毛带着温顺的笑意，像阳光落在柔软的草地上。",
            },
        ],
    },
    {
        "id": "greek_myth",
        "name": "希腊神话",
        "cover_src": "希腊神话封面.png",
        "levels": [
            {
                "id": "trojan_horse",
                "title": "特洛伊木马",
                "src": "特洛伊木马.png",
                "description": "古老木马静立城前，传说的转折藏在沉默的轮廓里。",
            },
            {
                "id": "prometheus_fire",
                "title": "普罗米修斯盗火",
                "src": "普罗米修斯盗火.png",
                "description": "火光照亮神话的夜色，也照亮人类对光明的想象。",
            },
        ],
    },
]


def require_source(name: str) -> Path:
    path = SOURCE_DIR / name
    if not path.exists():
        raise FileNotFoundError(path)
    return path


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    return alpha.point(lambda value: 255 if value > 8 else 0).getbbox()


def trim_transparent(image: Image.Image, padding: int = 2) -> Image.Image:
    bbox = alpha_bbox(image)
    if bbox is None:
        return image.copy()
    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(image.width, right + padding)
    bottom = min(image.height, bottom + padding)
    return image.crop((left, top, right, bottom))


def save_png(src_name: str, rel_dst: str) -> None:
    dst = ROOT / rel_dst
    dst.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(require_source(src_name)) as image:
        output = trim_transparent(ImageOps.exif_transpose(image), 2).convert("RGBA")
        output.save(dst, format="PNG", optimize=True, compress_level=9)
    (dst.with_suffix(dst.suffix + ".import")).unlink(missing_ok=True)
    print(f"png {src_name} -> {rel_dst} ({output.width}x{output.height})")


def contain(image: Image.Image, max_size: tuple[int, int]) -> Image.Image:
    output = ImageOps.exif_transpose(image).convert("RGB")
    output.thumbnail(max_size, Image.Resampling.LANCZOS)
    return output


def save_jpg(src_name: str, rel_dst: str, max_size: tuple[int, int], quality: int = 86) -> tuple[int, int]:
    dst = ROOT / rel_dst
    dst.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(require_source(src_name)) as image:
        output = ImageOps.exif_transpose(image)
        if output.mode in {"RGBA", "LA"} or (output.mode == "P" and "transparency" in output.info):
            rgba = output.convert("RGBA")
            canvas = Image.new("RGBA", rgba.size, (*CREAM_RGB, 255))
            canvas.alpha_composite(rgba)
            output = canvas
        output = contain(output, max_size)
        output.save(dst, format="JPEG", quality=quality, optimize=True, progressive=True)
    (dst.with_suffix(dst.suffix + ".import")).unlink(missing_ok=True)
    print(f"jpg {src_name} -> {rel_dst} ({output.width}x{output.height})")
    return output.size


def res(path: str) -> str:
    return f"res://{path}"


def image_record(path: str, size: tuple[int, int]) -> dict[str, Any]:
    return {
        "path": res(path),
        "width": size[0],
        "height": size[1],
    }


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


def reset_levels() -> None:
    levels_dir = ROOT / "levels"
    if levels_dir.exists():
        shutil.rmtree(levels_dir)
    levels_dir.mkdir(parents=True, exist_ok=True)


def write_levels() -> None:
    reset_levels()
    catalog_topics: list[dict[str, Any]] = []
    for topic_index, topic in enumerate(TOPICS):
        topic_dir = f"levels/{topic['id']}"
        cover_size = save_jpg(topic["cover_src"], f"{topic_dir}/cover.jpg", (1024, 768), 86)
        catalog_levels: list[dict[str, Any]] = []
        for level_index, level in enumerate(topic["levels"]):
            level_dir = f"{topic_dir}/{level['id']}"
            source_path = f"{level_dir}/source.jpg"
            source_size = save_jpg(level["src"], source_path, (1440, 1920), 87)
            level_json = {
                "version": 2,
                "id": level["id"],
                "title": level["title"],
                "title_i18n": {"zh-Hans": level["title"], "_": level["title"]},
                "description": level["description"],
                "description_i18n": {"zh-Hans": level["description"], "_": level["description"]},
                "image": image_record(source_path, source_size),
                "assets": {
                    "default_image": image_record(source_path, source_size),
                },
                "background": {"type": "color", "color": "#F6EBD4"},
                "modes": {
                    "swap": {
                        "image": image_record(source_path, source_size),
                    },
                },
            }
            write_json(ROOT / level_dir / "level.json", level_json)
            catalog_levels.append(
                {
                    "id": level["id"],
                    "title": level["title"],
                    "title_i18n": {"zh-Hans": level["title"], "_": level["title"]},
                    "path": res(f"{level_dir}/level.json"),
                    "source": res(source_path),
                    "sort_order": level_index,
                }
            )
        catalog_topics.append(
            {
                "id": topic["id"],
                "name": topic["name"],
                "name_i18n": {"zh-Hans": topic["name"], "_": topic["name"]},
                "cover": res(f"{topic_dir}/cover.jpg"),
                "cover_size": {"width": cover_size[0], "height": cover_size[1]},
                "levels": catalog_levels,
                "sort_order": topic_index,
            }
        )
    write_json(ROOT / "levels/catalog.json", {"version": 2, "topics": catalog_topics})


def main() -> int:
    for src_name, rel_dst in UI_ASSETS.items():
        save_png(src_name, rel_dst)
    write_levels()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
