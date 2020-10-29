#include <unistd.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <cstdlib>
#include <serial_bridge_index.hpp>
#include <storages/portable_storage_template_helper.h>
#include <cryptonote_basic/cryptonote_format_utils.h>
#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/json_parser.hpp>

void test_encode() {
    size_t length = 0;
    const char *body = serial_bridge::create_blocks_request(1573230, &length);

    std::ofstream out("test/req.bin", std::ios::binary);
    out.write(body, length);

    out.close();

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
    std::string m_body(input, size);

    std::ifstream paramsFile("test/input.json");
    std::stringstream paramsStream;
    paramsStream << paramsFile.rdbuf();
    std::string params = paramsStream.str();

    auto resp = serial_bridge::extract_data_from_blocks_response_str(input, size, params);
    std::cout << resp << '\n';

    delete[] input;
}

int main() {
    test_decode();

    return 0;
}
