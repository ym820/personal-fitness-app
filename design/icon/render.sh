#!/bin/bash
# render.sh in.svg out.png  （1024x1024）
in=$(realpath "$1"); out=$(realpath -m "$2")
html=$(mktemp --suffix=.html)
printf '<html><body style="margin:0;background:transparent">%s</body></html>' "$(cat "$in")" > "$html"
"$(ls -d /opt/pw-browsers/chromium_headless_shell-*/chrome-linux/headless_shell | head -1)" --no-sandbox --hide-scrollbars \
  --default-background-color=00000000 --window-size=1024,1024 --screenshot="$out" "file://$html" >/dev/null 2>&1
rm -f "$html"
