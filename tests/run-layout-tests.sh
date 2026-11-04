#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
clang $(gnustep-config --objc-flags) -std=gnu99 -Isrc \
    tests/DocumentLayout.m src/StepDownDocument.m src/MarkdownRenderer.m \
    -o "$test_dir/DocumentLayout" $(gnustep-config --gui-libs)
xvfb-run -a "$test_dir/DocumentLayout"
