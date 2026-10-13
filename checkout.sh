#!/usr/bin/env bash
# Usage:
#   ./checkout.sh           interactive: choose a tag for each repo
#   ./checkout.sh --auto    check out the newest stable tag everywhere
#   ./checkout.sh libx11 xserver    only those repos (interactive)

cd "$(dirname "$0")" || exit 1

# repo dir | tag regex (anchored, so rc/alpha/CVS-era tags are excluded)
REPOS=(
  "macros|^util-macros-[0-9]+\.[0-9]+(\.[0-9]+)?$"
  "xorgproto|^xorgproto-[0-9]+\.[0-9]+(\.[0-9]+)?$"
  "libxtrans|^xtrans-[0-9]+\.[0-9]+\.[0-9]+$"
  "libxau|^libXau-[0-9]+\.[0-9]+\.[0-9]+$"
  "libxdmcp|^libXdmcp-[0-9]+\.[0-9]+\.[0-9]+$"
  "xcbproto|^xcb-proto-[0-9]+\.[0-9]+(\.[0-9]+)?$"
  "libxcb|^libxcb-[0-9]+\.[0-9]+(\.[0-9]+)?$"
  "libx11|^libX11-[0-9]+\.[0-9]+(\.[0-9]+)?$"
  "pixman|^pixman-[0-9]+\.[0-9]+\.[0-9]+$"
  "libxkbfile|^libxkbfile-[0-9]+\.[0-9]+\.[0-9]+$"
  "xkbcomp|^xkbcomp-[0-9]+\.[0-9]+\.[0-9]+$"
  "xkeyboard-config|^xkeyboard-config-[0-9]+\.[0-9]+(\.[0-9]+)?$"
  "libfontenc|^libfontenc-[0-9]+\.[0-9]+\.[0-9]+$"
  "libxfont|^libXfont2-[0-9]+\.[0-9]+\.[0-9]+$"
  "libxcvt|^libxcvt-[0-9]+\.[0-9]+\.[0-9]+$"
  "xserver|^xorg-server-21\.1\.[0-9]+$"
)

AUTO=0
[ "$1" = "--auto" ] && { AUTO=1; shift; }
ONLY=("$@")

want() {
  [ ${#ONLY[@]} -eq 0 ] && return 0
  for o in "${ONLY[@]}"; do [ "$o" = "$1" ] && return 0; done
  return 1
}

for entry in "${REPOS[@]}"; do
  dir="${entry%%|*}"
  re="${entry#*|}"

  want "$dir" || continue
  if [ ! -d "$dir/.git" ]; then
    echo "!! $dir not found, skipping"
    continue
  fi

  echo
  echo "=== $dir ==="
  cd "$dir" || continue

  mapfile -t TAGS < <(git tag | grep -E "$re" | sort -V | tail -8)

  if [ ${#TAGS[@]} -eq 0 ]; then
    echo "No tags matched the filter. Last 15 tags in this repo:"
    git tag | sort -V | tail -15
    if [ $AUTO -eq 1 ]; then cd ..; continue; fi
    read -rp "Type a tag/branch to checkout (Enter to skip): " pick
    [ -n "$pick" ] && git checkout "$pick"
    cd ..
    continue
  fi

  newest="${TAGS[-1]}"

  if [ $AUTO -eq 1 ]; then
    git checkout -q "$newest" && echo "-> $newest"
    cd ..
    continue
  fi

  i=1
  for t in "${TAGS[@]}"; do
    mark=""; [ "$t" = "$newest" ] && mark="  (newest)"
    echo "  [$i] $t$mark"
    i=$((i+1))
  done
  echo "  [s] skip    [m] type manually"
  read -rp "Choice [Enter = newest]: " c

  case "$c" in
    "")  git checkout -q "$newest" && echo "-> $newest" ;;
    s|S) echo "skipped" ;;
    m|M) read -rp "Tag/branch: " t; git checkout "$t" ;;
    *)
      if [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -le ${#TAGS[@]} ]; then
        git checkout -q "${TAGS[$((c-1))]}" && echo "-> ${TAGS[$((c-1))]}"
      else
        echo "invalid choice, skipped"
      fi
      ;;
  esac
  cd ..
done

echo
echo "=== Summary ==="
for entry in "${REPOS[@]}"; do
  dir="${entry%%|*}"
  [ -d "$dir/.git" ] && printf "%-18s %s\n" "$dir" "$(git -C "$dir" describe --tags --always 2>/dev/null)"
done
