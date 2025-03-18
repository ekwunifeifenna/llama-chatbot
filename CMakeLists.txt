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

# Add llama.cpp first
add_subdirectory(llama.cpp)

find_package(yaml-cpp REQUIRED)

# Modern Crow installation with proper target
include(FetchContent)
FetchContent_Declare(
    crow
    GIT_REPOSITORY https://github.com/CrowCpp/Crow.git
    GIT_TAG v1.0+5
    CMAKE_ARGS 
        -DCROW_BUILD_EXAMPLES=OFF 
        -DCROW_BUILD_TESTS=OFF
        -DCROW_AMALGAMATE=ON  # Reduces header includes
)
FetchContent_MakeAvailable(crow)

add_executable(chatbot
    src/chat.cpp
)

target_include_directories(chatbot PRIVATE
    # Only include llama.cpp if needed for direct header access
    ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp
)

target_link_libraries(chatbot PRIVATE
    llama
    Crow::Crow  # Modern namespace-style target
    yaml-cpp
    pthread
    # Boost is automatically handled by Crow's linking
)

# Add runtime library paths for CUDA stubs
set_target_properties(chatbot PROPERTIES
    INSTALL_RPATH "$ORIGIN/../lib"
    BUILD_WITH_INSTALL_RPATH TRUE
)