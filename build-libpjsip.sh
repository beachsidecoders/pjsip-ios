#!/bin/sh
#
# pjsip project ios build script
#
# portions based on chebur/pjsip build script (https://github.com/chebur/pjsip/blob/master/pjsip.sh)
#
# usage 
#   ./build-libpjsip.sh
#
# options
#   -s [full path to pjsip source directory]
#   -o [full path to pjsip output directory]
#   --with-openssl [full path to openssl directory]
#   --with-openh264 [full path to openh264 directory]
#   --with-opus [full path to opus directory]
#
# license
# The MIT License (MIT)
# 
# Copyright (c) 2016 Beachside Coders LLC
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

# see http://stackoverflow.com/a/3915420/318790
function realpath { echo $(cd $(dirname "$1"); pwd)/$(basename "$1"); }
__FILE__=`realpath "$0"`
__DIR__=`dirname "${__FILE__}"`


IOS_DEPLOYMENT_VERSION="9.0"

#default
PJSIP_SRC_DIR=${__DIR__}/pjproject
PJSIP_OUTPUT_DIR=${__DIR__}/libpjsip

OPENSSL_PREFIX=
OPENH264_PREFIX=
OPUS_PREFIX=
while [ "$#" -gt 0 ]; do
    case $1 in
        -s)
            if [ "$#" -gt 1 ]; then
                PJSIP_SRC_DIR=$2
                shift 2
                continue
            else
                echo 'ERROR: Please specify source directory.' >&2
                exit 1
            fi
            ;;
        -o)
            if [ "$#" -gt 1 ]; then
                PJSIP_OUTPUT_DIR=$2
                shift 2
                continue
            else
                echo 'ERROR: Please specify output directory.' >&2
                exit 1
            fi
            ;;
        --with-openssl)
            if [ "$#" -gt 1 ]; then
                OPENSSL_PREFIX=$2
                shift 2
                continue
            else
                echo 'ERROR: Please specify openssl directory.' >&2
                exit 1
            fi
            ;;
        --with-openh264)
            if [ "$#" -gt 1 ]; then
                OPENH264_PREFIX=$2
                shift 2
                continue
            else
                echo 'ERROR: Please specify openh264 directory.' >&2
                exit 1
            fi
            ;;
        --with-opus)
            if [ "$#" -gt 1 ]; then
                OPUS_PREFIX=$2
                shift 2
                continue
            else
                echo 'ERROR: Please specify opus directory.' >&2
                exit 1
            fi
            ;;
    esac

    shift
done

PJSIP_LOG_DIR="${PJSIP_OUTPUT_DIR}/log"
PJSIP_BUILD_DIR=${__DIR__}/build
PJSIP_SRC_WORKING_DIR=${PJSIP_BUILD_DIR}/pjproject-src
PJSIP_CONFIG_PATH="${PJSIP_SRC_WORKING_DIR}/pjlib/include/pj/config_site.h"
PJLIB_PATHS=("pjlib/lib" \
             "pjlib-util/lib" \
             "pjmedia/lib" \
             "pjnath/lib" \
             "pjsip/lib" \
             "third_party/lib")

if [ "${PJSIP_SRC_DIR}" = "${PJSIP_OUTPUT_DIR}" ]; then
    echo 'ERROR: Output directory must not be the source directory. Please specify a different output directory.' >&2
    exit 1
fi

function remove_pj_output () {
    PJ_LIB=$1

    PJ_OUTPUT_DIR="${PJSIP_OUTPUT_DIR}/${PJ_LIB}"

    if [ -d ${PJ_OUTPUT_DIR} ]; then
        rm -rf ${PJ_OUTPUT_DIR}
    fi
}

function prepare_build () {
    echo "Preparing build..."

    # remove old output
    if [ -d ${PJSIP_LOG_DIR} ]; then
        rm -rf ${PJSIP_LOG_DIR}
    fi

    remove_pj_output pjsip
    remove_pj_output pjlib
    remove_pj_output pjlib-util
    remove_pj_output pjnath
    remove_pj_output pjmedia
    remove_pj_output third_party

    if [ -d ${PJSIP_BUILD_DIR} ]; then
      rm -rf ${PJSIP_BUILD_DIR}
    fi

    # create output
    if [ ! -d ${PJSIP_OUTPUT_DIR} ]; then
        mkdir ${PJSIP_OUTPUT_DIR}
    fi

    # create log directory
    if [ ! -d ${PJSIP_LOG_DIR} ]; then
        mkdir ${PJSIP_LOG_DIR}
    fi

    # create build directory
    if [ ! -d ${PJSIP_BUILD_DIR} ]; then
        mkdir ${PJSIP_BUILD_DIR}
    fi

    # create working source
    rsync -av --exclude=.git ${PJSIP_SRC_DIR}/ ${PJSIP_SRC_WORKING_DIR} > "${PJSIP_LOG_DIR}/build.log" 2>&1
}

