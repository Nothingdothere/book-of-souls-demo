"""Export a GPU-compressed web build without changing the editor's artwork imports."""

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import struct
from pathlib import Path

from compact_web_pack import compact


ROOT = Path(__file__).resolve().parents[1]
STAGING = ROOT / ".godot" / "web_project"


def prepare():
    STAGING.mkdir(parents=True, exist_ok=True)
    sources = []
    for directory in ("assets", "dialogue", "scenes", "scripts", "shaders"):
        sources.extend(path for path in (ROOT / directory).rglob("*") if path.is_file())
    sources.extend(ROOT / name for name in ("project.godot", "export_presets.cfg"))
    copied = set()
    for source in sources:
        relative = source.relative_to(ROOT)
        target = STAGING / relative
        copied.add(relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.name.endswith(".png.import"):
            # Basis/UASTC transcodes to the GPU format supported by the browser.
            # Keep dimensions/pivots and alpha; don't resize the artist's sources.
            content = source.read_text(encoding="utf-8")
            width, height = struct.unpack(">II", source.with_suffix("").read_bytes()[16:24])
            # WebGL's block-compressed base levels need block-aligned dimensions.
            # Preserve irregular canvases losslessly rather than changing layouts.
            mode = 4 if width % 4 == 0 and height % 4 == 0 else 0
            content = re.sub(r"(?m)^compress/mode=\d+$", f"compress/mode={mode}", content)
            content = re.sub(r"(?m)^compress/uastc_level=\d+$", "compress/uastc_level=2", content)
            content = re.sub(r"(?m)^compress/rdo_quality_loss=.+$", "compress/rdo_quality_loss=0.0", content)
            if not target.exists() or target.read_text(encoding="utf-8") != content:
                target.write_text(content, encoding="utf-8")
        elif source.name == "export_presets.cfg":
            content = source.read_text(encoding="utf-8").replace(
                "vram_texture_compression/for_mobile=false", "vram_texture_compression/for_mobile=true"
            )
            target.write_text(content, encoding="utf-8")
        elif source.name == "project.godot":
            content = source.read_text(encoding="utf-8")
            # The exporter validates mobile GPU support even with Basis textures.
            key = "textures/vram_compression/import_etc2_astc"
            if re.search(rf"(?m)^{re.escape(key)}=", content):
                content = re.sub(rf"(?m)^{re.escape(key)}=.+$", f"{key}=true", content)
            else:
                content = content.replace("[rendering]", f"[rendering]\n\n{key}=true")
            target.write_text(content, encoding="utf-8")
        elif not target.exists() or target.read_bytes() != source.read_bytes():
            shutil.copy2(source, target)
    # Remove only stale input files in our own staging tree, never its import cache.
    for directory in ("assets", "dialogue", "scenes", "scripts", "shaders"):
        for target in (STAGING / directory).rglob("*"):
            if target.is_file() and target.relative_to(STAGING) not in copied:
                target.unlink()
    print(f"Prepared {len(copied)} inputs in {STAGING}", flush=True)


def run(godot, *arguments):
    process = subprocess.Popen(
        [str(godot), "--headless", "--path", str(STAGING), *arguments],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        encoding="utf-8", errors="replace",
    )
    for line in process.stdout:
        print(line, end="", flush=True)
    if process.wait():
        raise SystemExit(f"Godot failed ({process.returncode}): {' '.join(arguments)}")


def version_loader(pack):
    # A fresh HTML page must not launch the previous, memory-heavy cached pack.
    html_path = pack.with_suffix(".html")
    html = html_path.read_text(encoding="utf-8")
    match = re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", html)
    if not match:
        raise ValueError("Godot HTML loader configuration not found")
    config = json.loads(match[1])
    version = hashlib.sha256(pack.read_bytes()).hexdigest()[:12]
    config["mainPack"] = f"{pack.name}?build={version}"
    config["fileSizes"][config["mainPack"]] = pack.stat().st_size
    html = html[:match.start(1)] + json.dumps(config, separators=(",", ":")) + html[match.end(1):]
    html_path.write_text(html, encoding="utf-8")
    print(f"Versioned web pack: {version}", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    prepare()
    if not args.prepare_only:
        if not args.godot or not args.godot.is_file():
            parser.error("--godot must point to the Godot executable")
        run(args.godot, "--editor", "--import")
        run(args.godot, "--export-release", "Web", str(ROOT / "docs" / "index.html"))
        pack = ROOT / "docs" / "index.pck"
        compact(pack)
        if pack.stat().st_size >= 100 * 1024 * 1024:
            raise SystemExit("Web pack exceeds GitHub's 100 MiB file limit")
        version_loader(pack)
