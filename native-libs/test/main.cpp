#include <iostream>
#include <fstream>
#include <string>
#include <cstdlib>
#include <serial_bridge_index.hpp>
#include <string_tools.h>
#include <storages/portable_storage_template_helper.h>

// Files to be copied.
// epee/include/storages
// epee/include/file_io_utils.h

// ObjC
// create_blocks_request
// HTTP request
// serial_bridgeextract_utxos

void test_encode() {
    size_t length = 0;
    const char *body = serial_bridge::create_blocks_request(100, &length);

    for (size_t i = 0; i < length; i++) {
        std::cout << body[i];
    }

    std::cout << std::endl;

    std::free((void *)body);
}

void test_decode() {
    std::ifstream in("test/d.bin", std::ios::binary | std::ios::ate);
    if (!in) {
        std::cout << "No file\n";
        return;
    }

    int size = in.tellg();
    in.seekg(0, std::ios::beg);

    char *input = new char[size];
    in.read(input, size);

    int current_height = serial_bridge::extract_utxos_from_blocks_response(input, size);
    std::cout << "Current height: " << current_height << '\n';

    delete[] input;
}

int main() {
    test_decode();

    return 0;
}
