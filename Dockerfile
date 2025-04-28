# FROM ubuntu:22.04

# # 1. Install base dependencies
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
#     && rm -rf /var/lib/apt/lists/*

# # 2. Build llama.cpp with CPU optimizations
# RUN git clone https://github.com/ggerganov/llama.cpp && \
#     cd llama.cpp && \
#     mkdir build && cd build && \
#     cmake .. \
#         -DLLAMA_CPU=ON \
#         -DLLAMA_CURL=OFF \  
#         -DCMAKE_BUILD_TYPE=Release \  
#     && make -j4

# # 3. Download small model (TinyLlama ~500MB)
# RUN mkdir -p /app/models && \
#     wget -O /app/models/tinyllama.gguf \
#     "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"

# # 4. Application setup
# WORKDIR /app
# COPY . .

# # 5. Build application with Release config
# RUN mkdir -p build && \
#     cd build && \
#     cmake -DCMAKE_BUILD_TYPE=Release .. && \
#     cmake --build . -- -j4

# # 6. Install Python dependencies for ngrok (optional)
# RUN pip install pyngrok

# # 7. Runtime configuration
# EXPOSE 8080
# CMD ["./build/chatbot"]

FROM ubuntu:22.04

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

# Use specific llama.cpp commit
RUN git clone https://github.com/ggerganov/llama.cpp && \
    cd llama.cpp && \
    git checkout b2440d9 && \
    mkdir build && cd build && \
    cmake .. \
        -DLLAMA_CURL=OFF \
        -DLLAMA_METAL=OFF \
        -DCMAKE_BUILD_TYPE=Release \
    && make -j4

RUN pip install pyngrok

WORKDIR /app
COPY . .

RUN mkdir -p build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    cmake --build . -- -j4 && \
    strip -s chatbot

EXPOSE 8080
CMD ["./build/chatbot"]