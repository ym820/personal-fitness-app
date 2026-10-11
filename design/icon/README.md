# App 图标源文件

- `light.svg`：默认图标（iPhone 和手表）
- `dark.svg`：iPhone 深色模式图标
- `tinted.svg`：iPhone 着色模式图标（导出时转成灰度）

改完 SVG 后重新导出（需要 Chromium 和 ImageMagick，云端环境自带）：

```sh
cd design/icon
./render.sh light.svg light.png && ./render.sh dark.svg dark.png && ./render.sh tinted.svg tinted.png
convert light.png -alpha off ../../FitnessApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png
convert dark.png -alpha off ../../FitnessApp/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png
convert tinted.png -alpha off -colorspace Gray ../../FitnessApp/Assets.xcassets/AppIcon.appiconset/AppIcon-Tinted.png
convert light.png -alpha off ../../FitnessWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png
rm -f *.png
```
