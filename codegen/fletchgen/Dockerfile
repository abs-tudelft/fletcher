ARG ARROW_VERSION=0.10.0
FROM mbrobbel/libarrow:$ARROW_VERSION

LABEL fletcher=

ENV BUILD_PACKAGES make cmake g++ clang
ENV RUNTIME_PACKAGES boost-dev
ENV CXX clang++

WORKDIR fletchgen
ADD src src
ADD CMakeLists.txt .

WORKDIR build
RUN apk add --no-cache $BUILD_PACKAGES $RUNTIME_PACKAGES && \
    cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DENABLE_TESTS=OFF \
      .. && \
    make && make install && \
    cd ../.. && rm -rf fletchgen && \
    apk del $BUILD_PACKAGES

WORKDIR /
ENTRYPOINT ["fletchgen"]
