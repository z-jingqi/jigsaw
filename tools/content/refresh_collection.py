"""Process all catalog artwork and stage the easier collection before publishing.

Artwork is generated with built-in imagegen; this tool only resizes, encodes,
compresses, verifies, and publishes saved sources. Original files are backed up.
Run build_polygons.ts against the prepared staging/levels directory in between.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
OLD_SOURCES = ROOT / ".artifacts/content-rebuild-20261005/sources"
SIZE = (1080, 1440)
THUMB_SIZE = (324, 432)
CONTENT_REVISION = "2026-10-artwork-4-easier"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def encode(source: Path, target: Path, size: tuple[int, int], quality: int, *, preserve_aspect: bool = False) -> dict:
    target.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as raw:
        image = ImageOps.exif_transpose(raw).convert("RGB")
        image = (ImageOps.contain if preserve_aspect else ImageOps.fit)(image, size, Image.Resampling.LANCZOS)
        output_size = image.size
        image.save(target, "WEBP", quality=quality, method=6)
    with Image.open(target) as decoded:
        decoded.load()
        if decoded.format != "WEBP" or decoded.mode != "RGB" or decoded.size != output_size:
            raise ValueError(f"Invalid processed image: {target}")
    return {"source": str(source), "source_sha256": sha(source), "source_bytes": source.stat().st_size,
            "path": str(target), "bytes": target.stat().st_size, "sha256": sha(target),
            "width": output_size[0], "height": output_size[1], "quality": quality, "method": 6}


def snapshot(work: Path) -> dict:
    file = work / "before.json"
    if file.exists():
        return read_json(file)
    catalog = read_json(ROOT / "levels/catalog.json")
    files: set[str] = {"levels/catalog.json"}
    levels = []
    for topic in catalog["topics"]:
        files.add(topic["cover"].removeprefix("res://"))
        for entry in topic["levels"]:
            relative = entry["path"].removeprefix("res://")
            config = read_json(ROOT / relative)
            files.add(relative)
            files.add(config["image"]["path"].removeprefix("res://"))
            files.add(config.get("thumbnail", {}).get("path", f"res://{Path(relative).parent.as_posix()}/thumbnail.webp").removeprefix("res://"))
            levels.append({"id": entry["id"], "theme_id": topic["id"], "path": relative,
                           "polygon": len(config["modes"]["polygon"]["pieces"]),
                           "knob": [config["modes"]["knob"]["cols"], config["modes"]["knob"]["rows"]],
                           "swap": [config["modes"]["swap"]["cols"], config["modes"]["swap"]["rows"]]})
    hashes = {}
    for relative in sorted(files):
        source = ROOT / relative
        if not source.is_file():
            raise FileNotFoundError(source)
        backup = work / "original-files" / relative
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, backup)
        hashes[relative] = sha(source)
    value = {"catalog": catalog, "levels": levels, "files": hashes}
    write_json(file, value)
    return value


def prepare(work: Path) -> None:
    before = snapshot(work)
    stage = work / "staging"
    records = []
    catalog = before["catalog"]
    catalog["content_revision"] = CONTENT_REVISION
    for topic in catalog["topics"]:
        for index, entry in enumerate(topic["levels"]):
            config = read_json(work / "original-files" / entry["path"].removeprefix("res://"))
            if topic["id"] == "topic_01":
                source = work / "sources" / (entry["id"] + ".png")
            else:
                source = OLD_SOURCES / (entry["id"] + ".png")
                if not source.exists():
                    source = work / "original-files" / config["image"]["path"].removeprefix("res://")
            if not source.exists():
                raise FileNotFoundError(f"Artwork source is missing: {source}")
            with Image.open(source) as raw:
                if abs(raw.width / raw.height - 0.75) > 0.02:
                    raise ValueError(f"Wrong artwork aspect ratio: {source}")
            folder = f"assets/artwork/{topic['id']}"
            image_relative = f"{folder}/{entry['id']}.webp"
            thumb_relative = f"{folder}/{entry['id']}-thumb.webp"
            for kind, relative, size, quality in (("image", image_relative, SIZE, 86), ("thumbnail", thumb_relative, THUMB_SIZE, 82)):
                record = encode(source, stage / relative, size, quality)
                record.update({"id": entry["id"], "kind": kind, "relative_path": relative})
                records.append(record)
                config[kind] = {"path": "res://" + relative, "width": size[0], "height": size[1]}
            config["image"].update({"aspect_ratio": 0.75, "preset": "mobile_portrait_3x4"})
            polygon = config["modes"]["polygon"]
            polygon["pieces"] = []
            polygon["generator"] = {"target_count": 28 if index % 2 == 0 else 30}
            config["modes"]["knob"].update({"auto": True, "cols": 5, "rows": 6})
            config["modes"]["swap"].update({"auto": True, "cols": 4, "rows": 6})
            if entry["id"] == "shanhai_v2_01":
                config["title"] = "九尾狐"
                config["title_i18n"] = {"zh": "九尾狐", "zh-Hans": "九尾狐", "_": "九尾狐"}
            write_json(stage / entry["path"].removeprefix("res://"), config)
        cover_relative = topic["cover"].removeprefix("res://")
        cover_source = work / "sources/cover-shanhai.png" if topic["id"] == "topic_01" else work / "original-files" / cover_relative
        record = encode(cover_source, stage / cover_relative, (900, 1200), 86, preserve_aspect=True)
        record.update({"id": topic["id"], "kind": "cover", "relative_path": cover_relative})
        records.append(record)
        print(json.dumps({"prepared_theme": topic["id"], "levels": len(topic["levels"])}), flush=True)
    write_json(stage / "levels/catalog.json", catalog)
    write_json(work / "processed-images.json", {"images": records})


def verify(work: Path) -> dict:
    stage = work / "staging"
    catalog = read_json(stage / "levels/catalog.json")
    problems = []
    counts = []
    hashes = []
    for topic in catalog["topics"]:
        for entry in topic["levels"]:
            config = read_json(stage / entry["path"].removeprefix("res://"))
            modes = config["modes"]
            count = len(modes["polygon"]["pieces"])
            if count not in (28, 30) or modes["polygon"]["generator"].get("actual_count") != count:
                problems.append(f"Wrong polygon count: {entry['id']}/{count}")
            for mode, dimensions in (("knob", (5, 6)), ("swap", (4, 6))):
                if (modes[mode]["cols"], modes[mode]["rows"]) != dimensions:
                    problems.append(f"Wrong {mode} dimensions: {entry['id']}")
            for kind, expected in (("image", SIZE), ("thumbnail", THUMB_SIZE)):
                path = stage / config[kind]["path"].removeprefix("res://")
                with Image.open(path) as image:
                    image.load()
                    if image.format != "WEBP" or image.mode != "RGB" or image.size != expected:
                        problems.append(f"Invalid {kind}: {entry['id']}")
                if kind == "image":
                    hashes.append(sha(path))
            counts.append({"id": entry["id"], "polygon": count, "knob": 30, "swap": 24})
        with Image.open(stage / topic["cover"].removeprefix("res://")) as cover:
            cover.load()
            source = work / "sources/cover-shanhai.png" if topic["id"] == "topic_01" else work / "original-files" / topic["cover"].removeprefix("res://")
            with Image.open(source) as original:
                aspect_error = abs(cover.width / cover.height - original.width / original.height)
            if cover.format != "WEBP" or cover.width > 900 or cover.height > 1200 or aspect_error > 0.002:
                problems.append(f"Invalid cover: {topic['id']}")
    if len(counts) != 80 or len(set(hashes)) != 80:
        problems.append("The collection must contain 80 different level images")
    result = {"ok": not problems, "levels": counts, "images": 168, "problems": problems}
    write_json(work / "verification.json", result)
    print(json.dumps({key: value for key, value in result.items() if key != "levels"}), flush=True)
    return result


def restyle(work: Path) -> None:
    """Replace Shanhaijing artwork without regenerating the accepted easier geometry."""
    before = snapshot(work)
    stage = work / "staging"
    shutil.copytree(work / "original-files", stage, dirs_exist_ok=True)
    catalog = before["catalog"]
    catalog["content_revision"] = CONTENT_REVISION
    topic = next(value for value in catalog["topics"] if value["id"] == "topic_01")
    records = []
    for entry in topic["levels"]:
        relative_config = entry["path"].removeprefix("res://")
        config = read_json(work / "original-files" / relative_config)
        source = work / "sources" / (entry["id"] + ".png")
        with Image.open(source) as image:
            if abs(image.width / image.height - 0.75) > 0.02:
                raise ValueError(f"Wrong artwork aspect ratio: {source}")
        for kind, size, quality in (("image", SIZE, 86), ("thumbnail", THUMB_SIZE, 82)):
            relative = config[kind]["path"].removeprefix("res://")
            record = encode(source, stage / relative, size, quality)
            record.update({"id": entry["id"], "kind": kind, "relative_path": relative})
            records.append(record)
        write_json(stage / relative_config, config)
    cover_relative = topic["cover"].removeprefix("res://")
    record = encode(work / "sources/cover-shanhai.png", stage / cover_relative, (900, 1200), 86, preserve_aspect=True)
    record.update({"id": topic["id"], "kind": "cover", "relative_path": cover_relative})
    records.append(record)
    write_json(stage / "levels/catalog.json", catalog)
    write_json(work / "processed-images.json", {"images": records})
    print(json.dumps({"restyled_levels": len(topic["levels"]), "processed_images": len(records)}), flush=True)


def publish(work: Path) -> None:
    result = verify(work)
    if not result["ok"]:
        raise ValueError("Staged collection failed verification")
    for source in (work / "staging").rglob("*"):
        if source.is_file():
            target = ROOT / source.relative_to(work / "staging")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    print(json.dumps({"published": len(result["levels"]), "images": result["images"]}), flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("snapshot", "prepare", "restyle", "verify", "publish"))
    parser.add_argument("--work", type=Path, default=ROOT / ".artifacts/shanhai-style-20261005")
    args = parser.parse_args()
    globals()[args.command](args.work.resolve())


if __name__ == "__main__":
    main()
