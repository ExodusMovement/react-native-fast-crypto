#include <iostream>
#include <string>
#include <serial_bridge_index.hpp>
#include <string_tools.h>

// Files to be copied.
// epee/include/storages
// epee/include/file_io_utils.h

// ObjC
// create_blocks_request
// HTTP request
// serial_bridgeextract_utxos


int main() {
    size_t length = 0;
    const char *body = serial_bridge::create_blocks_request(100, &length);

    for (size_t i = 0; i < length; i++) {
        std::cout << body[i];
    }

    std::cout << std::endl;

    return 0;
}
