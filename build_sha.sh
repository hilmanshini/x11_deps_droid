source /work/x11/env.sh
cd /work/x11/libsha1
autoreconf -fi
mkdir -p _b && cd _b
../configure --host=$TRIPLE --prefix=$PREFIX --disable-static
make -j$(nproc) && make install
pkg-config --modversion libsha1     # must print a version
