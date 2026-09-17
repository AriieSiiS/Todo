"""Prepara un PNG de calzado con composición de catálogo determinista."""

from __future__ import annotations

import argparse
import json
import math
from collections import deque
from pathlib import Path

try:
    from PIL import Image, ImageOps
except ImportError as error:  # pragma: no cover - mensaje para el entorno real.
    raise SystemExit("Instala Pillow para preparar imágenes de catálogo.") from error


CANVAS_SIZE = 1200
VISIBLE_WIDTH = 1032
MIN_ASPECT_RATIO = 1.85
MAX_ASPECT_RATIO = 2.70
ALPHA_EMPTY_LIMIT = 8
ALPHA_SHADOW_LIMIT = 160
ALPHA_OPAQUE_LIMIT = 248


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Retira el fondo y normaliza un render para el catálogo de Todo.",
    )
    parser.add_argument("source")
    parser.add_argument("destination")
    parser.add_argument(
        "--preset",
        choices=("calzado-perfil",),
        default="calzado-perfil",
    )
    parser.add_argument(
        "--chroma",
        help="Color hexadecimal del fondo plano, por ejemplo '#FF00FF'.",
    )
    parser.add_argument("--tolerance", type=int, default=48)
    return parser


def parse_hex_color(value: str) -> tuple[int, int, int]:
    normalized = value.strip().removeprefix("#")
    if len(normalized) != 6:
        raise ValueError("El croma debe tener el formato hexadecimal #RRGGBB.")
    try:
        return tuple(int(normalized[index:index + 2], 16) for index in (0, 2, 4))  # type: ignore[return-value]
    except ValueError as error:
        raise ValueError("El croma debe tener el formato hexadecimal #RRGGBB.") from error


def color_distance(
    pixel: tuple[int, int, int, int],
    chroma: tuple[int, int, int],
) -> float:
    return math.sqrt(sum((pixel[index] - chroma[index]) ** 2 for index in range(3)))


def remove_connected_background(
    image: Image.Image,
    chroma: tuple[int, int, int] | None,
    tolerance: int,
) -> None:
    pixels = image.load()
    width, height = image.size
    visited = bytearray(width * height)
    pending: deque[tuple[int, int]] = deque()

    def is_background(x: int, y: int) -> bool:
        pixel = pixels[x, y]
        return pixel[3] <= ALPHA_EMPTY_LIMIT or (
            chroma is not None and color_distance(pixel, chroma) <= tolerance
        )

    def enqueue(x: int, y: int) -> None:
        offset = y * width + x
        if visited[offset] or not is_background(x, y):
            return
        visited[offset] = 1
        pending.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while pending:
        x, y = pending.popleft()
        pixels[x, y] = (0, 0, 0, 0)
        if x > 0:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y > 0:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)


def clean_alpha(image: Image.Image) -> None:
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha <= ALPHA_SHADOW_LIMIT:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            if alpha >= ALPHA_OPAQUE_LIMIT:
                pixels[x, y] = (red, green, blue, 255)
                continue
            normalized = round(
                (alpha - ALPHA_SHADOW_LIMIT)
                * 255
                / (ALPHA_OPAQUE_LIMIT - ALPHA_SHADOW_LIMIT)
            )
            pixels[x, y] = (red, green, blue, normalized)


def visible_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A").point(
        lambda value: 255 if value > ALPHA_EMPTY_LIMIT else 0
    )
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("El render no contiene ningún píxel visible.")
    return bounds


def prepare_catalog_png(
    source: Path,
    destination: Path,
    *,
    chroma: tuple[int, int, int] | None = None,
    tolerance: int = 48,
) -> dict[str, object]:
    with Image.open(source) as opened:
        image = ImageOps.exif_transpose(opened).convert("RGBA")
    if image.getchannel("A").getextrema()[0] == 255 and chroma is None:
        raise ValueError("Un render opaco requiere indicar --chroma.")

    remove_connected_background(image, chroma, tolerance)
    clean_alpha(image)
    left, top, right, bottom = visible_bounds(image)
    width = right - left
    height = bottom - top
    aspect_ratio = width / height
    if not MIN_ASPECT_RATIO <= aspect_ratio <= MAX_ASPECT_RATIO:
        raise ValueError(
            "La composición debe mostrar una sola pieza de calzado en horizontal y tener una relación "
            f"visible entre {MIN_ASPECT_RATIO:.2f}:1 y {MAX_ASPECT_RATIO:.2f}:1; "
            f"el render recibido tiene {aspect_ratio:.2f}:1. Regenera la composición, "
            "no la gires automáticamente."
        )

    cropped = image.crop((left, top, right, bottom))
    target_height = round(VISIBLE_WIDTH / aspect_ratio)
    resized = cropped.resize(
        (VISIBLE_WIDTH, target_height),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(
        resized,
        (
            (CANVAS_SIZE - VISIBLE_WIDTH) // 2,
            (CANVAS_SIZE - target_height) // 2,
        ),
    )
    final_bounds = visible_bounds(canvas)
    final_width = final_bounds[2] - final_bounds[0]
    final_height = final_bounds[3] - final_bounds[1]
    if abs(final_width - VISIBLE_WIDTH) > 2 or not 380 <= final_height <= 560:
        raise ValueError("La normalización final no cumple la caja visual de Calzado.")

    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, "PNG", compress_level=6)
    return {
        "preset": "calzado-perfil",
        "source": str(source.resolve()),
        "destination": str(destination.resolve()),
        "canvas": [CANVAS_SIZE, CANVAS_SIZE],
        "visibleBounds": list(final_bounds),
        "visibleSize": [final_width, final_height],
        "visibleAspectRatio": round(final_width / final_height, 4),
    }


def main() -> int:
    arguments = build_parser().parse_args()
    chroma = parse_hex_color(arguments.chroma) if arguments.chroma else None
    result = prepare_catalog_png(
        Path(arguments.source),
        Path(arguments.destination),
        chroma=chroma,
        tolerance=max(0, arguments.tolerance),
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
