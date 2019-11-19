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
    std::string m_body = serial_bridge::create_blocks_request(100);

    std::cout << m_body << std::endl;

    return 0;
}