function config_site() {
    echo "Creating config.h..."

    HAS_VIDEO=

    echo "#define PJ_CONFIG_IPHONE 1" >> "${PJSIP_CONFIG_PATH}"
    if [[ ${OPENH264_PREFIX} ]]; then
        echo "#define PJMEDIA_HAS_OPENH264_CODEC 1" >> "${PJSIP_CONFIG_PATH}"
        HAS_VIDEO=1
    fi
    if [[ ${HAS_VIDEO} ]]; then
        echo "#define PJMEDIA_HAS_VIDEO 1" >> "${PJSIP_CONFIG_PATH}"
        echo "#define PJMEDIA_VIDEO_DEV_HAS_OPENGL 1" >> "${PJSIP_CONFIG_PATH}"
        echo "#define PJMEDIA_VIDEO_DEV_HAS_OPENGL_ES 1" >> "${PJSIP_CONFIG_PATH}"
        echo "#define PJMEDIA_VIDEO_DEV_HAS_IOS_OPENGL 1" >> "${PJSIP_CONFIG_PATH}"
        echo "#include <OpenGLES/ES3/glext.h>" >> "${PJSIP_CONFIG_PATH}"
    fi
    echo "#include <pj/config_site_sample.h>" >> "${PJSIP_CONFIG_PATH}"
}

function copy_arch_libs () {
    ARCH=${1}

    for SRC_DIR in ${PJLIB_PATHS[*]}; do
        SRC_DIR="${PJSIP_SRC_WORKING_DIR}/${SRC_DIR}"
        DST_DIR="${SRC_DIR}-${ARCH}"
        if [ -d "${DST_DIR}" ]; then
            rm -rf "${DST_DIR}"
        fi
        cp -R "${SRC_DIR}" "${DST_DIR}"

    done
}

function remove_arch_libs () {
    ARCH=${1}

    for LIB_DIR in ${PJLIB_PATHS[*]}; do
        LIB_DIR="${PJSIP_SRC_WORKING_DIR}/${LIB_DIR}"
        LIB_ARCH_DIR="${LIB_DIR}-${ARCH}"
        if [ -d "${LIB_ARCH_DIR}" ]; then
            rm -rf "${LIB_ARCH_DIR}"
        fi
    done    
}

function build_arch () {
    ARCH=$1
    LOG=${PJSIP_LOG_DIR}/${ARCH}.log

    pushd . > /dev/null
    cd ${PJSIP_SRC_WORKING_DIR}

    # configure
    CONFIGURE="./configure-iphone"
    if [[ ${OPENSSL_PREFIX} ]]; then
        CONFIGURE="${CONFIGURE} --with-ssl=${OPENSSL_PREFIX}"
    fi
    if [[ ${OPENH264_PREFIX} ]]; then
        CONFIGURE="${CONFIGURE} --with-openh264=${OPENH264_PREFIX}"
    fi
    if [[ ${OPUS_PREFIX} ]]; then
        CONFIGURE="${CONFIGURE} --with-opus=${OPUS_PREFIX}"
    fi

    # flags
    if [[ ! ${CFLAGS} ]]; then
        export CFLAGS=
    fi
    if [[ ! ${LDFLAGS} ]]; then
        export LDFLAGS=
    fi
    if [[ ${OPENSSL_PREFIX} ]]; then
        export CFLAGS="${CFLAGS} -I${OPENSSL_PREFIX}/include"
        export LDFLAGS="${LDFLAGS} -L${OPENSSL_PREFIX}/lib"
    fi
    if [[ ${OPENH264_PREFIX} ]]; then
        export CFLAGS="${CFLAGS} -I${OPENH264_PREFIX}/include"
        export LDFLAGS="${LDFLAGS} -L${OPENH264_PREFIX}/lib"
    fi
    if [[ ${OPUS_PREFIX} ]]; then
        export CFLAGS="${CFLAGS} -I${OPUS_PREFIX}/include"
        export LDFLAGS="${LDFLAGS} -L${OPUS_PREFIX}/lib"
    fi
    export LDFLAGS="${LDFLAGS} -lstdc++"

    echo "Building ${ARCH}..."

    make distclean > ${LOG} 2>&1
    ARCH="-arch ${ARCH}" ${CONFIGURE} >> ${LOG} 2>&1
    make dep >> ${LOG} 2>&1
    make clean >> ${LOG}
    make >> ${LOG} 2>&1

    copy_arch_libs ${ARCH}

    popd > /dev/null
}

