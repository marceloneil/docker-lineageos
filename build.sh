#!/bin/bash

# Assign user
export USER="build"

# Set default environment variables
DEVICE_LIST=
JACK_RAM="4G"
export USE_CCACHE=1
CCACHE_SIZE="75G"
TAG=14.1
TYPE="WEEKLY"
SIGN_BUILDS=0
NAME=
EMAIL=

while [[ $# > 0 ]]; do
    key="$1"
    case $key in
        --device-list) DEVICE_LIST=$2 ;;
        --jack-ram) JACK_RAM=$2 ;;
        --no-ccache) export USE_CCACHE=0 ;;
        --ccache-size) CCACHE_SIZE=$2 ;;
        -t|--tag) TAG=$2 ;;
        --type) TYPE=$2 ;;
        --sign-builds) SIGN_BUILDS=1 ;;
        --migration) TYPE="MIGRATION" && SIGN_BUILDS=1 ;;
        --name) NAME=$2 ;;
        --email) EMAIL=$2 ;;
    esac
    shift
done

# Set Name and Email
git config --global user.email $EMAIL
git config --global user.name $NAME
# Allocate RAM to jack
export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx$JACK_RAM"

# Initialize ccache if needed
if [ $USE_CCACHE == 1 ]; then
    echo "Initializing ccache in /srv/ccache..."
    if [ ! -f /srv/ccache/ccache.conf ]; then
        export CCACHE_DIR=/srv/ccache ccache -M $CCACHE_SIZE
    else
        export CCACHE_DIR=/srv/ccache
    fi
fi

# Initialize repository if needed
if [ ! "$(ls -A)" ]; then
    repo init -u https://github.com/LineageOS/android.git -b cm-$TAG
fi

repo sync
source build/envsetup.sh

# The following code is in part from julianxhokaxhiu/docker-lineage-cicd
IFS=','
for codename in $DEVICE_LIST; do
    if [ ! -z "$codename" ]; then
        breakfast $codename
        if [ $SIGN_BUILDS == 1 ]; then
            mka target-files-package dist
            croot
            ./build/tools/releasetools/sign_target_files_apks -o \
                -d /build/android-certs \
                out/dist/*-target_files-*.zip \
                out/dist/signed-target_files.zip
            ./build/tools/releasetools/ota_from_target_files \
                -k /build/android-certs/releasekey \
                --block --backup=true \
                out/dist/signed-target_files.zip \
                /build/zips/lineage-$TAG-"$(date +%Y%m%d)"-$TYPE-$codename.zip
        elif [ $SIGN_BUILDS == 0]; then
            croot
            brunch oneplus3
        fi
        /usr/bin/make clean
    fi
done
