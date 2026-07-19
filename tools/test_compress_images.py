from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

from tools.compress_images import compress_one, transparency_is_preserved


def patterned_image(size: tuple[int, int]) -> Image.Image:
    image = Image.new("RGB", size)
    pixels = image.load()
    for y in range(size[1]):
        for x in range(size[0]):
            pixels[x, y] = ((x * 17 + y * 3) % 256, (x * 5 + y * 11) % 256, (x * 13 + y * 7) % 256)
    return image


def compress(
    src: Path,
    dst: Path,
    target_bytes: int | None = None,
    output_format: str | None = None,
    webp_quality: int = 76,
):
    return compress_one(
        src,
        dst,
        min_savings=1,
        min_savings_percent=1.0,
        png_colors=256,
        jpeg_quality=88,
        jpeg_min_quality=60,
        webp_quality=webp_quality,
        target_bytes=target_bytes,
        output_format=output_format,
    )


class CompressImagesTest(unittest.TestCase):
    def test_small_jpeg_is_copied_without_reencoding(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            src = root / "source.jpg"
            dst = root / "out" / "source.jpg"
            patterned_image((160, 200)).save(src, format="JPEG", quality=76)

            result = compress(src, dst, target_bytes=100 * 1024)

            self.assertEqual(result.status, "copied")
            self.assertEqual(src.read_bytes(), dst.read_bytes())

    def test_target_size_selects_a_lower_jpeg_quality(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            src = root / "large.jpg"
            patterned_image((720, 960)).save(src, format="JPEG", quality=100, subsampling=0)
            before = src.stat().st_size

            result = compress(src, src, target_bytes=220 * 1024)

            self.assertEqual(result.status, "wrote")
            self.assertLess(src.stat().st_size, before)
            self.assertLessEqual(src.stat().st_size, 220 * 1024)

    def test_second_pass_is_stable(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            src = Path(temp_dir) / "stable.jpg"
            patterned_image((480, 640)).save(src, format="JPEG", quality=100, subsampling=0)

            first = compress(src, src)
            second = compress(src, src)

            self.assertEqual(first.status, "wrote")
            self.assertEqual(second.status, "kept")

    def test_png_alpha_and_transparent_pixels_are_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            src = root / "alpha.png"
            dst = root / "out" / "alpha.png"
            image = Image.new("RGBA", (240, 180), (17, 33, 91, 0))
            draw = ImageDraw.Draw(image)
            draw.rounded_rectangle((30, 20, 210, 160), radius=24, fill=(230, 110, 60, 220))
            image.save(src, format="PNG")

            result = compress(src, dst)

            self.assertIn(result.status, {"wrote", "copied"})
            self.assertTrue(dst.exists())
            self.assertTrue(transparency_is_preserved(src, dst))

    def test_png_can_be_converted_to_webp_at_cover_quality(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            src = root / "cover.png"
            dst = root / "out" / "cover.webp"
            patterned_image((480, 960)).save(src, format="PNG")

            result = compress(src, dst, output_format="WEBP")

            self.assertEqual(result.status, "wrote")
            with Image.open(dst) as output:
                self.assertEqual(output.format, "WEBP")
                self.assertEqual(output.size, (480, 960))
            self.assertIn("quality=76", result.detail)

    def test_webp_conversion_preserves_alpha_geometry(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            src = root / "alpha.png"
            dst = root / "alpha.webp"
            image = Image.new("RGBA", (240, 180), (17, 33, 91, 0))
            draw = ImageDraw.Draw(image)
            draw.rounded_rectangle((30, 20, 210, 160), radius=24, fill=(230, 110, 60, 220))
            image.save(src, format="PNG")

            result = compress(src, dst, output_format="WEBP")

            self.assertEqual(result.status, "wrote")
            self.assertTrue(transparency_is_preserved(src, dst, preserve_transparent_rgb=False))


if __name__ == "__main__":
    unittest.main()
