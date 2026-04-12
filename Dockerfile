# ── Stage 1: build the toolchain ─────────────────────────────────────────────
FROM debian:bookworm-slim AS builder

ARG BINUTILS_VERSION=2.41
ARG GCC_VERSION=12.3.0
ARG NEWLIB_VERSION=4.3.0.20230120
ARG TARGET=arm-none-eabi
ARG PREFIX=/opt/arm-none-eabi-be

ENV PATH="${PREFIX}/bin:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        wget \
        ca-certificates \
        xz-utils \
        python3 \
        texinfo \
        bison \
        flex \
        gawk \
        libgmp-dev \
        libmpc-dev \
        libmpfr-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN wget -q \
        https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz \
        https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz \
        https://sourceware.org/pub/newlib/newlib-${NEWLIB_VERSION}.tar.gz \
    && tar xf binutils-${BINUTILS_VERSION}.tar.xz \
    && tar xf gcc-${GCC_VERSION}.tar.xz \
    && tar xf newlib-${NEWLIB_VERSION}.tar.gz

RUN ln -s /build/newlib-${NEWLIB_VERSION}/newlib  gcc-${GCC_VERSION}/newlib \
    && ln -s /build/newlib-${NEWLIB_VERSION}/libgloss gcc-${GCC_VERSION}/libgloss

# ── binutils ──────────────────────────────────────────────────────────────────
RUN mkdir build-binutils && cd build-binutils \
    && ../binutils-${BINUTILS_VERSION}/configure \
        --target=${TARGET} \
        --prefix=${PREFIX} \
        --with-sysroot \
        --disable-multilib \
        --disable-nls \
        --disable-werror \
    && make -j$(nproc) \
    && make install

# ── GCC stage 1 ───────────────────────────────────────────────────────────────
RUN mkdir build-gcc && cd build-gcc \
    && ../gcc-${GCC_VERSION}/configure \
        --target=${TARGET} \
        --prefix=${PREFIX} \
        --with-newlib \
        --without-headers \
        --with-gmp=/usr --with-mpfr=/usr --with-mpc=/usr \
        --disable-multilib \
        --disable-shared \
        --disable-threads \
        --disable-nls \
        --disable-libssp \
        --disable-libgomp \
        --disable-libatomic \
        --disable-libquadmath \
        --enable-languages=c \
        --with-cpu=cortex-r4 \
        --with-fpu=vfpv3-d16 \
        --with-float=hard \
        --with-mode=arm \
    && make -j$(nproc) \
        CFLAGS_FOR_TARGET="-mbig-endian -mcpu=cortex-r4 -mfpu=vfpv3-d16 -mfloat-abi=hard -marm" \
        all-gcc all-target-libgcc \
    && make install-gcc install-target-libgcc

# ── newlib ────────────────────────────────────────────────────────────────────
RUN mkdir build-newlib && cd build-newlib \
    && ../newlib-${NEWLIB_VERSION}/configure \
        --target=${TARGET} \
        --prefix=${PREFIX} \
        --disable-multilib \
        --disable-newlib-supplied-syscalls \
        --enable-newlib-reent-small \
        --enable-newlib-nano-formatted-io \
        --disable-nls \
    && make -j$(nproc) \
        CFLAGS_FOR_TARGET="-mbig-endian -mcpu=cortex-r4 -mfpu=vfpv3-d16 -mfloat-abi=hard -marm" \
    && make install

# ── Stage 2: slim final image ─────────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
	make \
	libmpc3 \
	libmpfr6 \
	libgmp10 \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/arm-none-eabi-be /opt/arm-none-eabi-be

ENV PATH=/opt/arm-none-eabi-be/bin:$PATH

WORKDIR /project
CMD ["/bin/bash"]
