# cmake_minimum_required(VERSION 3.15)
# project(chatbot LANGUAGES C CXX)

# set(CMAKE_CXX_STANDARD 20)
# set(CMAKE_CXX_STANDARD_REQUIRED ON)

# add_subdirectory(llama.cpp)

# find_package(yaml-cpp REQUIRED)

# list(APPEND CMAKE_PREFIX_PATH "/usr/local/lib/cmake/PrometheusCpp")
# list(APPEND CMAKE_PREFIX_PATH "/usr/local")

# find_package(PrometheusCpp REQUIRED COMPONENTS core pull)

# include(FetchContent)
# FetchContent_Declare(
#     crow
#     GIT_REPOSITORY https://github.com/CrowCpp/Crow.git
#     GIT_TAG v1.0+5
# )
# FetchContent_MakeAvailable(crow)

# add_executable(chatbot
#     src/chat.cpp
# )

# target_include_directories(chatbot PRIVATE
#     ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp
# )

# target_link_libraries(chatbot PRIVATE
#     llama
#     crow::crow
#     yaml-cpp
#     prometheus-cpp::core
#     prometheus-cpp::pull
#     pthread
#     ${CMAKE_DL_LIBS} #Dynamic loader library
# )

cmake_minimum_required(VERSION 3.15)
project(chatbot LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add llama.cpp
add_subdirectory(llama.cpp)

find_package(yaml-cpp REQUIRED)

# Crow setup
include(FetchContent)
FetchContent_Declare(
    crow
    GIT_REPOSITORY https://github.com/CrowCpp/Crow.git
    GIT_TAG v1.0+5
)
FetchContent_MakeAvailable(crow)

# Executable
add_executable(chatbot src/chat.cpp)

target_include_directories(chatbot PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp
)

target_link_libraries(chatbot PRIVATE
    llama
    Crow::Crow
    yaml-cpp
    pthread
)