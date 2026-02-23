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
    sed -i '/filter "system:Linux"/a \ \ \ \ \ \ \ \ buildoptions { "-fpack-struct=4", "-fpermissive", "-flax-vector-conversions" }' premake5.lua
    find PsyCross/include/psx/ -name "*.h" -exec sed -i 's/typedef long\s*long32/typedef int long32/g' {} +
    find PsyCross/include/psx/ -name "*.h" -exec sed -i 's/typedef unsigned long\s*u_long/typedef unsigned int u_long/g' {} +
    find PsyCross/include/psx/ -name "*.h" -exec sed -i 's/typedef unsigned long\s*ulong/typedef unsigned int ulong/g' {} +
    find PsyCross/include/psx/ -name "*.h" -exec sed -i 's/void\s*\*.*tag/unsigned int tag/g' {} +
    find PsyCross/include/psx/ -name "*.h" -exec sed -i 's/#define P_LEN.*/#define P_LEN (1)/g' {} +
    sed -i 's/(int)vsync_callback/(uintptr_t)vsync_callback/g' PsyCross/src/psx/LIBETC.C

    premake5 gmake
    cd build
    make config=release_arm64 -j$(nproc)
fi
Use code with caution.

Why the error was (6 == 4):
Original header: void* tag (8 bytes) + long (8 bytes) + long (8 bytes) = 24 bytes.
24 / 4 = 6.
If P_LEN was 2 (default for 64-bit), you get 6 - 2 = 4. It passes! BUT the data is aligned wrong for the PSX engine.
By shrinking tag to 4 bytes but leaving another long at 8 bytes, the math breaks.
By shrinking everything to 4 bytes (int) and setting P_LEN to 1, we match the original PlayStation hardware's memory layout.
Try running this. If it still fails, please run this command and show me the output:
grep -A 5 "typedef struct {" PsyCross/include/psx/libgpu.h | head -n 20



Ask anything




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