function armv7() {
    export CFLAGS="-miphoneos-version-min=${IOS_DEPLOYMENT_VERSION}"
    export LDFLAGS="-miphoneos-version-min=${IOS_DEPLOYMENT_VERSION}"
    build_arch "armv7"
}

function armv7s() {
    export CFLAGS="-miphoneos-version-min=${IOS_DEPLOYMENT_VERSION}"
    export LDFLAGS="-miphoneos-version-min=${IOS_DEPLOYMENT_VERSION}"
    build_arch "armv7s"
}

function arm64() {
    export CFLAGS="-miphoneos-version-min=${IOS_DEPLOYMENT_VERSION}"
    export LDFLAGS="-miphoneos-version-min=${IOS_DEPLOYMENT_VERSION}"
    build_arch "arm64"
}

function i386() {
    export DEVPATH="`xcrun -sdk iphonesimulator --show-sdk-platform-path`/Developer"
    export CFLAGS="-O2 -m32 -mios-simulator-version-min=${IOS_DEPLOYMENT_VERSION}"
    export LDFLAGS="-O2 -m32 -mios-simulator-version-min=${IOS_DEPLOYMENT_VERSION}"
    build_arch "i386"
}

function x86_64() {
    export DEVPATH="`xcrun -sdk iphonesimulator --show-sdk-platform-path`/Developer"
    export CFLAGS="-O2 -m32 -mios-simulator-version-min=${IOS_DEPLOYMENT_VERSION}"
    export LDFLAGS="-O2 -m32 -mios-simulator-version-min=${IOS_DEPLOYMENT_VERSION}"
    build_arch "x86_64"
}

function build_pj () {
    # create config_site
    config_site

    # build all architectures
    armv7 && armv7s && arm64 && i386 && x86_64
}

