#!/bin/bash
# Mac 上で実行: Web 資産をコピーして Xcode プロジェクトを生成し、開く
set -e
cd "$(dirname "$0")"
rm -rf Web && mkdir Web
cp ../index.html ../manifest.webmanifest ../icon-*.png Web/
if ! command -v xcodegen >/dev/null; then brew install xcodegen; fi
xcodegen generate
open VanillaAcid.xcodeproj
