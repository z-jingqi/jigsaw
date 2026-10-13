"""Stage and verify generated artwork before replacing the live level catalog.

This tool processes saved files only. Image generation uses built-in imagegen.
The publish command copies validated files; obsolete folders are listed for
native PowerShell deletion after the new catalog passes runtime validation.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from level_artwork_plan import ROOT, WORK, entries

STAGE = WORK / "staging"
PRESERVED = ROOT / "levels/topic_03/cat_02"
SIZE = (1080, 1440)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


def snapshot() -> dict:
    path = WORK / "original-state.json"
    if path.exists():
        return read_json(path)
    catalog = read_json(ROOT / "levels/catalog.json")
    covers = {}
    for topic in catalog["topics"]:
        cover = ROOT / topic["cover"].removeprefix("res://")
        covers[topic["id"]] = {"path": str(cover.relative_to(ROOT)), "sha256": digest(cover)}
    data = {
        "catalog": catalog, "covers": covers,
        "space_cat": {str(p.relative_to(PRESERVED)): digest(p) for p in PRESERVED.rglob("*") if p.is_file()},
        "obsolete_folders": [str((ROOT / level["path"].removeprefix("res://")).parent) for topic in catalog["topics"] for level in topic["levels"] if level["id"] != "cat_02"],
    }
    write_json(path, data)
    return data


def prepare() -> None:
    snapshot()
    ready = 0
    for entry in entries():
        source = WORK / entry["source"]
        if not source.exists():
            continue
        folder = STAGE / "assets/artwork" / entry["theme_id"]
        folder.mkdir(parents=True, exist_ok=True)
        image_path = folder / (entry["id"] + ".webp")
        thumb_path = folder / (entry["id"] + "-thumb.webp")
        if not image_path.exists():
            with Image.open(source) as raw:
                raw.load()
                if abs(raw.width / raw.height - 0.75) > 0.015:
                    raise ValueError(f"Portrait ratio mismatch: {source}")
                if raw.width < 900 or raw.height < 1200:
                    raise ValueError(f"Source too small: {source}")
                image = raw.convert("RGB").resize(SIZE, Image.Resampling.LANCZOS)
                image.save(image_path, "WEBP", quality=90, method=6)
                image.resize((324, 432), Image.Resampling.LANCZOS).save(thumb_path, "WEBP", quality=85, method=6)
        config_path = STAGE / "levels" / entry["theme_id"] / entry["id"] / "level.json"
        if not config_path.exists():
            resource_folder = f"res://assets/artwork/{entry['theme_id']}/"
            write_json(config_path, {
                "version": 3, "id": entry["id"], "topic_id": entry["theme_id"],
                "title": entry["title"], "title_i18n": {"zh": entry["title"], "zh-Hans": entry["title"], "_": entry["title"]},
                "description": "", "image": {"path": resource_folder + image_path.name, "width": SIZE[0], "height": SIZE[1], "aspect_ratio": 0.75, "preset": "mobile_portrait_3x4"},
                "thumbnail": {"path": resource_folder + thumb_path.name, "width": 324, "height": 432},
                "background": {"type": "color", "color": "#F5F0E3"},
                "modes": {
					"polygon": {"pieces": [], "generator": {"target_count": 28 if entry["sort_order"] % 2 == 0 else 30}, "assist": {"outline": True, "seed": {"mode": "auto", "count": 1, "piece_ids": []}}},
					"knob": {"auto": True, "cols": 5, "rows": 6, "knob_size": 0.24},
					"swap": {"auto": True, "cols": 4, "rows": 6},
                },
            })
        ready += 1
    for cover_id in ("cover-shanhai", "cover-greek"):
        source = WORK / "sources" / (cover_id + ".png")
        if source.exists():
            target = STAGE / "covers" / (cover_id + ".webp")
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.exists():
                with Image.open(source) as raw:
                    raw.convert("RGB").resize((900, 1200), Image.Resampling.LANCZOS).save(target, "WEBP", quality=92, method=6)
    print(json.dumps({"ready": ready, "required": 79, "stage": str(STAGE)}))


def verify() -> dict:
    original = snapshot()
    problems = []
    images = []
    configs = []
    for entry in entries():
        path = STAGE / "levels" / entry["theme_id"] / entry["id"] / "level.json"
        if not path.exists():
            problems.append(f"Missing config: {entry['id']}")
            continue
        config = read_json(path)
        configs.append(config)
        if not config["modes"]["polygon"]["pieces"]:
            problems.append(f"Missing polygon geometry: {entry['id']}")
        for key in ("image", "thumbnail"):
            image_path = STAGE / config[key]["path"].removeprefix("res://")
            if not image_path.exists():
                problems.append(f"Missing {key}: {entry['id']}")
                continue
            with Image.open(image_path) as image:
                image.load()
                if image.size != (config[key]["width"], config[key]["height"]):
                    problems.append(f"Wrong {key} dimensions: {entry['id']}")
                if image.mode != "RGB":
                    problems.append(f"Unexpected alpha: {entry['id']}")
            if key == "image":
                images.append({"id": entry["id"], "path": str(image_path.relative_to(STAGE)), "sha256": digest(image_path), "bytes": image_path.stat().st_size})
    if len({i["sha256"] for i in images}) != len(images):
        problems.append("Duplicate image content")
    for relative, sha in original["space_cat"].items():
        if digest(PRESERVED / relative) != sha:
            problems.append(f"Space cat changed: {relative}")
    for theme_id, info in original["covers"].items():
        if theme_id not in ("topic_01", "topic_02") and digest(ROOT / info["path"]) != info["sha256"]:
            problems.append(f"Retained cover changed: {theme_id}")
    for cover in ("cover-shanhai", "cover-greek"):
        if not (STAGE / "covers" / (cover + ".webp")).exists():
            problems.append(f"Missing {cover}")
    result = {"ok": not problems, "new_level_count": len(configs), "images": images, "problems": problems}
    write_json(WORK / "content-verification.json", result)
    print(json.dumps({k: v for k, v in result.items() if k != "images"}, ensure_ascii=True))
    return result


def publish() -> None:
    verified = verify()
    if not verified["ok"] or verified["new_level_count"] != 79:
        raise ValueError("All new artwork and geometry must pass before publication")
    original = snapshot()
    catalog = original["catalog"]
    catalog["version"] = 5
    catalog["content_revision"] = "2026-10-artwork-2"
    for topic in catalog["topics"]:
        topic["levels"] = []
        if topic["id"] == "topic_03":
            topic["levels"].append({"id": "cat_02", "sort_order": 0, "path": "res://levels/topic_03/cat_02/level.json"})
        for entry in entries():
            if entry["theme_id"] == topic["id"]:
                topic["levels"].append({"id": entry["id"], "sort_order": entry["sort_order"], "path": f"res://levels/{entry['theme_id']}/{entry['id']}/level.json"})
    assert len(catalog["topics"]) == 8 and all(len(t["levels"]) == 10 for t in catalog["topics"])
    for branch in ("levels", "assets"):
        for path in (STAGE / branch).rglob("*"):
            if path.is_file():
                target = ROOT / path.relative_to(STAGE)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, target)
    for cover_id, target in (("cover-shanhai", original["covers"]["topic_01"]["path"]), ("cover-greek", original["covers"]["topic_02"]["path"])):
        shutil.copy2(STAGE / "covers" / (cover_id + ".webp"), ROOT / target)
    write_json(ROOT / "levels/catalog.json", catalog)
    write_json(WORK / "obsolete-folders.json", {"folders": original["obsolete_folders"]})
    print(json.dumps({"published": 80, "themes": 8, "obsolete_folders": len(original["obsolete_folders"])}))


def sheets() -> None:
    font_path = ROOT / "assets/fonts/noto/NotoSansSC[wght].ttf"
    font = ImageFont.truetype(str(font_path), 18)
    for theme in dict.fromkeys(e["theme_id"] for e in entries()):
        selected = [e for e in entries() if e["theme_id"] == theme]
        sheet = Image.new("RGB", (1080, 648), "#F5F0E3")
        draw = ImageDraw.Draw(sheet)
        for index, entry in enumerate(selected):
            source = WORK / entry["source"]
            if not source.exists():
                continue
            with Image.open(source) as image:
                image = image.convert("RGB").resize((198, 264), Image.Resampling.LANCZOS)
                x, y = (index % 5) * 216 + 9, (index // 5) * 324 + 12
                sheet.paste(image, (x, y))
                draw.text((x, y + 272), entry["title"], fill="#194F47", font=font)
        sheet.save(WORK / (theme + "-sheet.jpg"), quality=92)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("prepare", "verify", "publish", "sheets"))
    command = parser.parse_args().command
    {"prepare": prepare, "verify": verify, "publish": publish, "sheets": sheets}[command]()
