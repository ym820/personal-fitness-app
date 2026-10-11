#!/bin/bash
# 云端会话启动时安装 Swift 工具链，用来跑 Packages/FitnessCore 的单元测试。
# swift.org 下载被云端网络策略拦了，所以从 Docker Hub 官方 swift 镜像里取工具链那一层。
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

SWIFT_TAG="6.1-noble"
SWIFT_HOME="$HOME/swift"

if [ ! -x "$SWIFT_HOME/usr/bin/swift" ]; then
  echo "安装 Swift ($SWIFT_TAG)…" >&2

  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    binutils libc6-dev libcurl4-openssl-dev libedit2 libgcc-13-dev libpython3-dev \
    libsqlite3-0 libstdc++-13-dev libxml2-dev libncurses-dev libz3-dev pkg-config \
    tzdata zlib1g-dev >/dev/null 2>&1 \
    || { apt-get update -qq >/dev/null 2>&1 && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      binutils libc6-dev libcurl4-openssl-dev libedit2 libgcc-13-dev libpython3-dev \
      libsqlite3-0 libstdc++-13-dev libxml2-dev libncurses-dev libz3-dev pkg-config \
      tzdata zlib1g-dev >/dev/null; }

  registry="https://registry-1.docker.io/v2/library/swift"
  token=$(curl -fsS "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/swift:pull" \
    | python3 -I -c 'import sys, json; print(json.load(sys.stdin)["token"])')
  auth="Authorization: Bearer $token"

  # 多架构索引 → linux/amd64 的镜像 → 最大的一层就是工具链
  manifest=$(curl -fsS -H "$auth" \
    -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json' \
    "$registry/manifests/$SWIFT_TAG" \
    | python3 -I -c 'import sys, json
for m in json.load(sys.stdin)["manifests"]:
    p = m.get("platform", {})
    if p.get("os") == "linux" and p.get("architecture") == "amd64":
        print(m["digest"]); break')
  layer=$(curl -fsS -H "$auth" -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
    "$registry/manifests/$manifest" \
    | python3 -I -c 'import sys, json; print(max(json.load(sys.stdin)["layers"], key=lambda l: l["size"])["digest"])')

  tmp="$(mktemp -d)"
  curl -fsSL -H "$auth" -o "$tmp/layer.tgz" "$registry/blobs/$layer"
  mkdir -p "$SWIFT_HOME.partial"
  tar xzf "$tmp/layer.tgz" -C "$SWIFT_HOME.partial"
  rm -rf "$tmp" "$SWIFT_HOME"
  mv "$SWIFT_HOME.partial" "$SWIFT_HOME"
fi

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$SWIFT_HOME/usr/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# 预先拉取依赖并编译一次，后面 swift test 更快
cd "$CLAUDE_PROJECT_DIR/Packages/FitnessCore"
"$SWIFT_HOME/usr/bin/swift" build --build-tests >/dev/null
"$SWIFT_HOME/usr/bin/swift" --version >&2
