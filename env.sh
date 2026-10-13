export NDK=/home/hilman/Android/Sdk/ndk/26.1.10909125/        # adjust to your NDK path
export API=31
export TRIPLE=x86_64-linux-android
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64
export PREFIX=$HOME/android-sysroot-x86_64   # build-time install dir (on your PC)
export DEVPREFIX=/data/local/x11             # where files will live on the device

export ac_cv_search_pthread_create="none required"
export ac_cv_lib_pthread_pthread_create=no
export ac_cv_func_pthread_create=yes

export CC=$TOOLCHAIN/bin/${TRIPLE}${API}-clang
export CXX=$TOOLCHAIN/bin/${TRIPLE}${API}-clang++
export AR=$TOOLCHAIN/bin/llvm-ar
export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
export STRIP=$TOOLCHAIN/bin/llvm-strip
export NM=$TOOLCHAIN/bin/llvm-nm
export CC_FOR_BUILD=gcc                      # for tools that run on your PC (libX11 makekeys)

export CPPFLAGS="-I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib"
export PKG_CONFIG_LIBDIR=$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig
unset PKG_CONFIG_PATH
export ACLOCAL_PATH=$PREFIX/share/aclocal
export PATH=$PREFIX/bin:$PATH
mkdir -p $PREFIX
