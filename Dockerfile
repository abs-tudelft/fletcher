ARG ARROW_VERSION=0.11.1
FROM mbrobbel/libarrow:$ARROW_VERSION

LABEL fletcher=

ARG AWS_FPGA_VERSION=1.4.2

ENV BUILD_PACKAGES git make cmake g++

WORKDIR fletcher
ADD . .

WORKDIR build
SHELL ["/bin/bash", "-c"]
RUN apt-get update && \
    apt-get install -y $BUILD_PACKAGES && \
    # setup aws-fpga
    git clone \
      --single-branch \
      --depth 1 \
      --branch v$AWS_FPGA_VERSION \
      https://github.com/aws/aws-fpga && \
    pushd aws-fpga && \
    source sdk_setup.sh && \
    popd && \
    # build fletcher
    cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DFLETCHER_GEN=1 \
      -DFLETCHER_TESTS=1 \
      -DFLETCHER_AWS=1 \
      -DFLETCHER_SNAP=0 \
      .. && \
    make && make test && make install && \
    cd ../.. && rm -rf fletcher && \
    apt-get remove -y --purge $BUILD_PACKAGES && \
    apt-get install -y $RUNTIME_PACKAGES && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /
ENTRYPOINT ["fletchgen"]
