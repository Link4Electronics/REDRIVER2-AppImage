#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
    libdecor      \
    libjpeg-turbo \
    lua           \
    sdl2          \
    openal        \
    premake
    
echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

# Comment this out if you need an AUR package
#make-aur-package PACKAGENAME

# If the application needs to be manually built that has to be done down here
echo "Making nightly build of REDRIVER2..."
echo "---------------------------------------------------------------"
REPO="https://github.com/OpenDriver2/REDRIVER2"
VERSION="$(git ls-remote "$REPO" HEAD | cut -c 1-9 | head -1)"
git clone --branch develop-SoapyMan --single-branch --recursive --depth 1 "$REPO" ./REDRIVER2
echo "$VERSION" > ~/version

# Only version of premake5 that works with REDRIVER2
#wget https://github.com/premake/premake-core/releases/download/v5.0.0-beta1/premake-5.0.0-beta1-linux.tar.gz -O premake5.tar.gz
#bsdtar -xvf premake5.tar.gz
#rm -f *.gz
#mv -v premake5 /usr/local/bin

mkdir -p ./AppDir/bin
cd ./REDRIVER2/src_rebuild
sed -i 's/require "premake_modules\/usage"/-- require "premake_modules\/usage"/g' premake5.lua
sed -i 's/\bconfiguration\b/filter/g' premake5.lua
sed -i 's/includedirs {/includedirs {\n\t\t"PsyCross\/include",\n\t\t"PsyCross\/include\/psx",\n\t\t"PsyCross\/include\/PsyX",/g' premake5.lua
sed -i 's/links {/links {\n\t\t"PsyCross",\n\t\t"m",/g' premake5.lua
sed -i 's/libdirs {/libdirs {\n\t\t"PsyCross\/bin\/Release",\n\t\t"PsyCross\/bin\/Debug",/g' premake5.lua
if [ "$ARCH" = "aarch64" ]; then
    sed -i 's/platforms { "x86", "x64" }/platforms { "x86", "x64", "arm64" }/g' premake5.lua
    sed -i '/filter "system:Linux"/a \ \ \ \ \ \ \ \ buildoptions { "-fpack-struct=4", "-fpermissive", "-flax-vector-conversions", "-include stdint.h" }' premake5.lua
    find . -type f \( -name "*.c" -o -name "*.h" -o -name "*.C" -o -name "*.cpp" \) -exec sed -i '1s/^\xEF\xBB\xBF//' {} +
    find PsyCross/include/psx/ -name "*.h" -exec sed -i 's/static_assert/\/\/ static_assert/g' {} +
cat << 'EOF' > PsyCross/include/psx/types.h
#ifndef TYPES_H
#define TYPES_H
#include <stdint.h>
#include <sys/types.h>

/* Use macros to force 32-bit sizing without colliding with system typedefs */
#define u_long uint32_t
#define ulong  uint32_t
#define long32 int32_t
#define u_int  uint32_t

typedef uint16_t u_short;
typedef uint8_t  u_char;
typedef uint32_t uint;
#endif
EOF
    sed -i 's/(uint32_t\*)((u_int\*)_addr)/(uint32_t)(uintptr_t)(_addr)/g' PsyCross/include/psx/libgpu.h
    find PsyCross/include/psx/ -name "*.h" -exec sed -i 's/(uint32_t\*)/(uint32_t*)(uintptr_t)/g' {} +
    sed -i 's/(int)vsync_callback/(uintptr_t)vsync_callback/g' PsyCross/src/psx/LIBETC.C
    find PsyCross/src/psx/ -name "*.C" -exec sed -i 's/unsigned long/uintptr_t/g' {} +
    find . -name "dr2locale.h" -exec sed -i 's/typedef unsigned int u_intptr;/typedef uintptr_t u_intptr;/g' {} +
    find . -name "*.h" -o -name "*.c" -o -name "*.cpp" | xargs sed -i 's/(int)st/(uintptr_t)st/g'
    find . -name "FEmain.c" -exec sed -i 's/(void\*)(feVariableSave/(void*)(uintptr_t)(feVariableSave/g' {} +
    find . -type f \( -name "*.c" -o -name "*.h" -o -name "*.cpp" -o -name "*.C" \) | xargs sed -i 's/.*asm.*int3.*/\/* int3 removed *\//g'
    find . -type f \( -name "*.c" -o -name "*.h" -o -name "*.cpp" -o -name "*.C" \) | xargs sed -i 's/__asm { int 3 }/\/* int3 removed *\//g'
    find . -name "*.h" -exec sed -i 's/#define BREAKPOINT.*/#define BREAKPOINT/g' {} +
    find . -name "*.c" -o -name "*.h" | xargs sed -i '1i #define trap(n) \/* trap *\/'
    find PsyCross/include/psx/ -name "*.h" -exec sed -i 's/typedef u_long\s*OTTYPE/typedef uint32_t OTTYPE/g' {} +

    premake5 gmake
    cd build
    make config=release_arm64 -j$(nproc)
else
    premake5 gmake
    cd build
    make config=release_x64 -j$(nproc)
fi
mv -v ../bin/Release/* ../../../AppDir/bin
cd ../..
cp -f .flatpak/icon.png ../AppDir/REDRIVER2.png
cp -r data/DRIVER2 ../AppDir/bin
cp -f data/config.ini ../AppDir/bin
cp -f data/cutscene_recorder.ini ../AppDir/bin
