FROM debian:stable

RUN set -x && apt-get update && apt-get install -y unzip automake build-essential curl file pkg-config git python libtool libtinfo5

WORKDIR /opt/android
## INSTALL ANDROID SDK
ENV ANDROID_SDK_REVISION 4333796
ENV ANDROID_SDK_HASH 92ffee5a1d98d856634e8b71132e8a95d96c83a63fde1099be3d86df3106def9
RUN set -x \
    && curl -s -O https://dl.google.com/android/repository/sdk-tools-linux-${ANDROID_SDK_REVISION}.zip \
    && echo "${ANDROID_SDK_HASH}  sdk-tools-linux-${ANDROID_SDK_REVISION}.zip" | sha256sum -c \
    && unzip sdk-tools-linux-${ANDROID_SDK_REVISION}.zip \
    && rm -f sdk-tools-linux-${ANDROID_SDK_REVISION}.zip

## INSTALL ANDROID NDK
ENV ANDROID_NDK_REVISION 17c
ENV ANDROID_NDK_HASH 3f541adbd0330a9205ba12697f6d04ec90752c53d6b622101a2a8a856e816589
RUN set -x \
    && curl -s -O https://dl.google.com/android/repository/android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip \
    && echo "${ANDROID_NDK_HASH}  android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip" | sha256sum -c \
    && unzip android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip \
    && rm -f android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip

ENV WORKDIR /opt/android
ENV ANDROID_SDK_ROOT ${WORKDIR}/tools
ENV ANDROID_NDK_ROOT ${WORKDIR}/android-ndk-r${ANDROID_NDK_REVISION}
ENV PREFIX /opt/android/prefix

ENV TOOLCHAIN_DIR ${WORKDIR}/toolchain
RUN set -x \
    && ${ANDROID_NDK_ROOT}/build/tools/make_standalone_toolchain.py \
         --arch arm64 \
         --api 21 \
         --install-dir ${TOOLCHAIN_DIR} \
         --stl=libc++

#INSTALL cmake
ARG CMAKE_VERSION=3.13.0
ARG CMAKE_HASH=1c6612f3c6dd62959ceaa96c4b64ba7785132de0b9cbc719eea6fe1365cc8d94
RUN set -x \
    && cd /usr \
    && curl -L -s -O https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-Linux-x86_64.tar.gz \
    && echo "${CMAKE_HASH}  cmake-${CMAKE_VERSION}-Linux-x86_64.tar.gz" | sha256sum -c \
    && tar -xzf /usr/cmake-${CMAKE_VERSION}-Linux-x86_64.tar.gz \
    && rm -f /usr/cmake-${CMAKE_VERSION}-Linux-x86_64.tar.gz
ENV PATH /usr/cmake-${CMAKE_VERSION}-Linux-x86_64/bin:$PATH

## Boost
ARG BOOST_VERSION=1_62_0
ARG BOOST_VERSION_DOT=1.62.0
ARG BOOST_HASH=440a59f8bc4023dbe6285c9998b0f7fa288468b889746b1ef00e8b36c559dce1
RUN set -x \
    && curl -s -L -o  boost_${BOOST_VERSION}.tar.gz https://downloads.sourceforge.net/project/boost/boost/${BOOST_VERSION_DOT}/boost_${BOOST_VERSION}.tar.gz \
    && echo "${BOOST_HASH}  boost_${BOOST_VERSION}.tar.gz" | sha256sum -c \
    && tar -xvf boost_${BOOST_VERSION}.tar.gz \
    && rm -f boost_${BOOST_VERSION}.tar.gz \
    && cd boost_${BOOST_VERSION} \
    && ./bootstrap.sh --prefix=${PREFIX}

ENV HOST_PATH $PATH
ENV PATH $TOOLCHAIN_DIR/aarch64-linux-android/bin:$TOOLCHAIN_DIR/bin:$PATH

ARG NPROC=1

# Build iconv for lib boost locale
ENV ICONV_VERSION 1.16
ENV ICONV_HASH e6a1b1b589654277ee790cce3734f07876ac4ccfaecbee8afa0b649cf529cc04
RUN set -x \
    && curl -s -O http://ftp.gnu.org/pub/gnu/libiconv/libiconv-${ICONV_VERSION}.tar.gz \
    && echo "${ICONV_HASH}  libiconv-${ICONV_VERSION}.tar.gz" | sha256sum -c \
    && tar -xzf libiconv-${ICONV_VERSION}.tar.gz \
    && rm -f libiconv-${ICONV_VERSION}.tar.gz \
    && cd libiconv-${ICONV_VERSION} \
    && CC=aarch64-linux-android-clang CXX=aarch64-linux-android-clang++ ./configure --build=x86_64-linux-gnu --host=aarch64-linux-android --prefix=${PREFIX} --disable-rpath \
    && make -j${NPROC} && make install

