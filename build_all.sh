#!/usr/bin/env bash
# Usage:
#   ./build_all.sh              build everything
#   ./build_all.sh from x11     resume from a step
#   ./build_all.sh only xserver run a single step
set -eo pipefail
cd "$(dirname "$0")"
ROOT=$PWD
source "$ROOT/env.sh"
CROSS=$ROOT/android-x86_64.ini
NATIVE=$ROOT/native.ini
J=$(nproc)

STEPS=(macros xorgproto xtrans xau xdmcp xcbproto xcb x11 pixman xkbfile
       xkbcomp xkbconfig fontenc freetype xfont xcvt sha1 xserver)
rm -rf freetype/
# ---------- argument parsing ----------
MODE=all; TARGET=""
case "${1:-}" in
  from|only) MODE=$1; TARGET=${2:?"give a step name"} ;;
  "") ;;
  *) echo "usage: $0 [from|only STEP]"; exit 1 ;;
esac
if [ -n "$TARGET" ] && ! printf '%s\n' "${STEPS[@]}" | grep -qx "$TARGET"; then
  echo "Unknown step '$TARGET'. Steps: ${STEPS[*]}"; exit 1
fi
go=0; [ "$MODE" = all ] && go=1

# ---------- find a Python >= 3.11 (needed by xkeyboard-config) ----------
PY=""
for p in /usr/bin/python3 /usr/bin/python3.13 /usr/bin/python3.12 /usr/bin/python3.11; do
  if [ -x "$p" ] && "$p" -c 'import sys; sys.exit(sys.version_info < (3,11))'; then
    PY=$p; break
  fi
done
echo "Python >= 3.11: ${PY:-NOT FOUND}"

cat > "$NATIVE" <<EOF
[binaries]
python3 = '${PY:-/usr/bin/python3}'
python = '${PY:-/usr/bin/python3}'
EOF

if [ ! -f "$CROSS" ]; then
cat > "$CROSS" <<EOF
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$AR'
strip = '$STRIP'
pkg-config = 'pkg-config'

[built-in options]
c_args = ['-I$PREFIX/include']
c_link_args = ['-L$PREFIX/lib']

[properties]
needs_exe_wrapper = true
pkg_config_libdir = ['$PREFIX/lib/pkgconfig', '$PREFIX/share/pkgconfig']

[host_machine]
system = 'android'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF
fi

