# # Build stage
# FROM nvidia/cuda:12.2.0-devel-ubuntu22.04 AS builder

# # Install build dependencies
# RUN apt-get update && \
#     apt-get install -y \
#     build-essential \
#     cmake \
#     git \
#     wget \
#     python3-pip \
#     libyaml-cpp-dev \
#     libcurl4-openssl-dev \
#     zlib1g-dev \
#     nlohmann-json3-dev && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# # Install Prometheus C++ client from source
# RUN git clone https://github.com/jupp0r/prometheus-cpp.git && \
#     cd prometheus-cpp && \
#     git submodule init && \
#     git submodule update && \
#     mkdir build && \
#     cd build && \
#     cmake .. \
#       -DBUILD_SHARED_LIBS=ON \
#       -DCMAKE_INSTALL_PREFIX=/usr/local \
#       -DENABLE_TESTING=OFF && \
#     make -j$(nproc) && \
#     make install && \
#     ldconfig

# # Install Python dependencies
# RUN pip install numpy

# # Set working directory
# WORKDIR /app

# # Configure CUDA stub libraries
# RUN ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1 && \
#     echo "/usr/local/cuda/lib64/stubs" > /etc/ld.so.conf.d/cuda-stubs.conf && \
#     ldconfig

# # Set environment variables for the build
# ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64/stubs:$LD_LIBRARY_PATH
# ENV LIBRARY_PATH=/usr/local/cuda/lib64/stubs:$LIBRARY_PATH
# ENV CMAKE_PREFIX_PATH=/usr/local/lib/cmake/PrometheusCpp:$CMAKE_PREFIX_PATH

# # Clone and build llama.cpp with CUDA support
# RUN git clone https://github.com/ggerganov/llama.cpp && \
#     cd llama.cpp && mkdir build && cd build && \
#     cmake .. -DGGML_CUDA=ON && \
#     make -j$(nproc)

# # Build your application
# COPY . /app/src
# WORKDIR /app/src/build
# RUN cmake .. && \
#     cmake --build . -- -j$(nproc)

# # Runtime stage
# FROM nvidia/cuda:12.2.0-base-ubuntu22.04

# # Install runtime dependencies
# RUN apt-get update && \
#     apt-get install -y --no-install-recommends \
#     libstdc++6 \
#     libyaml-cpp0.7 \
#     libcurl4 \
#     zlib1g && \
#     rm -rf /var/lib/apt/lists/*

# # Copy built artifacts from the builder stage
# COPY --from=builder /app/src/build/chatbot /app/chatbot
# COPY --from=builder /app/src/config.yaml /app/
# COPY --from=builder /app/llama.cpp/models/ggml-vocab.bin /app/models/
# COPY --from=builder /usr/local/lib/libprometheus-cpp* /usr/local/lib/

# # Final setup
# WORKDIR /app
# RUN ldconfig
# EXPOSE 8080
# CMD ["/app/chatbot"]

# Build stage
FROM nvidia/cuda:12.2.0-devel-ubuntu22.04 AS builder

# Install build dependencies
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    python3-pip \
    libyaml-cpp-dev \
    libcurl4-openssl-dev \
    zlib1g-dev \
    nlohmann-json3-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Prometheus C++ client from source
RUN git clone https://github.com/jupp0r/prometheus-cpp.git && \
    cd prometheus-cpp && \
    git submodule init && \
    git submodule update && \
    mkdir build && \
    cd build && \
    cmake .. \
      -DBUILD_SHARED_LIBS=ON \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DENABLE_TESTING=OFF && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# Install Python dependencies
RUN pip install numpy

# Set working directory
WORKDIR /app

# Configure CUDA stub libraries
RUN ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1 && \
    echo "/usr/local/cuda/lib64/stubs" > /etc/ld.so.conf.d/cuda-stubs.conf && \
    ldconfig

# Set environment variables for the build
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64/stubs:$LD_LIBRARY_PATH
ENV LIBRARY_PATH=/usr/local/cuda/lib64/stubs:$LIBRARY_PATH
ENV CMAKE_PREFIX_PATH=/usr/local/lib/cmake/PrometheusCpp:$CMAKE_PREFIX_PATH

# Clone and build llama.cpp with CUDA support
RUN git clone https://github.com/ggerganov/llama.cpp && \
    cd llama.cpp && mkdir build && cd build && \
    cmake .. -DGGML_CUDA=ON && \
    make -j$(nproc)

# Build your application
COPY . /app/src
WORKDIR /app/src/build
RUN cmake .. && \
    cmake --build . -- -j$(nproc)

# Runtime stage
FROM nvidia/cuda:12.2.0-base-ubuntu22.04

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libstdc++6 \
    libyaml-cpp0.7 \
    libcurl4 \
    zlib1g && \
    rm -rf /var/lib/apt/lists/*

# Copy built artifacts from the builder stage
COPY --from=builder /app/src/build/chatbot /app/chatbot
COPY --from=builder /app/src/config.yaml /app/
COPY --from=builder /app/llama.cpp/models/ggml-vocab.bin /app/models/
COPY --from=builder /usr/local/lib/libprometheus-cpp* /usr/local/lib/

# Final setup
WORKDIR /app
RUN ldconfig
EXPOSE 8080
CMD ["/app/chatbot"]