function lipo_libs() {
    echo "Lipo libs..."

    # pjlib
    PJLIB_LIB_OUTPUT_DIR="${PJSIP_OUTPUT_DIR}/pjlib/lib"

    if [ ! -d ${PJLIB_LIB_OUTPUT_DIR} ]; then
        mkdir -p ${PJLIB_LIB_OUTPUT_DIR}
    fi

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/pjlib/lib-armv7/libpj-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/pjlib/lib-armv7s/libpj-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/pjlib/lib-arm64/libpj-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/pjlib/lib-i386/libpj-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/pjlib/lib-x86_64/libpj-x86_64-apple-darwin_ios.a \
                             -create -output ${PJLIB_LIB_OUTPUT_DIR}/libpj-apple-darwin_ios.a

    # pjlib-util
    PJLIB_UTIL_LIB_OUTPUT_DIR="${PJSIP_OUTPUT_DIR}/pjlib-util/lib"

    if [ ! -d ${PJLIB_UTIL_LIB_OUTPUT_DIR} ]; then
        mkdir -p ${PJLIB_UTIL_LIB_OUTPUT_DIR}
    fi

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/pjlib-util/lib-armv7/libpjlib-util-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/pjlib-util/lib-armv7s/libpjlib-util-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/pjlib-util/lib-arm64/libpjlib-util-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/pjlib-util/lib-i386/libpjlib-util-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/pjlib-util/lib-x86_64/libpjlib-util-x86_64-apple-darwin_ios.a \
                             -create -output ${PJLIB_UTIL_LIB_OUTPUT_DIR}/libpjlib-util-apple-darwin_ios.a

    # pjnath
    PJNATH_LIB_OUTPUT_DIR="${PJSIP_OUTPUT_DIR}/pjnath/lib"

    if [ ! -d ${PJNATH_LIB_OUTPUT_DIR} ]; then
        mkdir -p ${PJNATH_LIB_OUTPUT_DIR}
    fi

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/pjnath/lib-armv7/libpjnath-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/pjnath/lib-armv7s/libpjnath-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/pjnath/lib-arm64/libpjnath-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/pjnath/lib-i386/libpjnath-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/pjnath/lib-x86_64/libpjnath-x86_64-apple-darwin_ios.a \
                             -create -output ${PJNATH_LIB_OUTPUT_DIR}/libpjnath-apple-darwin_ios.a

    # pjsip
    PJSIP_LIB_OUTPUT_DIR="${PJSIP_OUTPUT_DIR}/pjsip/lib"

    if [ ! -d ${PJSIP_LIB_OUTPUT_DIR} ]; then
        mkdir -p ${PJSIP_LIB_OUTPUT_DIR}
    fi

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-armv7/libpjsip-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-armv7s/libpjsip-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-arm64/libpjsip-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-i386/libpjsip-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-x86_64/libpjsip-x86_64-apple-darwin_ios.a \
                             -create -output ${PJSIP_LIB_OUTPUT_DIR}/libpjsip-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-armv7/libpjsip-simple-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-armv7s/libpjsip-simple-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-arm64/libpjsip-simple-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-i386/libpjsip-simple-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-x86_64/libpjsip-simple-x86_64-apple-darwin_ios.a \
                             -create -output ${PJSIP_LIB_OUTPUT_DIR}/libpjsip-simple-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-armv7/libpjsip-ua-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-armv7s/libpjsip-ua-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-arm64/libpjsip-ua-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-i386/libpjsip-ua-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-x86_64/libpjsip-ua-x86_64-apple-darwin_ios.a \
                             -create -output ${PJSIP_LIB_OUTPUT_DIR}/libpjsip-ua-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-armv7/libpjsua-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-armv7s/libpjsua-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-arm64/libpjsua-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-i386/libpjsua-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-x86_64/libpjsua-x86_64-apple-darwin_ios.a \
                             -create -output ${PJSIP_LIB_OUTPUT_DIR}/libpjsua-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-armv7/libpjsua2-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-armv7s/libpjsua2-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-arm64/libpjsua2-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-i386/libpjsua2-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/pjsip/lib-x86_64/libpjsua2-x86_64-apple-darwin_ios.a \
                             -create -output ${PJSIP_LIB_OUTPUT_DIR}/libpjsua2-apple-darwin_ios.a


    # pjmedia
    PJMEDIA_LIB_OUTPUT_DIR="${PJSIP_OUTPUT_DIR}/pjmedia/lib"

    if [ ! -d ${PJMEDIA_LIB_OUTPUT_DIR} ]; then
        mkdir -p ${PJMEDIA_LIB_OUTPUT_DIR}
    fi

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-armv7/libpjmedia-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-armv7s/libpjmedia-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-arm64/libpjmedia-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-i386/libpjmedia-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-x86_64/libpjmedia-x86_64-apple-darwin_ios.a \
                             -create -output ${PJMEDIA_LIB_OUTPUT_DIR}/libpjmedia-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-armv7/libpjmedia-audiodev-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-armv7s/libpjmedia-audiodev-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-arm64/libpjmedia-audiodev-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-i386/libpjmedia-audiodev-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-x86_64/libpjmedia-audiodev-x86_64-apple-darwin_ios.a \
                             -create -output ${PJMEDIA_LIB_OUTPUT_DIR}/libpjmedia-audiodev-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-armv7/libpjmedia-codec-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-armv7s/libpjmedia-codec-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-arm64/libpjmedia-codec-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-i386/libpjmedia-codec-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-x86_64/libpjmedia-codec-x86_64-apple-darwin_ios.a \
                             -create -output ${PJMEDIA_LIB_OUTPUT_DIR}/libpjmedia-codec-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-armv7/libpjmedia-videodev-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-armv7s/libpjmedia-videodev-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-arm64/libpjmedia-videodev-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-i386/libpjmedia-videodev-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-x86_64/libpjmedia-videodev-x86_64-apple-darwin_ios.a \
                             -create -output ${PJMEDIA_LIB_OUTPUT_DIR}/libpjmedia-videodev-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-armv7/libpjsdp-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-armv7s/libpjsdp-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-arm64/libpjsdp-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-i386/libpjsdp-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/pjmedia/lib-x86_64/libpjsdp-x86_64-apple-darwin_ios.a \
                             -create -output ${PJMEDIA_LIB_OUTPUT_DIR}/libpjsdp-apple-darwin_ios.a

    # pj_third_party
    PJ_THIRD_PARTY_LIB_OUTPUT_DIR="${PJSIP_OUTPUT_DIR}/third_party/lib"

    if [ ! -d ${PJ_THIRD_PARTY_LIB_OUTPUT_DIR} ]; then
        mkdir -p ${PJ_THIRD_PARTY_LIB_OUTPUT_DIR}
    fi

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/third_party/lib-armv7/libg7221codec-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/third_party/lib-armv7s/libg7221codec-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/third_party/lib-arm64/libg7221codec-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/third_party/lib-i386/libg7221codec-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/third_party/lib-x86_64/libg7221codec-x86_64-apple-darwin_ios.a \
                             -create -output ${PJ_THIRD_PARTY_LIB_OUTPUT_DIR}/libg7221codec-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/third_party/lib-armv7/libgsmcodec-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/third_party/lib-armv7s/libgsmcodec-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/third_party/lib-arm64/libgsmcodec-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/third_party/lib-i386/libgsmcodec-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/third_party/lib-x86_64/libgsmcodec-x86_64-apple-darwin_ios.a \
                             -create -output ${PJ_THIRD_PARTY_LIB_OUTPUT_DIR}/libgsmcodec-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/third_party/lib-armv7/libilbccodec-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/third_party/lib-armv7s/libilbccodec-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/third_party/lib-arm64/libilbccodec-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/third_party/lib-i386/libilbccodec-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/third_party/lib-x86_64/libilbccodec-x86_64-apple-darwin_ios.a \
                             -create -output ${PJ_THIRD_PARTY_LIB_OUTPUT_DIR}/libilbccodec-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/third_party/lib-armv7/libresample-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/third_party/lib-armv7s/libresample-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/third_party/lib-arm64/libresample-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/third_party/lib-i386/libresample-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/third_party/lib-x86_64/libresample-x86_64-apple-darwin_ios.a \
                             -create -output ${PJ_THIRD_PARTY_LIB_OUTPUT_DIR}/libresample-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/third_party/lib-armv7/libspeex-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/third_party/lib-armv7s/libspeex-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/third_party/lib-arm64/libspeex-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/third_party/lib-i386/libspeex-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/third_party/lib-x86_64/libspeex-x86_64-apple-darwin_ios.a \
                             -create -output ${PJ_THIRD_PARTY_LIB_OUTPUT_DIR}/libspeex-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_SRC_WORKING_DIR}/third_party/lib-armv7/libsrtp-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_SRC_WORKING_DIR}/third_party/lib-armv7s/libsrtp-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_SRC_WORKING_DIR}/third_party/lib-arm64/libsrtp-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_SRC_WORKING_DIR}/third_party/lib-i386/libsrtp-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_SRC_WORKING_DIR}/third_party/lib-x86_64/libsrtp-x86_64-apple-darwin_ios.a \
                             -create -output ${PJ_THIRD_PARTY_LIB_OUTPUT_DIR}/libsrtp-apple-darwin_ios.a

}

function copy_pj_include () {
    PJ_LIB=$1

    PJ_HEADER_SRC_DIR="${PJSIP_SRC_WORKING_DIR}/${PJ_LIB}/include"
    PJ_HEADER_DST_DIR="${PJSIP_OUTPUT_DIR}/${PJ_LIB}"

    if [ ! -d ${PJ_HEADER_DST_DIR} ]; then
        mkdir -p ${PJ_HEADER_DST_DIR}
    fi

    cp -R "${PJ_HEADER_SRC_DIR}" "${PJ_HEADER_DST_DIR}"
}

function copy_includes () {
    echo "Copy includes..."
 
    copy_pj_include pjsip
    copy_pj_include pjlib
    copy_pj_include pjlib-util
    copy_pj_include pjnath
    copy_pj_include pjmedia
}

function package_pj () {
    lipo_libs
    copy_includes
}

function clean_up_build () {
    echo "Cleaning up..."

    if [ -d ${PJSIP_BUILD_DIR} ]; then
        rm -rf ${PJSIP_BUILD_DIR}
    fi
}


echo "Build pjsip..."
prepare_build
build_pj
package_pj
clean_up_build
echo "Done."
