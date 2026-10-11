#!/usr/bin/env python3
"""从 Workout Guide 下载动作示范图（SVG 线条画），放进 iPhone app 的 asset catalog。

图片来源：https://github.com/bryllim/workout-guide （CC BY-SA 4.0，Bryl Lim，基于 Everkinetic）
每个动作用哪两帧记在 scripts/workout_guide_frames.json 里。
图片存成「模板图」，在 app 里按当前文字颜色染色，深色模式自动变白。
原图画布四周空白很多，这里把同一个动作的几帧按它们的共同边界裁掉空白（只改 SVG 的 viewBox，
线条本身不动），两帧的比例保持一致。需要 Pillow 来算边界。

用法：python3 scripts/fetch_images.py
会先清空旧图再重新下载，同时更新 exercises.json 里的 images 字段。
"""
import io
import json
import pathlib
import re
import shutil
import urllib.request

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
EXERCISES = ROOT / "Packages/FitnessCore/Sources/FitnessCore/Resources/exercises.json"
FRAMES = ROOT / "scripts/workout_guide_frames.json"
ASSETS = ROOT / "FitnessApp/Assets.xcassets"
IMAGES = ASSETS / "ExerciseImages"
BASE_URL = "https://raw.githubusercontent.com/bryllim/workout-guide/main/packages/workout-guide/assets"
INFO = {"author": "xcode", "version": 1}
CANVAS = 512
MARGIN = 8


def download(url):
    print(f"下载 {url}")
    with urllib.request.urlopen(url) as response:
        return response.read()


def content_box(png_bytes):
    """PNG 里不透明部分的边界 (left, top, right, bottom)"""
    return Image.open(io.BytesIO(png_bytes)).convert("RGBA").getchannel("A").getbbox()


def crop_svg(svg, box):
    left, top, right, bottom = box
    left, top = max(0, left - MARGIN), max(0, top - MARGIN)
    right, bottom = min(CANVAS, right + MARGIN), min(CANVAS, bottom + MARGIN)
    width, height = right - left, bottom - top
    svg = svg.decode()
    svg = re.sub(r'width="\d+"', f'width="{width}"', svg, count=1)
    svg = re.sub(r'height="\d+"', f'height="{height}"', svg, count=1)
    svg = re.sub(r'viewBox="[^"]*"', f'viewBox="{left} {top} {width} {height}"', svg, count=1)
    return svg.encode()


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def main():
    frames = {k: v for k, v in json.loads(FRAMES.read_text()).items() if not k.startswith("_")}
    exercises = json.loads(EXERCISES.read_text())

    if IMAGES.exists():
        shutil.rmtree(IMAGES)
    IMAGES.mkdir(parents=True)
    write_json(IMAGES / "Contents.json", {"info": INFO})

    for exercise in exercises:
        source = frames[exercise["id"]]
        base = f"{BASE_URL}/{source['slug']}"
        svgs = [download(f"{base}/frame-{frame}.svg") for frame in source["frames"]]
        boxes = [content_box(download(f"{base}/frame-{frame}.png")) for frame in source["frames"]]
        union = (min(b[0] for b in boxes), min(b[1] for b in boxes),
                 max(b[2] for b in boxes), max(b[3] for b in boxes))

        names = []
        for index, svg in enumerate(svgs):
            name = f"{exercise['id']}_{index}"
            imageset = IMAGES / f"{name}.imageset"
            imageset.mkdir()
            (imageset / f"{name}.svg").write_bytes(crop_svg(svg, union))
            write_json(imageset / "Contents.json", {
                "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
                "info": INFO,
                "properties": {
                    "preserves-vector-representation": True,
                    "template-rendering-intent": "template",
                },
            })
            names.append(name)
        exercise["images"] = names

    write_json(EXERCISES, exercises)


if __name__ == "__main__":
    main()
