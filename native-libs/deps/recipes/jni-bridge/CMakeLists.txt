# Sets the minimum version of CMake required to build your native library.
# This ensures that a certain set of CMake features is available to
# your build.

cmake_minimum_required(VERSION 3.4.1)

add_library(crypto_bridge SHARED
            crypto_bridge.cpp)

add_library(nativecrypto
             SHARED
             IMPORTED)

set_target_properties(nativecrypto
                       PROPERTIES IMPORTED_LOCATION
                       ${INSTALL_DIR}/lib/libnativecrypto.so)

# Include libraries needed for crypto_bridge lib
target_link_libraries(crypto_bridge nativecrypto android log)

