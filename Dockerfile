# Build stage
FROM nvidia/cuda:12.2.0-devel-ubuntu22.04 as builder

# Install build dependencies including Prometheus client
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    python3-pip \
    libyaml-cpp-dev \
    libprometheus-cpp-dev  # Development headers

# Install Python dependencies
RUN pip install numpy

# Set working directory
WORKDIR /app

# Configure CUDA stub libraries
RUN ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1 && \
    echo "/usr/local/cuda/lib64/stubs" > /etc/ld.so.conf.d/cuda-stubs.conf && \
    ldconfig

# Build environment variables
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64/stubs:$LD_LIBRARY_PATH
ENV LIBRARY_PATH=/usr/local/cuda/lib64/stubs:$LIBRARY_PATH

# Clone and build llama.cpp with CUDA support
RUN git clone https://github.com/ggerganov/llama.cpp && \
    cd llama.cpp && mkdir build && cd build && \
    cmake .. -DGGML_CUDA=ON && \
    make -j4

# Build your application
COPY . /app/src
WORKDIR /app/src/build
RUN cmake .. && cmake --build .

# Runtime stage
FROM nvidia/cuda:12.2.0-base-ubuntu22.04

# Install runtime dependencies (CORRECTED PACKAGE NAME)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libstdc++6 \
    libyaml-cpp0.7 \
    libprometheus-cpp0.13-0 &&\
    rm -rf /var/lib/apt/lists/*

# Copy built artifacts
COPY --from=builder /app/src/build/chatbot /app/chatbot
COPY --from=builder /app/src/config.yaml /app/
COPY --from=builder /app/llama.cpp/models/ggml-vocab.bin /app/models/

# Final setup
WORKDIR /app
EXPOSE 8080
CMD ["/app/chatbot"]