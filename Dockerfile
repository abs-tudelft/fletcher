ARG ARROW_VERSION=0.13.0
FROM mbrobbel/libarrow:$ARROW_VERSION

LABEL fletcher=

ENV BUILD_PACKAGES cmake g++ git

WORKDIR fletcher
ADD . .

WORKDIR build
RUN apt-get update && \
    apt-get install -y $BUILD_PACKAGES && \
    cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DFLETCHER_GEN=1 \
      -DFLETCHER_TESTS=0 \
      .. && \
    make && make install && \
    cd ../.. && rm -rf fletcher && \
    apt-get remove -y --purge $BUILD_PACKAGES && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /
ENTRYPOINT ["fletchgen"]
