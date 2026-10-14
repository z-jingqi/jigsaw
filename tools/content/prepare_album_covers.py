"""Create lightweight album previews from the current theme covers."""

from pathlib import Path
import json

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]


def prepare(theme_ids: set[str] | None = None) -> None:
    catalog_path = ROOT / "levels/catalog.json"
    original = catalog_path.read_text(encoding="utf-8")
    catalog = json.loads(original)
    updated = original
    output = ROOT / "assets/artwork/album"
    output.mkdir(parents=True, exist_ok=True)
    total_bytes = 0
    covers = 0
    for topic in catalog["topics"]:
        if theme_ids is not None and topic["id"] not in theme_ids:
            continue
        relative = f"assets/artwork/album/{topic['id']}-cover.webp"
        target = ROOT / relative
        with Image.open(ROOT / topic["cover"].removeprefix("res://")) as source:
            image = ImageOps.fit(source.convert("RGB"), (324, 432), Image.Resampling.LANCZOS)
            image.save(target, "WEBP", quality=82, method=6)
        with Image.open(target) as verified:
            if verified.format != "WEBP" or verified.size != (324, 432):
                raise RuntimeError(f"Invalid album cover: {target}")
        if "cover_thumbnail" not in topic:
            marker = f'"cover": "{topic["cover"]}",'
            if updated.count(marker) != 1:
                raise RuntimeError(f"Ambiguous theme cover: {topic['id']}")
            updated = updated.replace(marker, marker + f'\n\t\t\t"cover_thumbnail": "res://{relative}",')
        elif topic["cover_thumbnail"] != f"res://{relative}":
            raise RuntimeError(f"Unexpected album cover path for {topic['id']}")
        total_bytes += target.stat().st_size
        covers += 1
    catalog_path.write_text(updated, encoding="utf-8", newline="")
    print(json.dumps({"ok": True, "covers": covers, "dimensions": [324, 432], "total_bytes": total_bytes}))


if __name__ == "__main__":
    prepare()
