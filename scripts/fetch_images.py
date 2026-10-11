#!/usr/bin/env python3
"""从 free-exercise-db 下载 exercises.json 里每个动作的示范图，放进 iPhone app 的 asset catalog。

用法：python3 scripts/fetch_images.py
已经存在的图片会跳过。
"""
import json
import pathlib
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
EXERCISES = ROOT / "Packages/FitnessCore/Sources/FitnessCore/Resources/exercises.json"
ASSETS = ROOT / "FitnessApp/Assets.xcassets"
IMAGES = ASSETS / "ExerciseImages"
BASE_URL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises"
CONTENTS_INFO = {"info": {"author": "xcode", "version": 1}}


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n")


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    write_json(ASSETS / "Contents.json", CONTENTS_INFO)
    IMAGES.mkdir(exist_ok=True)
    write_json(IMAGES / "Contents.json", CONTENTS_INFO)

    for exercise in json.loads(EXERCISES.read_text()):
        for index, name in enumerate(exercise["images"]):
            imageset = IMAGES / f"{name}.imageset"
            imageset.mkdir(exist_ok=True)
            jpg = imageset / f"{name}.jpg"
            if not jpg.exists():
                url = f"{BASE_URL}/{exercise['id']}/{index}.jpg"
                print(f"下载 {url}")
                with urllib.request.urlopen(url) as response:
                    jpg.write_bytes(response.read())
            write_json(imageset / "Contents.json", {
                "images": [{"filename": jpg.name, "idiom": "universal"}],
                **CONTENTS_INFO,
            })


if __name__ == "__main__":
    main()
