#!/bin/bash
# 把网页代码、动作数据、示范图和图标组装到 _site/，本地预览和 GitHub Pages 都用它。
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf _site
mkdir -p _site/data _site/img
cp -R web/. _site/
rm -rf _site/test _site/package.json
cp Packages/FitnessCore/Sources/FitnessCore/Resources/{exercises,plan,videos}.json _site/data/
cp FitnessApp/Assets.xcassets/ExerciseImages/*.imageset/*.svg _site/img/
cp FitnessApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png _site/icon.png

# Service Worker 安装时预先缓存的文件列表
(cd _site && find . -type f ! -name sw.js ! -name files.json | sed 's|^\./||' | sort \
  | sed 's/.*/"&"/' | paste -sd, - | sed 's/.*/[&]/') > _site/files.json
