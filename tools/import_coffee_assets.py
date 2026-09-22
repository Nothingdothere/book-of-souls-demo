"""Import artist archives into stable, game-sized PNG assets.

Run from the project root with paths to the no-cat, coffee, and cat ZIP files.
"""

from pathlib import Path
from sys import argv
from zipfile import ZipFile

from PIL import Image
from io import BytesIO


ROOT = Path(__file__).resolve().parents[1]
COFFEE_NAMES = [
    "street_parallax", "cafe_back", "street_more_buildings", "street_back",
    "street_ground", "cafe_exterior", "street_far_buildings",
    "cafe_foreground", "street_foreground", "cafe_floor", "cafe_midground",
]
CAT_GROUPS = {"поднимает лапу": "paw", "моргает": "blink", "умывается": "wash"}


def png_entries(archive):
    return [name for name in archive.namelist() if name.lower().endswith(".png")]


def write_image(raw, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    image = Image.open(BytesIO(raw)).convert("RGBA")
    if destination.parent.name == "no_cat" and "idle" in destination.name:
        # The figure lives near the centre of a 3144x4308 transparent canvas.
        # This fixed crop keeps every idle frame registered to the same pivot.
        image = image.crop((1050, 1360, 2074, 2896))
    if "cat" in destination.parts and destination.parent.name in CAT_GROUPS.values():
        image = image.resize((512, 512), Image.Resampling.LANCZOS)
    image.save(destination, optimize=True)
    print(destination.relative_to(ROOT), image.size, image.getchannel("A").getbbox())
    return image


def main():
    no_cat_zip, coffee_zip, cat_zip = map(Path, argv[1:4])
    with ZipFile(no_cat_zip) as archive:
        for name in png_entries(archive):
            write_image(archive.read(name), ROOT / "assets/character/no_cat" / Path(name).name)
    with ZipFile(coffee_zip) as archive:
        entries = png_entries(archive)
        assert len(entries) == len(COFFEE_NAMES)
        for name, stem in zip(entries, COFFEE_NAMES):
            write_image(archive.read(name), ROOT / "assets/coffee" / (stem + ".png"))
    with ZipFile(cat_zip) as archive:
        counts = {value: 0 for value in CAT_GROUPS.values()}
        for name in png_entries(archive):
            group = CAT_GROUPS[name.split("/")[0]]
            counts[group] += 1
            target = ROOT / "assets/cat" / group / f"{counts[group]:02d}.png"
            write_image(archive.read(name), target)


if __name__ == "__main__":
    main()
