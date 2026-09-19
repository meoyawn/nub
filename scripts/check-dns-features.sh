#!/usr/bin/env bash
# Guard the resolved dependency graph, including feature unification from
# auxiliary HTTP clients. No cross-compilation or live VPN is needed.
# @lat: [[design/architecture#Architecture#HTTP DNS resolution]]
set -euo pipefail
cd "$(dirname "$0")/.."

targets=(
  aarch64-apple-darwin
  x86_64-apple-darwin
  x86_64-unknown-linux-gnu
  x86_64-pc-windows-msvc
  aarch64-linux-android
)
# Android still compiles Hickory; the engine's client builders disable it
# at runtime to avoid JNI without a JVM. This guards feature selection only.
for target in "${targets[@]}"; do
  for features in default all; do
    args=(tree --locked -p nub-cli --target "$target"
      --edges normal --prefix none --format '{p} {f}')
    if [[ "$features" == all ]]; then args+=(--all-features); fi
    graph=$(cargo "${args[@]}")
    if ! grep -q '^reqwest ' <<< "$graph"; then
      echo "FAIL: no reqwest clients found for $target ($features)" >&2
      exit 1
    fi
    if grep -q '^hickory-resolver ' <<< "$graph"; then
      hickory=true
    else
      hickory=false
    fi
    expected=true
    if [[ "$target" == *-apple-darwin ]]; then expected=false; fi
    if [[ "$hickory" != "$expected" ]]; then
      echo "FAIL: $target ($features): Hickory=$hickory, expected $expected" >&2
      exit 1
    fi
    echo "PASS: $target ($features): Hickory=$hickory"
  done
done
