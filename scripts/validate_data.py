#!/usr/bin/env python3
"""检查 exercises.json、plan.json 和示范图是否一致。

用法：python3 scripts/validate_data.py
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "Packages/FitnessCore/Sources/FitnessCore/Resources"
IMAGES = ROOT / "FitnessApp/Assets.xcassets/ExerciseImages"
BODY_PARTS = {"legs", "chest", "back", "shoulders", "arms", "core"}
UNITS = {"reps", "seconds"}
REQUIRED = ["id", "nameZh", "nameEn", "equipmentZh", "equipmentEn", "bodyPart",
            "primaryMuscles", "images", "tipsZh", "unit", "increment"]


def main():
    errors = []
    exercises = json.loads((RESOURCES / "exercises.json").read_text())
    plan = json.loads((RESOURCES / "plan.json").read_text())

    ids = [e.get("id") for e in exercises]
    if len(ids) != len(set(ids)):
        errors.append("动作 id 有重复")

    for e in exercises:
        name = e.get("id", "?")
        missing = [key for key in REQUIRED if key not in e]
        if missing:
            errors.append(f"{name}: 缺少字段 {missing}")
            continue
        if e["bodyPart"] not in BODY_PARTS:
            errors.append(f"{name}: bodyPart 不合法 {e['bodyPart']}")
        if e["unit"] not in UNITS:
            errors.append(f"{name}: unit 不合法 {e['unit']}")
        if not isinstance(e["increment"], (int, float)) or e["increment"] < 0:
            errors.append(f"{name}: increment 不合法 {e['increment']}")
        if not 3 <= len(e["tipsZh"]) <= 5:
            errors.append(f"{name}: tipsZh 应该有 3 到 5 条，现在 {len(e['tipsZh'])} 条")
        if len(e["images"]) != 2:
            errors.append(f"{name}: 应该有 2 张图")
        for image in e["images"]:
            if not (IMAGES / f"{image}.imageset" / f"{image}.jpg").exists():
                errors.append(f"{name}: 缺少图片 {image}.jpg")

    known = set(ids)
    for template in plan["templates"]:
        for item in template["exercises"]:
            if item["exerciseId"] not in known:
                errors.append(f"训练 {template['id']}: 动作 {item['exerciseId']} 不在 exercises.json 里")
            if not 0 < item["targetMin"] <= item["targetMax"]:
                errors.append(f"训练 {template['id']}: {item['exerciseId']} 目标范围不合法")

    if errors:
        print("\n".join(errors))
        sys.exit(1)
    print(f"OK：{len(exercises)} 个动作，{len(plan['templates'])} 套训练")


if __name__ == "__main__":
    main()
