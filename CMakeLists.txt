cmake_minimum_required(VERSION 3.15)
project(chatbot LANGUAGES C CXX)

add_subdirectory(llama.cpp)

add_executable(chat src/chat.cpp)
target_link_libraries(chat PRIVATE llama)