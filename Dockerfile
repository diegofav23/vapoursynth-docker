FROM nvidia/cuda@sha256:520292dbb4f755fd360766059e62956e9379485d9e073bbd2f6e3c20c270ed66 AS build

# ------------------------
# Versions
# ------------------------

ARG PYTHON_VERSION="3.12.9"
ARG CUDA_VERSION="12.8"
ARG TENSORRT_VERSION="10.9.0.34"
ARG ZIMG_VERSION="3.0.5"
ARG VAPOURSYNTH_VERSION="70"
ARG FFMPEG_VERSION="7.1.1"
ARG FFTW_VERSION="3.3.10"
ARG XXHASH_VERSION="0.8.3"
ARG LSMASH_VERSION="2.18.0"
ARG OBUPARSE_SHA="918524abdc19b6582d853c03373d8e2e0b9f11ee"

ARG VS_MLRT_VERSION="15.9"
ARG VS_FFMS2_VERSION="5.0"
ARG VS_BESTSOURCE_VERSION="11"
ARG VS_MVTOOLS_VERSION="24"
ARG VS_NNEDI3_VERSION="12"
ARG VS_UTIL_VERSION="0.8.0"
ARG VS_LSMASH_SHA="609d85f9ce5b17006649987e79ba5c0109a7dd9c"
ARG VS_MISCOBSOLETE_SHA="07e0589a381f7deb3bf533bb459a94482bccc5c7"
ARG VS_NNEDI3CL_SHA="eb2a810c0b7dfdd3ad908a1bdc07d6daab64eb57"
ARG VS_EEDI3_SHA="d11bdb37c7a7118cd095b53d9f8fbbac02a06ac0"
ARG VS_ZNEDI3_SHA="68dc130bc37615fd912d1dc1068261f00f54b146"
ARG VS_TIVTC_SHA="7abd4a3bc1fdc625400bc4f84ba618ee6a8da53a"
ARG VS_EDGEFIXER_SHA="562e06dcf21d2aed3fde54b97b9b19e4ca4e335d"

# ------------------------
# Initial setup
# ------------------------

# Enable source code repositories
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources

# Install tools from repositories
RUN apt update && apt install -y --no-install-recommends \
    build-essential \
    autoconf \
    automake \
    libtool \
    git \
    pkg-config \
    wget \
    cmake \
    meson \
    ninja-build \
    yasm \
    nasm \
    ca-certificates \
    gdb \
    lcov \
    libbz2-dev \
    libffi-dev \
    libgdbm-dev \
    libgdbm-compat-dev \
    liblzma-dev \
    libncurses5-dev \
    libreadline6-dev \
    libsqlite3-dev \
    libssl-dev \
    lzma \
    lzma-dev \
    tk-dev \
    uuid-dev \
    zlib1g-dev \
    libboost-all-dev \
    libdav1d-dev \
    libxml2-dev \
    libvpx-dev

# Install python build dependencies
RUN apt build-dep -y python3

# Update CA certificates
RUN update-ca-certificates

# ------------------------
# Dependencies compilation
# ------------------------

WORKDIR /installation

