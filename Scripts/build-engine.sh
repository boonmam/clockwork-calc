#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build/engine"
mkdir -p "$BUILD/sources" "$ROOT/Vendor/Engine"
fetch() {
  local name="$1" url="$2" checksum="$3"
  if [ ! -f "$BUILD/sources/$name" ]; then curl --fail --location --retry 3 "$url" -o "$BUILD/sources/$name"; fi
  echo "$checksum  $BUILD/sources/$name" | shasum -a 256 -c -
}
fetch gmp-6.3.0.tar.xz https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898
fetch mpfr-4.2.2.tar.xz https://www.mpfr.org/mpfr-4.2.2/mpfr-4.2.2.tar.xz b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01
fetch libqalculate-5.13.1.tar.gz https://github.com/Qalculate/libqalculate/releases/download/v5.13.1/libqalculate-5.13.1.tar.gz cf8d3eaf3d85030115701e997b6585e69573e71add88e7758486c5d1b01d3cc3
for archive in "$BUILD"/sources/*.tar.*; do tar -xf "$archive" -C "$BUILD/sources"; done
# The untranslated definition templates are valid English XML.
for source in "$BUILD/sources/libqalculate-5.13.1/data/"*.xml.in; do
  cp "$source" "$ROOT/App/Resources/Definitions/$(basename "${source%.in}")"
done
cp "$BUILD/sources/libqalculate-5.13.1/data/eurofxref-daily.xml" "$ROOT/App/Resources/Definitions/"
cp "$BUILD/sources/libqalculate-5.13.1/data/rates.json" "$ROOT/App/Resources/Definitions/"
for platform in ${PLATFORMS:-iphonesimulator iphoneos}; do
  sdk="$(xcrun --sdk "$platform" --show-sdk-path)"
  target=arm64-apple-ios17.0
  if [ "$platform" = iphonesimulator ]; then target=arm64-apple-ios17.0-simulator; fi
  prefix="$ROOT/Vendor/Engine/$platform"
  mkdir -p "$prefix" "$BUILD/$platform"
  export CC="$(xcrun -f clang) -target $target -isysroot $sdk"
  export CXX="$(xcrun -f clang++) -target $target -isysroot $sdk"
  export CFLAGS="-O2 -fPIC" CXXFLAGS="-O2 -fPIC -std=c++17"
  export CPPFLAGS="-I$prefix/include" LDFLAGS="-L$prefix/lib"
  export PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig"
  export LIBXML_CFLAGS="-I$sdk/usr/include/libxml2" LIBXML_LIBS="-lxml2"
  export ac_cv_func_fork=no ac_cv_func_system=no ac_cv_func_pipe2=no
  for package in gmp-6.3.0 mpfr-4.2.2 libqalculate-5.13.1; do
    mkdir -p "$BUILD/$platform/$package"
    pushd "$BUILD/$platform/$package" >/dev/null
    echo "Building $package for $platform"
    options=(--host=aarch64-apple-darwin --prefix="$prefix" --disable-shared --enable-static)
    case "$package" in
      gmp*) options+=(--disable-assembly --with-pic) ;;
      mpfr*) options+=(--with-gmp="$prefix") ;;
      libqalculate*) options+=(--disable-textport --disable-unittests --disable-nls --without-libcurl --without-icu --without-gnuplot-call --disable-insecure) ;;
    esac
    "$BUILD/sources/$package/configure" "${options[@]}" > configure.log 2>&1
    if [[ "$package" == libqalculate* ]]; then
      make -C libqalculate -j"${JOBS:-6}" > build.log 2>&1
      make -C libqalculate install > install.log 2>&1
    else
      make -j"${JOBS:-6}" > build.log 2>&1
      make install > install.log 2>&1
    fi
    popd >/dev/null
  done
done