# ---------- helpers ----------
fix_pc() {   # Bionic has no libpthread
  sed -i 's/-lpthread//g' "$PREFIX"/lib/pkgconfig/*.pc 2>/dev/null || true
}

# autotools: at <dir> [configure args...]
at() {
  local d=$1; shift
  echo "##### autotools: $d"
  pushd "$ROOT/$d" >/dev/null
  [ -f configure ] || autoreconf -fi
  rm -rf _b
  mkdir _b
  cd _b
  ../configure --host=$TRIPLE --prefix=$PREFIX --disable-static \
      --disable-docs --disable-specs --without-xmlto --without-fop "$@"
  find . -name Makefile -exec sed -i 's/-lpthread//g' {} +
  make -j$J
  make install
  popd >/dev/null
}

# meson: ms <dir> [meson args...]
ms() {
  local d=$1; shift
  echo "##### meson: $d"
  pushd "$ROOT/$d" >/dev/null
  rm -rf _b
  meson setup _b --cross-file "$CROSS" --native-file "$NATIVE" \
      --prefix=$PREFIX --libdir=lib "$@"
  ninja -C _b
  ninja -C _b install
  popd >/dev/null
}

# step <name> <command...>
step() {
  local name=$1; shift
  if [ "$MODE" = from ] && [ "$name" = "$TARGET" ]; then go=1; fi
  if [ "$MODE" = only ]; then
    if [ "$name" = "$TARGET" ]; then go=1; else go=0; fi
  fi
  if [ $go -ne 1 ]; then return 0; fi
  "$@"
  fix_pc
  echo "##### OK: $name"
}

# ---------- special steps ----------
xkbconfig() {
  if [ -n "$PY" ]; then
    ms xkeyboard-config -Dnls=false
  else
    echo "No Python >= 3.11, copying host xkb data instead"
    mkdir -p "$PREFIX/share/X11"
    cp -r /usr/share/X11/xkb "$PREFIX/share/X11/"
  fi
}

freetype() {
  if [ ! -d "$ROOT/freetype/.git" ]; then
    git clone https://gitlab.freedesktop.org/freetype/freetype.git "$ROOT/freetype"
    local tag
    tag=$(git -C "$ROOT/freetype" tag | grep -E '^VER-2-[0-9]+-[0-9]+$' | sort -V | tail -1)
    git -C "$ROOT/freetype" checkout "$tag"
  fi
  ms freetype -Dharfbuzz=disabled -Dbzip2=disabled -Dpng=disabled -Dbrotli=disabled
}

# libsha1: its test.c uses old C and fails, so build the library only
sha1() {
  if [ ! -d "$ROOT/libsha1" ]; then
    git clone https://github.com/dottedmag/libsha1.git "$ROOT/libsha1"
  fi
  pushd "$ROOT/libsha1" >/dev/null
  [ -f configure ] || autoreconf -fi
  rm -rf _b; mkdir _b; cd _b
  CFLAGS="-O2 -std=gnu89 -Wno-implicit-int" \
    ../configure --host=$TRIPLE --prefix=$PREFIX --disable-static
  make -j$J -k || true                      # test.c may still fail; ignore
  [ -f .libs/libsha1.so ] || { echo "libsha1.so was not built"; exit 1; }
  mkdir -p "$PREFIX/include" "$PREFIX/lib/pkgconfig"
  cp ../libsha1.h "$PREFIX/include/"
  cp -a .libs/libsha1.so* "$PREFIX/lib/"
  cat > "$PREFIX/lib/pkgconfig/libsha1.pc" <<EOF
prefix=$PREFIX
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: libsha1
Description: SHA1 implementation
Version: 0.3.99
Libs: -L\${libdir} -lsha1
Cflags: -I\${includedir}
EOF
  popd >/dev/null
  pkg-config --exists libsha1
}

xserver() {
  # Bionic has no libpthread: replace the lookup (idempotent)
  if grep -q "find_library('pthread'" "$ROOT/xserver/os/meson.build"; then
    cp -n "$ROOT/xserver/os/meson.build" "$ROOT/xserver/os/meson.build.orig"
    sed -i "s|cc.find_library('pthread'[^)]*)|dependency('', required: false)|" \
      "$ROOT/xserver/os/meson.build"
  fi
  ms xserver \
    -Dxorg=false -Dxvfb=true -Dxnest=false -Dxephyr=false -Dxwin=false \
    -Dglamor=false -Dglx=false -Ddri3=false \
    -Dudev=false -Dudev_kms=false -Dhal=false -Dsystemd_logind=false \
    -Dxdmcp=false -Dmitshm=false -Dpciaccess=false -Dint10=false \
    -Dsecure-rpc=false -Dsha1=libsha1 \
    -Dxkb_dir=$DEVPREFIX/share/X11/xkb \
    -Dxkb_bin_dir=$DEVPREFIX/bin \
    -Dxkb_output_dir=/data/local/tmp \
    -Dlog_dir=/data/local/tmp \
    -Ddefault_font_path=$DEVPREFIX/share/fonts
}

# ---------- build order ----------
step macros    at macros
step xorgproto ms xorgproto
step xtrans    at libxtrans
step xau       at libxau
step xdmcp     at libxdmcp
step xcbproto  at xcbproto
step xcb       at libxcb
step x11       at libx11 --disable-malloc0returnsnull --disable-xf86bigfont
step pixman    ms pixman -Dtests=disabled -Ddemos=disabled
step xkbfile   ms libxkbfile
step xkbcomp   at xkbcomp
step xkbconfig xkbconfig
step fontenc   at libfontenc
step freetype  freetype
step xfont     at libxfont --with-bzip2=no
step xcvt      ms libxcvt
step sha1      sha1
step xserver   xserver

echo
echo "All done. Xvfb is in $PREFIX/bin"
