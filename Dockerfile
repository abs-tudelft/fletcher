ARG ARROW_VERSION=0.11.1
FROM mbrobbel/libarrow:$ARROW_VERSION

LABEL fletcher=

ENV BUILD_PACKAGES make cmake g++ libboost-all-dev
ENV RUNTIME_PACKAGES libboost-all-dev

WORKDIR fletcher
ADD . .

WORKDIR build
RUN apt-get update && \
    apt-get install -y $BUILD_PACKAGES && \
    cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DFLETCHER_GEN=1 \
      -DFLETCHER_TESTS=0 \
      -DFLETCHER_AWS=0 \
      -DFLETCHER_SNAP=0 \
      .. && \
    make && make install && \
    cd ../.. && rm -rf fletcher && \
    apt-get remove -y --purge $BUILD_PACKAGES && \
    apt-get install -y $RUNTIME_PACKAGES && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*
