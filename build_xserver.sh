source env.sh
cd xserver
meson setup _b --cross-file ../android-x86_64.ini --native-file ../native.ini \
  --prefix=$PREFIX --libdir=lib \
  -Dxorg=false -Dxvfb=true -Dxnest=false -Dxephyr=false -Dxwin=false \
  -Dglamor=false -Dglx=false -Ddri3=false \
  -Dudev=false -Dudev_kms=false -Dhal=false -Dsystemd_logind=false \
  -Dxdmcp=false -Dmitshm=false -Dpciaccess=false -Dint10=false \
  -Dxkb_dir=$DEVPREFIX/share/X11/xkb \
  -Dxkb_bin_dir=$DEVPREFIX/bin \
  -Dxkb_output_dir=/data/local/tmp \
  -Dlog_dir=/data/local/tmp \
  -Ddefault_font_path=$DEVPREFIX/share/fonts
