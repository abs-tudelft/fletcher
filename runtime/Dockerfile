ARG ARROW_VERSION=0.10.0
FROM mbrobbel/libarrow:$ARROW_VERSION

LABEL fletcher=

ENV BUILD_PACKAGES make cmake g++
ENV RUNTIME_PACKAGES boost-dev

WORKDIR runtime
ADD src src
ADD CMakeLists.txt .

WORKDIR build
RUN apk add --no-cache $BUILD_PACKAGES $RUNTIME_PACKAGES && \
    cmake \
      -DCMAKE_BUILD_TYPE=Release \
      .. && \
    make && make install && \
    cd ../.. && rm -rf runtime && \
    apk del $BUILD_PACKAGES
