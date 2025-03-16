# Build stage
FROM nvidia/cuda:12.2.0-devel-ubuntu22.04 as builder

# Update package list and install build dependencies
RUN apt-get update && \
    apt-get install -y build-essential cmake git wget python3-pip libyaml-cpp-dev

# Install Python dependencies and build yaml-cpp from source
RUN pip install numpy && \
    git clone https://github.com/jbeder/yaml-cpp.git && \
    cd yaml-cpp && mkdir build && cd build && \
    cmake .. && make -j4 && make install

# Set working directory and clone llama.cpp repository
WORKDIR /app

# Add CUDA stub library path for linking
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64/stubs:$LD_LIBRARY_PATH
ENV LIBRARY_PATH=/usr/local/cuda/lib64/stubs:$LIBRARY_PATH

# Build llama.cpp with CUDA support
RUN git clone https://github.com/ggerganov/llama.cpp && \
    cd llama.cpp && mkdir build && cd build && \
    cmake .. -DGGML_CUDA=ON && \
    make -j4

# Copy application source code and build the application
COPY . /app/src
WORKDIR /app/src/build
RUN cmake .. && cmake --build .

# Runtime stage
FROM nvidia/cuda:12.2.0-base-ubuntu22.04

# Update package list and install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends libstdc++6 libyaml-cpp0.7 && \
    rm -rf /var/lib/apt/lists/*

# Copy the built application and configuration files from the builder stage
COPY --from=builder /app/src/build/chatbot /app/chatbot
COPY --from=builder /app/src/config.yaml /app/
COPY --from=builder /app/llama.cpp/models/ggml-vocab.bin /app/models/

# Set the working directory
WORKDIR /app

# Expose the application port
EXPOSE 8080

# Command to run the application
CMD ["/app/chatbot"]