# TensorRT
RUN wget -q https://developer.nvidia.com/downloads/compute/machine-learning/tensorrt/10.9.0/tars/TensorRT-${TENSORRT_VERSION}.Linux.x86_64-gnu.cuda-${CUDA_VERSION}.tar.gz -O TensorRT.tar.gz \
    && tar -xzf TensorRT.tar.gz \
    && cd TensorRT-${TENSORRT_VERSION}/targets/x86_64-linux-gnu \
    && rm lib/*nvinfer_builder_resource_win* lib/libnvinfer_dispatch* lib/libnvinfer_lean* \
    && mv lib/*.so* /usr/local/lib \
    && mv bin/* /usr/local/bin \
    && cd ../.. \
    && mv include/* /usr/local/include

# Python
RUN wget -q https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz \
    && tar -xf Python-${PYTHON_VERSION}.tar.xz \
    && cd Python-${PYTHON_VERSION} \
    && CFLAGS=-fPIC ./configure --with-openssl-rpath=auto --enable-optimizations --disable-test-modules \
    && make -j$(nproc) \
    && make altinstall \
    && make install

RUN python3 -m ensurepip

# Zimg
RUN git clone --recurse-submodules --depth 1 --branch release-${ZIMG_VERSION} "https://github.com/sekrit-twc/zimg.git" \
    && cd zimg \
    && ./autogen.sh \
    && ./configure --disable-static \
    && make -j $(nproc) \
    && make install

# Vapoursynth
RUN python3 -m pip install --break-system-package cython

RUN git clone --depth 1 --branch R${VAPOURSYNTH_VERSION} "https://github.com/vapoursynth/vapoursynth.git" \
    && cd vapoursynth \
    && ./autogen.sh \
    && ./configure --disable-static \
    && make -j $(nproc) \
    && make install

# FFmpeg
RUN git clone --depth 1 --branch n${FFMPEG_VERSION} https://git.ffmpeg.org/ffmpeg.git \
    && cd ffmpeg \
    && ./configure --enable-shared --disable-programs --disable-debug --disable-doc --disable-static --enable-nonfree --enable-gpl --disable-postproc --disable-avfilter \
    && make -j $(nproc) \
    && make install

# FFTW
RUN wget -q https://fftw.org/fftw-${FFTW_VERSION}.tar.gz \
    && tar -xzf fftw-${FFTW_VERSION}.tar.gz \
    && cd fftw-${FFTW_VERSION} \
    && ./configure --disable-static --enable-shared --enable-single \
    && make -j $(nproc) \
    && make install

# XxHash
RUN git clone --depth 1 --branch v${XXHASH_VERSION} https://github.com/Cyan4973/xxHash.git \
    && cd xxHash \
    && cmake -S ./cmake_unofficial -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DXXHASH_BUILD_XXHSUM=OFF \
    && cmake --build build -j $(nproc) \
    && cmake --install build

# Obuparse
RUN git clone https://github.com/dwbuiten/obuparse.git \
    && cd obuparse \
    && git checkout ${OBUPARSE_SHA} \
    && make -j $(nproc) \
    && make install

# L-SMASH
RUN git clone --depth 1 --branch v${LSMASH_VERSION} https://github.com/vimeo/l-smash.git \
    && cd l-smash \
    && mv configure configure.old \
    && sed 's/-Wl,--version-script,liblsmash.ver//g' configure.old > configure \
    && chmod +x configure \
    && ./configure --disable-static \
    && make lib -j $(nproc) \
    && make install-lib

# ------------------------
# Vapoursynth Plugins
# ------------------------

WORKDIR /vsplugins

# vsmlrt + vstrt
RUN git clone --depth 1 --branch v${VS_MLRT_VERSION} https://github.com/AmusementClub/vs-mlrt.git \
    && cd vs-mlrt/vstrt \
    && cmake -S . -B build -G Ninja -D CMAKE_BUILD_TYPE=Release -D VAPOURSYNTH_INCLUDE_DIRECTORY="/usr/local/include/vapoursynth" \
    && cmake --build build \
    && cmake --install build --prefix install

# vsmlrt script patch to simplify usage (trtexec and LD_LIBRARY_PATH from OS PATH)
RUN cd vs-mlrt/scripts \
    && sed -i 's|os\.path\.join(plugins_path, "vsmlrt-cuda", "trtexec")|"/usr/local/bin/trtexec"|' vsmlrt.py \
    && sed -i 's|{env_key: prev_env_value, "CUDA_MODULE_LOADING": "LAZY"}|{env_key: prev_env_value, "CUDA_MODULE_LOADING": "LAZY", "LD_LIBRARY_PATH": os.environ.get("LD_LIBRARY_PATH")}|' vsmlrt.py \
    && sed -i 's|{env_key: log_filename, "CUDA_MODULE_LOADING": "LAZY"}|{env_key: log_filename, "CUDA_MODULE_LOADING": "LAZY", "LD_LIBRARY_PATH": os.environ.get("LD_LIBRARY_PATH")}|' vsmlrt.py \
    && sed -i 's|{"CUDA_MODULE_LOADING": "LAZY"}|{"CUDA_MODULE_LOADING": "LAZY", "LD_LIBRARY_PATH": os.environ.get("LD_LIBRARY_PATH")}|' vsmlrt.py

# ffms2
RUN git clone --depth 1 --branch ${VS_FFMS2_VERSION} https://github.com/FFMS/ffms2.git \
    && cd ffms2 \
    && mkdir build \
    && ./autogen.sh \
    && ./configure --prefix="/vsplugins/ffms2/build" \
    && make -j $(nproc) \
    && make install

# bestsource
RUN git clone --depth 1 --recurse-submodules --branch R${VS_BESTSOURCE_VERSION} https://github.com/vapoursynth/bestsource.git \
    && cd bestsource \
    && meson setup build -Ddefault_library=static \
    && ninja -C build

# L-SMASH Source with patch to use shared zlib
RUN git clone https://github.com/HomeOfAviSynthPlusEvolution/L-SMASH-Works.git \
    && cd L-SMASH-Works \
    && git checkout ${VS_LSMASH_SHA} \
    && sed -i 's/^set(ZLIB_USE_STATIC_LIBS ON)/# &/' CMakeLists.txt \
    && cmake -S . -B build -G Ninja -DBUILD_AVS_PLUGIN=OFF -DENABLE_MFX=OFF -DENABLE_VULKAN=OFF \
    && cmake --build build -j $(nproc)

# vs-misc
RUN git clone https://github.com/vapoursynth/vs-miscfilters-obsolete.git \
    && cd vs-miscfilters-obsolete \
    && git checkout ${VS_MISCOBSOLETE_SHA} \
    && meson setup build \
    && ninja -C build

# vapoursynth-mvtools
RUN git clone --depth 1 --branch v${VS_MVTOOLS_VERSION} https://github.com/dubhater/vapoursynth-mvtools.git \
    && cd vapoursynth-mvtools \
    && meson setup build \
    && ninja -C build

# nnedi3cl
RUN git clone https://github.com/HomeOfVapourSynthEvolution/VapourSynth-NNEDI3CL.git \
    && cd VapourSynth-NNEDI3CL \
    && git checkout ${VS_NNEDI3CL_VERSION} \
    && meson setup build \
    && ninja -C build

# eedi3
RUN git clone https://github.com/HomeOfVapourSynthEvolution/VapourSynth-EEDI3.git \
    && cd VapourSynth-EEDI3 \
    && git checkout ${VS_EEDI3_SHA} \
    && meson setup build \
    && ninja -C build

# nnedi3
RUN git clone --depth 1 --branch v${VS_NNEDI3_VERSION} https://github.com/dubhater/vapoursynth-nnedi3.git \
    && cd vapoursynth-nnedi3 \
    && mkdir build \
    && ./autogen.sh \
    && ./configure --prefix="/vsplugins/vapoursynth-nnedi3/build" \
    && make -j $(nproc) \
    && make install

# znedi3
RUN git clone --recurse-submodules https://github.com/sekrit-twc/znedi3.git \
    && cd znedi3 \
    && git checkout ${VS_ZNEDI3_SHA} \
    && make X86=1 -j $(nproc)

# tivtc
RUN git clone https://github.com/dubhater/vapoursynth-tivtc.git \
    && cd vapoursynth-tivtc \
    && git checkout ${VS_TIVTC_SHA} \
    && meson setup build \
    && ninja -C build

# edgefixer
RUN git clone https://github.com/sekrit-twc/EdgeFixer.git \
    && cd EdgeFixer \
    && git checkout ${VS_EDGEFIXER_SHA} \
    && cd EdgeFixer \
    && gcc -shared -o ../edgefixer.so edgefixer.c vsplugin.c -lm -I "/usr/local/include/vapoursynth"

ENV PATH="/usr/local/cuda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"

# vsutil | mvsfunc
RUN python3 -m pip install --break-system-packages \
    VapourSynth==${VAPOURSYNTH_VERSION} \
    vsutil==${VS_UTIL_VERSION} \
    git+https://github.com/HomeOfVapourSynthEvolution/mvsfunc \
    tabulate \
    cuda-core[cu12]

# havsfunc
RUN wget -q https://raw.githubusercontent.com/Selur/VapoursynthScriptsInHybrid/refs/heads/master/havsfunc_org.py

# Copy libraries installed with apt
RUN cd /usr/lib/x86_64-linux-gnu \
    && cp -P libboost_filesystem.so* libdav1d.so* libvpx.so* libxml2.so* /usr/local/lib

# Remove unecessary files from /usr/local/lib/
RUN cd /usr/local/lib \
    && rm -dr *.la *.a pkgconfig cmake

# ------------------------
# Finalize
# ------------------------

FROM nvidia/cuda@sha256:ebef3c171eeef0298e4eb2e4be843105edf3b8b0ac45e0b43acee358e8046867 AS final

# OpenCL integration (required for nnedi3cl)
RUN apt update && apt install -y --no-install-recommends pocl-opencl-icd

WORKDIR /vapoursynth

RUN mkdir assets plugins

# Dipendent libraries
COPY --from=build /usr/local/lib/ /usr/local/lib/

# Binaries
COPY --from=build /usr/local/bin/python3* /usr/local/bin/
COPY --from=build /usr/local/bin/vspipe /usr/local/bin/
COPY --from=build /usr/local/bin/trtexec /usr/local/bin/

# vsmlrt + vstrt
COPY --from=build /vsplugins/vs-mlrt/scripts/ /usr/local/lib/python3.12/site-packages/
COPY --from=build /vsplugins/vs-mlrt/vstrt/install/lib/libvstrt.so /usr/local/lib/vapoursynth/

# ffms2
COPY --from=build /vsplugins/ffms2/build/lib/libffms2.so* /usr/local/lib/vapoursynth/
COPY --from=build /vsplugins/ffms2/build/bin/ffmsindex /usr/local/bin/

# bestsource
COPY --from=build /vsplugins/bestsource/build/bestsource.so /usr/local/lib/vapoursynth/

# L-SMASH Source
COPY --from=build /vsplugins/L-SMASH-Works/build/liblsmashsource.*.so /usr/local/lib/vapoursynth/liblsmashsource.so

# vs-misc
COPY --from=build /vsplugins/vs-miscfilters-obsolete/build/libmiscfilters.so /usr/local/lib/vapoursynth/

# vapoursynth-mvtools
COPY --from=build /vsplugins/vapoursynth-mvtools/build/libmvtools.so /usr/local/lib/vapoursynth/

# nnedi3cl
COPY --from=build /vsplugins/VapourSynth-NNEDI3CL/build/libnnedi3cl.so /usr/local/lib/vapoursynth/
COPY --from=build /vsplugins/VapourSynth-NNEDI3CL/NNEDI3CL/nnedi3_weights.bin /usr/local/lib/vapoursynth/

# eedi3
COPY --from=build /vsplugins/VapourSynth-EEDI3/build/libeedi3m.so /usr/local/lib/vapoursynth/

# nnedi3
COPY --from=build /vsplugins/vapoursynth-nnedi3/build/lib/libnnedi3.so /usr/local/lib/vapoursynth/

# znedi3
COPY --from=build /vsplugins/znedi3/vsznedi3.so /usr/local/lib/vapoursynth/

# tivtc
COPY --from=build /vsplugins/vapoursynth-tivtc/build/libtivtc.so /usr/local/lib/vapoursynth/

# edgefixer
COPY --from=build /vsplugins/EdgeFixer/edgefixer.so /usr/local/lib/vapoursynth/

# vsutil
COPY --from=build /usr/local/lib/python3.12/site-packages/vsutil/ /usr/local/lib/python3.12/site-packages/vsutil/

# mvsfunc
COPY --from=build /usr/local/lib/python3.12/site-packages/mvsfunc/ /usr/local/lib/python3.12/site-packages/mvsfunc/

# havsfunc
COPY --from=build /vsplugins/havsfunc_org.py /usr/local/lib/python3.12/site-packages/havsfunc.py

# Set Vapoursynth libraries location
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PYTHONPATH="/usr/local/lib/python3.12/site-packages"
ENV PYTHONIOENCODING="utf-8"

# Add vapoursynth config to specify plugins location
RUN mkdir -p /root/.config/vapoursynth/ \
    && echo "UserPluginDir=/vapoursynth/plugins" > /root/.config/vapoursynth/vapoursynth.conf \
    && echo "SystemPluginDir=/usr/local/lib/vapoursynth" >> /root/.config/vapoursynth/vapoursynth.conf

COPY info.py ./
COPY nvidia_entrypoint.sh /opt/nvidia/

# nvidia_entrypoint.sh is executed by the base image
