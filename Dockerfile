ARG PYTHON_VERSION=3.8.7
ARG DIST_VERSION=slim-buster
ARG ZLIB_VERSION=1.2.8
ARG HDF5_VERSION=1.8.13
ARG NETCDF4_VERSION=4.1.3
ARG PROJ_VERSION=7.2.1
ARG GDAL_VERSION=3.2.1
ARG GEOS_VERSION=3.9.0

FROM python:${PYTHON_VERSION}-${DIST_VERSION} AS base
LABEL maintainer="Sebastian Klatt <sebastian@markow.io>"
RUN apt-get update \
 && apt-get install --upgrade --no-install-recommends --yes \
    ca-certificates \
    libcurl3-gnutls \
    libcurl4 \
    libsqlite3-0 \
    libtiff5 \
    openssl \
 && rm -rf /var/lib/apt/lists/*

FROM base AS build
WORKDIR /src
RUN apt-get update \
 && apt-get install --upgrade --no-install-recommends --yes \
    automake \
    build-essential \
    git \
    ssh \
    cmake \
    libcurl4-gnutls-dev \
    libsqlite3-dev \
    libtiff5-dev \
    libtool \
    pkg-config \
    sqlite3 \
    wget \
 && rm -rf /var/lib/apt/lists/* \
 && pip3 install --upgrade --no-cache-dir wheel

FROM build AS libs
ARG ZLIB_VERSION
ARG HDF5_VERSION
ARG NETCDF4_VERSION
ARG PROJ_VERSION
ARG GDAL_VERSION
ARG GEOS_VERSION
WORKDIR /build
ENV TARGET_DIR /opt
ENV PATH "${TARGET_DIR}/bin:${PATH}"
ENV CPATH "${TARGET_DIR}/include:${CPATH}"
ENV LD_LIBRARY_PATH "${TARGET_DIR}/lib:${LD_LIBRARY_PATH}"
RUN mkdir -p ${TARGET_DIR}
RUN wget -q -c "ftp://ftp.unidata.ucar.edu/pub/netcdf/netcdf-4/zlib-${ZLIB_VERSION}.tar.gz" -O - \
    | tar xz \
 && cd "zlib-${ZLIB_VERSION}" \
 && export CFLAGS=-w CPPFLAGS=-w \
 && ./configure --prefix=${TARGET_DIR} \
 && make -j $(nproc) \
 && make install
RUN wget -q -c "ftp://ftp.unidata.ucar.edu/pub/netcdf/netcdf-4/hdf5-${HDF5_VERSION}.tar.gz" -O - \
    | tar xz \
 && cd "hdf5-${HDF5_VERSION}" \
 && export CFLAGS=-w CPPFLAGS=-w \
 && ./configure --prefix=${TARGET_DIR} --enable-hl --enable-shared \
 && make -j $(nproc) \
 && make install
RUN wget -q -c "http://www.unidata.ucar.edu/downloads/netcdf/ftp/netcdf-${NETCDF4_VERSION}.tar.gz" -O - \
    | tar xz \
 && cd "netcdf-${NETCDF4_VERSION}" \
 && export CFLAGS=-w CPPFLAGS=-w \
 && CPPFLAGS=-I${TARGET_DIR}/include LDFLAGS=-L${TARGET_DIR}/lib ./configure --prefix=${TARGET_DIR} --enable-netcdf-4 --enable-shared --enable-dap \
 && make -j $(nproc) \
 && make install
RUN wget -q -c "https://github.com/OSGeo/PROJ/releases/download/${PROJ_VERSION}/proj-${PROJ_VERSION}.tar.gz" -O - \
    | tar xz \
 && cd "proj-${PROJ_VERSION}" \
 && export CFLAGS=-w CPPFLAGS=-w \
 && ./configure --prefix=${TARGET_DIR} \
 && make -j $(nproc) \
 && make install
RUN wget -q -c "https://github.com/OSGeo/gdal/releases/download/v${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz" -O - \
    | tar xz \
 && cd "gdal-${GDAL_VERSION}" \
 && export CFLAGS=-w CPPFLAGS=-w \
 && CPPFLAGS=-I${TARGET_DIR}/include LDFLAGS=-L${TARGET_DIR}/lib ./configure --prefix=${TARGET_DIR} \
 && make -j $(nproc) \
 && make install
RUN wget -c "http://download.osgeo.org/geos/geos-${GEOS_VERSION}.tar.bz2" -O - \
    | tar xj \
 && cd "geos-${GEOS_VERSION}" \
 && export CFLAGS=-w CPPFLAGS=-w \
 && CPPFLAGS=-I/opt/include LDFLAGS=-L/opt/lib ./configure --prefix=${TARGET_DIR} \
 && make -j $(nproc) \
 && make  install
COPY requirements.txt /wheels/
RUN pip3 install --no-cache $(grep numpy /wheels/requirements.txt) \
 && pip3 wheel --find-links=/wheels --wheel-dir=/wheels --requirement /wheels/requirements.txt \
 && cd "/build/gdal-${GDAL_VERSION}" \
 && cd swig/python \
 && PATH="${TARGET_DIR}/bin:${PATH}" pip3 wheel --wheel-dir=/wheels . \
 && ls -lh /wheels

FROM base AS image
ARG PYTHON_VERSION
LABEL maintainer="Sebastian Klatt <sebastian@markow.io>"
LABEL image.python.version="${PYTHON_VERSION}"
COPY --from=libs /opt /opt
COPY --from=libs /wheels /wheels
ENV PATH "/opt/bin:${PATH}"
ENV CPATH "/opt/include:${CPATH}"
ENV LD_LIBRARY_PATH "/opt/lib:${LD_LIBRARY_PATH}"
RUN pip3 install --no-cache --find-links=/wheels --requirement /wheels/requirements.txt \
 && rm -rf /wheels \
 && python3 -c "import wradlib; print(wradlib.__version__)"
