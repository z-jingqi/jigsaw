"""Split the approved 2x2 illustration sheet into full-bleed theme covers."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageOps


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--output', type=Path, default=Path('assets/ui/home/library'))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    source = Image.open(args.source).convert('RGB')
    width, height = source.size
    report = []
    for name, x, y in [('flowers', 0, 0), ('ocean', 1, 0), ('birds', 0, 1), ('forest', 1, 1)]:
        box = (x * width // 2, y * height // 2, (x + 1) * width // 2, (y + 1) * height // 2)
        cover = ImageOps.fit(source.crop(box), (600, 900), method=Image.Resampling.LANCZOS)
        path = args.output / f'{name}.webp'
        cover.save(path, 'WEBP', quality=92, method=6)
        saved = Image.open(path)
        report.append({'path': str(path), 'size': saved.size, 'mode': saved.mode, 'bytes': path.stat().st_size})
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