## Build BOOST
RUN set -x \
    && cd boost_${BOOST_VERSION} \
    && ./b2 --build-type=minimal link=static runtime-link=static --with-chrono --with-date_time --with-filesystem --with-program_options --with-regex --with-serialization --with-system --with-thread --with-locale --build-dir=android --stagedir=android toolset=clang threading=multi threadapi=pthread target-os=android -sICONV_PATH=${PREFIX} install -j${NPROC}

#Note : we build openssl because the default lacks DSA1

# download, configure and make Zlib
ENV ZLIB_VERSION 1.2.11
ENV ZLIB_HASH c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1
RUN set -x \
    && curl -s -O https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz \
    && echo "${ZLIB_HASH}  zlib-${ZLIB_VERSION}.tar.gz" | sha256sum -c \
    && tar -xzf zlib-${ZLIB_VERSION}.tar.gz \
    && rm zlib-${ZLIB_VERSION}.tar.gz \
    && mv zlib-${ZLIB_VERSION} zlib \
    && cd zlib && CC=clang CXX=clang++ ./configure --static \
    && make -j${NPROC}

# open ssl
ARG OPENSSL_VERSION=1.0.2p
ARG OPENSSL_HASH=50a98e07b1a89eb8f6a99477f262df71c6fa7bef77df4dc83025a2845c827d00
RUN set -x \
    && curl -s -O https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
    && echo "${OPENSSL_HASH}  openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c \
    && tar -xzf openssl-${OPENSSL_VERSION}.tar.gz \
    && rm openssl-${OPENSSL_VERSION}.tar.gz \
    && cd openssl-${OPENSSL_VERSION} \
    && sed -i -e "s/mandroid/target\ aarch64\-linux\-android/" Configure \
    && CC=clang CXX=clang++ \
           ./Configure android \
           no-asm \
           no-shared --static \
           --with-zlib-include=${WORKDIR}/zlib/include --with-zlib-lib=${WORKDIR}/zlib/lib \
           --prefix=${PREFIX} --openssldir=${PREFIX} \
    && make -j${NPROC} \
    && make install

# ZMQ
# 4.2.5 doesn't compile under 64bit android architectures (see issue #3131)
ARG ZMQ_VERSION=v4.3.0
ARG ZMQ_HASH=eff190d5031d313451505f323d3dd1c38ab9c25c
RUN set -x \
    && git clone https://github.com/zeromq/libzmq.git -b ${ZMQ_VERSION} \
    && cd libzmq \
    && test `git rev-parse HEAD` = ${ZMQ_HASH} || exit 1 \
    && ./autogen.sh \
    && CC=clang CXX=clang++ ./configure --prefix=${PREFIX} --host=aarch64-linux-android --enable-static --disable-shared \
    && make -j${NPROC} \
    && make install

# zmq.hpp
ARG CPPZMQ_VERSION=v4.3.0
ARG CPPZMQ_HASH=213da0b04ae3b4d846c9abc46bab87f86bfb9cf4
RUN set -x \
    && git clone https://github.com/zeromq/cppzmq.git -b ${CPPZMQ_VERSION} \
    && cd cppzmq \
    && test `git rev-parse HEAD` = ${CPPZMQ_HASH} || exit 1 \
    && cp *.hpp ${PREFIX}/include

# Sodium
ARG SODIUM_VERSION=1.0.16
ARG SODIUM_HASH=675149b9b8b66ff44152553fb3ebf9858128363d
RUN set -x \
    && git clone https://github.com/jedisct1/libsodium.git -b ${SODIUM_VERSION} \
    && cd libsodium \
    && test `git rev-parse HEAD` = ${SODIUM_HASH} || exit 1 \
    && ./autogen.sh \
    && CC=clang CXX=clang++ ./configure --prefix=${PREFIX} --host=aarch64-linux-android --enable-static --disable-shared \
    && make  -j${NPROC} \
    && make install

COPY . /src
ARG NPROC=4
RUN set -x \
    && cd /src \
    && CMAKE_INCLUDE_PATH="${PREFIX}/include" \
       CMAKE_LIBRARY_PATH="${PREFIX}/lib" \
       ANDROID_STANDALONE_TOOLCHAIN_PATH=${TOOLCHAIN_DIR} \
       USE_SINGLE_BUILDDIR=1 \
       PATH=${HOST_PATH} make release-static-android-armv8-wallet_api -j${NPROC}

RUN set -x \
    && cd /src/build/release \
    && find . -path ./lib -prune -o -name '*.a' -exec cp '{}' lib \;
