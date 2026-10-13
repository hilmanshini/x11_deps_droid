source env.sh
cat > /work/x11/android-x86_64.ini <<EOF
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


cat > /work/x11/native.ini <<'EOF'
[binaries]
python3 = '/usr/bin/python3'
python = '/usr/bin/python3'
EOF

/usr/bin/python3 --version     # must be 3.11 or newer
