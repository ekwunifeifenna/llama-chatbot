# # Full working Dockerfile with CUDA + CURL fix
# FROM nvidia/cuda:12.2.0-devel-ubuntu22.04

# # 1. Base dependencies
# RUN apt-get update && \
#     apt-get install -y --no-install-recommends \
#     build-essential \
#     cmake \
#     git \
#     wget \
#     python3-pip \
#     libyaml-cpp-dev \
#     zlib1g-dev \
#     libboost-dev \
#     libboost-system-dev \
#     libboost-date-time-dev \
#     nlohmann-json3-dev \
#     libcurl4-openssl-dev \  
#     libssl-dev \            
#     && rm -rf /var/lib/apt/lists/*

# # 2. Configure CUDA environment
# RUN ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1 && \
#     echo "/usr/local/cuda/lib64/stubs" > /etc/ld.so.conf.d/cuda-stubs.conf && \
#     ldconfig

# # 3. Build llama.cpp with specific CUDA arch
# RUN git clone https://github.com/ggerganov/llama.cpp && \
#     cd llama.cpp && \
#     mkdir build && cd build && \
#     cmake .. \
#         -DGGML_CUDA=ON \
#         -DLLAMA_CURL=OFF \           
#         -DCMAKE_CUDA_ARCHITECTURES=75 \  
#     && make -j$(nproc)

# # 4. Application setup
# WORKDIR /app
# COPY . .

# # 5. Build application
# RUN mkdir -p build && \
#     cd build && \
#     cmake .. && \
#     cmake --build . -- -j$(nproc)

# # 6. Runtime configuration
# EXPOSE 8080
# CMD ["/app/build/chatbot"]

# Dockerfile for Render.com free tier (CPU-only)
FROM ubuntu:22.04

# 1. Install base dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    wget \
    python3-pip \
    libyaml-cpp-dev \
    zlib1g-dev \
    libboost-dev \
    libboost-system-dev \
    libboost-date-time-dev \
    nlohmann-json3-dev \
    libcurl4-openssl-dev \  
    && rm -rf /var/lib/apt/lists/*

# 2. Build llama.cpp with CPU optimizations
RUN git clone https://github.com/ggerganov/llama.cpp && \
    cd llama.cpp && \
    mkdir build && cd build && \
    cmake .. \
        -DLLAMA_CPU=ON \
        -DLLAMA_CURL=OFF \  
        -DCMAKE_BUILD_TYPE=Release \  
    && make -j4

# 3. Download small model (TinyLlama ~500MB)
RUN mkdir -p /app/models && \
    wget -O /app/models/tinyllama.gguf \
    "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"

# 4. Application setup
WORKDIR /app
COPY . .

# 5. Build application with Release config
RUN mkdir -p build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    cmake --build . -- -j4

# 6. Install Python dependencies for ngrok (optional)
RUN pip install pyngrok

# 7. Runtime configuration
EXPOSE 8080
CMD ["./build/chatbot"]