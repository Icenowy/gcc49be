export PATH=/opt/gcc49be:$PATH
mkdir -p buildenv-$BEARCH && cd buildenv-$BEARCH
BUVER=2.25
GCCVER=4.9.2
GLCVER=2.21
! [ "$GNUMIRROR" ] && GNUMIRROR="http://ftp.gnu.org/gnu"
if [ ! -e sources ]; then
axel $GNUMIRROR/binutils/binutils-$BUVER.tar.bz2
axel $GNUMIRROR/gcc/gcc-$GCCVER/gcc-$GCCVER.tar.bz2
axel $GNUMIRROR//gmp/gmp-6.0.0a.tar.xz
axel http://www.mpfr.org/mpfr-3.1.2/mpfr-3.1.2.tar.xz
axel http://www.multiprecision.org/mpc/download/mpc-1.0.2.tar.gz
wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.19.tar.xz # axel may fail
axel $GNUMIRROR/glibc/glibc-$GLCVER.tar.xz
touch sources
fi
tar xvf binutils-$BUVER.tar.bz2
[ "$BUCLEAN" = "1" ] && rm -rf binutils-build-pass1
mkdir -p binutils-build-pass1
cd binutils-build-pass1
CC=$BECC CXX=$BECXX ../binutils-$BUVER/configure --prefix=/opt/gcc49be --with-lib-path=/opt/gcc49be/lib --disable-nls --disable-werror && make $ABMK && make install
cd ..
tar xvf gcc-$GCCVER.tar.bz2
cd gcc-$GCCVER
tar -xf ../mpfr-3.1.2.tar.xz
mv -v mpfr-3.1.2 mpfr
tar -xf ../gmp-6.0.0a.tar.xz
mv -v gmp-6.0.0 gmp
tar -xf ../mpc-1.0.2.tar.gz
mv -v mpc-1.0.2 mpc
for file in \
 $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h)
do
  cp -uv $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/opt/gcc49be&@g' \
      -e 's@/usr@/opt/gcc49be@g' $file.orig > $file
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/opt/gcc49be/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done
cd ..
cp -r gcc-$GCCVER gcc-$GCCVER-1
cd gcc-$GCCVER-1
sed -i '/k prot/agcc_cv_libc_provides_ssp=yes' gcc/configure
mkdir -pv ../gcc-build-pass1
cd ../gcc-build-pass1
CC=$BECC CXX=$BECXX ../gcc-$GCCVER/configure --prefix=/opt/gcc49be --with-newlib  \
    --without-headers                                \
    --with-local-prefix=/opt/gcc49be \
    --with-native-system-header-dir=/opt/gcc49be/include \
    --disable-nls                                    \
    --disable-shared                                 \
    --disable-multilib                               \
    --disable-decimal-float                          \
    --disable-threads                                \
    --disable-libatomic                              \
    --disable-libgomp                                \
    --disable-libitm                                 \
    --disable-libquadmath                            \
    --disable-libsanitizer                           \
    --disable-libssp                                 \
    --disable-libvtv                                 \
    --disable-libcilkrts                             \
    --disable-libstdc++-v3                           \
    --enable-languages=c,c++ && make $ABMK && make install
cd ..
tar vxf linux-3.19.tar.xz
cd linux-3.19
make mrproper
make INSTALL_HDR_PATH=dest headers_install
mkdir -p /opt/gcc49be/include
cp -rv dest/include/* /opt/gcc49be/include
cd ..
tar xvf glibc-$GLCVER.tar.xz
cd glibc-$GLCVER
sed -e '/ia32/s/^/1:/' \
    -e '/SSE2/s/^1://' \
    -i  sysdeps/i386/i686/multiarch/mempcpy_chk.S
mkdir -v ../glibc-build
cd ../glibc-build
../glibc-$GLCVER/configure                             \
      $([ "$BEARCH" = "x86" ] && echo "--host=i686-pc-linux-gnu") \
      --prefix=/opt/gcc49be \
      --disable-profile                             \
      --enable-kernel=2.6.32                        \
      --with-headers=/opt/gcc49be/include                 \
      libc_cv_forced_unwind=yes                     \
      libc_cv_ctors_header=yes                      \
      libc_cv_c_cleanup=yes && make $ABMK && make install
echo 'main(){}' > dummy.c
gcc dummy.c
(readelf -l a.out | grep ': /tools') || exit 1
cd ..
mkdir -p libstdcxx-build
cd libstdcxx-build
../gcc-$GCCVER/libstdc++-v3/configure --prefix=/opt/gcc49be \
    --disable-multilib              \
    --disable-shared                \
    --disable-nls                   \
    --disable-libstdcxx-threads     \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/opt/gcc49be/include/c++/$GCCVER &&make $ABMK && make install
cd ..
mkdir -p binutils-build
cd binutils-build
../binutils-$BUVER/configure --prefix=/opt/gcc49be \
    --disable-werror           \
    --with-lib-path==/opt/gcc49be/lib \
    --with-sysroot && make && make install
cd ../gcc-$GCCVER
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $(gcc -print-libgcc-file-name)`/include-fixed/limits.h
mkdir -v ../gcc-build
cd ../gcc-build
../gcc-$GCCVER/configure                               \
    --prefix=/opt/gcc49be \
    --with-local-prefix=/opt/gcc49be                       \
    --with-native-system-header-dir=/opt/gcc49be/include  \
    --enable-languages=c,c++                         \
    --disable-libstdcxx-pch                          \
    --disable-multilib                               \
    --disable-bootstrap && make && make install
echo 'main(){}' > dummy.c
gcc dummy.c
(readelf -l a.out | grep ': /tools') || exit 1


