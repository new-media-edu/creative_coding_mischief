cmake_minimum_required(VERSION 3.12)
project(aural-glossary-brain CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find OpenSSL
find_package(OpenSSL REQUIRED)

include_directories(
    .
    ${OPENSSL_INCLUDE_DIR}
    ../engine_a/whisper.cpp/examples/server
    ../engine_a/whisper.cpp/examples
)

add_executable(aural-glossary-brain brain.cpp)
target_link_libraries(aural-glossary-brain PRIVATE ${OPENSSL_LIBRARIES} pthread)

add_executable(test_brain test_brain.cpp)
target_link_libraries(test_brain PRIVATE ${OPENSSL_LIBRARIES} pthread)
