from __future__ import annotations

import tempfile
import sys
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))

from prepare_catalog_png import prepare_catalog_png, visible_bounds


class PrepareCatalogPngTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)

    def tearDown(self) -> None:
        self.directory.cleanup()

    def test_normalizes_a_transparent_horizontal_render(self) -> None:
        source = self.root / "entrada.png"
        destination = self.root / "salida.png"
        image = Image.new("RGBA", (1000, 700), (0, 0, 0, 0))
        ImageDraw.Draw(image).rounded_rectangle(
            (50, 120, 950, 520),
            radius=80,
            fill=(70, 80, 90, 255),
        )
        image.save(source)

        result = prepare_catalog_png(source, destination)

        prepared = Image.open(destination).convert("RGBA")
        bounds = visible_bounds(prepared)
        self.assertEqual(prepared.size, (1200, 1200))
        self.assertLessEqual(abs((bounds[2] - bounds[0]) - 1032), 2)
        self.assertTrue(380 <= bounds[3] - bounds[1] <= 560)
        self.assertEqual(result["preset"], "calzado-perfil")

    def test_removes_only_the_chroma_connected_to_the_edges(self) -> None:
        source = self.root / "entrada-croma.png"
        destination = self.root / "salida-croma.png"
        chroma = (255, 0, 255)
        image = Image.new("RGBA", (1000, 700), (*chroma, 255))
        draw = ImageDraw.Draw(image)
        draw.rectangle((50, 120, 950, 520), fill=(60, 70, 80, 255))
        draw.rectangle((450, 280, 550, 370), fill=(*chroma, 255))
        image.save(source)

        prepare_catalog_png(source, destination, chroma=chroma)

        prepared = Image.open(destination).convert("RGBA")
        self.assertEqual(prepared.getpixel((0, 0))[3], 0)
        self.assertGreater(
            sum(
                1
                for red, green, blue, alpha in prepared.get_flattened_data()
                if (red, green, blue) == chroma and alpha > 8
            ),
            0,
        )

    def test_removes_a_low_alpha_halo(self) -> None:
        source = self.root / "entrada-halo.png"
        destination = self.root / "salida-halo.png"
        image = Image.new("RGBA", (1000, 700), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        draw.rectangle((30, 100, 970, 540), fill=(180, 90, 20, 100))
        draw.rectangle((50, 120, 950, 520), fill=(60, 70, 80, 255))
        image.save(source)

        prepare_catalog_png(source, destination)

        prepared = Image.open(destination).convert("RGBA")
        self.assertFalse(
            any(
                red > 120 and green < 120 and blue < 60 and alpha > 8
                for red, green, blue, alpha in prepared.get_flattened_data()
            )
        )

    def test_rejects_an_empty_render(self) -> None:
        source = self.root / "vacio.png"
        Image.new("RGBA", (500, 500), (0, 0, 0, 0)).save(source)

        with self.assertRaisesRegex(ValueError, "ningún píxel visible"):
            prepare_catalog_png(source, self.root / "salida.png")

    def test_rejects_a_vertical_composition(self) -> None:
        source = self.root / "vertical.png"
        image = Image.new("RGBA", (700, 1000), (0, 0, 0, 0))
        ImageDraw.Draw(image).rectangle(
            (100, 50, 550, 950),
            fill=(60, 70, 80, 255),
        )
        image.save(source)

        with self.assertRaisesRegex(ValueError, "Regenera la composición"):
            prepare_catalog_png(source, self.root / "salida.png")


if __name__ == "__main__":
    unittest.main()
