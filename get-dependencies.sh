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
    openal
    
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
wget https://github.com/premake/premake-core/releases/download/v5.0.0-beta1/premake-5.0.0-beta1-linux.tar.gz -O premake5.tar.gz
bsdtar -xvf premake5.tar.gz
rm -f *.gz
chmod +x premake5
mv premake5 /usr/local/bin

mkdir -p ./AppDir/bin
cd ./REDRIVER2/src_rebuild
premake5 gmake
cd build
make config=release_x64 -j$(nproc)
mv -v REDRIVER2 ../../AppDir/bin
cd ../..
cp -f .flatpak/io.github.opendriver2.Redriver2.desktop ../AppDir
cp -f .flatpak/icon.png ../AppDir
cp -r data/DRIVER2 ../AppDir/bin
cp -f data/config.ini ../AppDir/bin
cp -f data/cutscene_recorder.ini ../AppDir/bin
