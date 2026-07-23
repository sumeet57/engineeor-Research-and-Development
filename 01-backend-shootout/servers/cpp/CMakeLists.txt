cmake_minimum_required(VERSION 3.14)
project(backend_shootout)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_BUILD_TYPE Release)

find_package(OpenSSL REQUIRED)
find_package(ZLIB REQUIRED)

# Download Crow header
include(FetchContent)
FetchContent_Declare(
  crow
  GIT_REPOSITORY https://github.com/CrowCpp/Crow.git
  GIT_TAG v1.2.0
)
FetchContent_MakeAvailable(crow)

add_executable(server server.cpp)
target_link_libraries(server Crow::Crow OpenSSL::SSL OpenSSL::Crypto ZLIB::ZLIB pthread)
