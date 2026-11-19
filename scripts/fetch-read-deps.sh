#!/bin/sh
# scripts/fetch-read-deps.sh DIR
#
# Fetches the systems listed in scripts/read-deps.txt into DIR, one directory per
# system, each checked against its pin (git: the commit; tgz: the archive md5).
# Stops on the first mismatch. DIR is then what CL_SOURCE_REGISTRY names with a
# trailing //:
#
#   scripts/fetch-read-deps.sh "$RUNNER_TEMP/read-deps"
#   CL_SOURCE_REGISTRY="$RUNNER_TEMP/read-deps//" dotcl scripts/gen-dist.lisp
set -eu
dir=${1:?usage: fetch-read-deps.sh DIR}
list=$(dirname "$0")/read-deps.txt
mkdir -p "$dir"
md5_of() { if command -v md5sum >/dev/null 2>&1; then md5sum "$1" | cut -d' ' -f1; else md5 -q "$1"; fi; }
grep -v '^[[:space:]]*\(#\|$\)' "$list" | while read -r kind name url pin; do
  case "$kind" in
    git)
      git clone -q "$url" "$dir/$name"
      git -C "$dir/$name" checkout -q "$pin"
      test "$(git -C "$dir/$name" rev-parse HEAD)" = "$pin" || { echo "$name: not at $pin" >&2; exit 1; }
      ;;
    tgz)
      f=$(mktemp)
      curl -fsSL -o "$f" "$url"
      test "$(md5_of "$f")" = "$pin" || { echo "$name: md5 of $url is not $pin" >&2; rm -f "$f"; exit 1; }
      mkdir -p "$dir/$name"
      tar xzf "$f" -C "$dir/$name" --strip-components=1
      rm -f "$f"
      ;;
    *) echo "read-deps.txt: unknown kind $kind" >&2; exit 1 ;;
  esac
  echo "read-deps: $name"
done
