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

void test_decompress() {
    std::ifstream file("test/blocks.json.gzip", std::ios::binary | std::ios::ate);
    if (!file) {
        throw std::runtime_error("Failed to open file");
    }

    file.seekg(0, std::ios::end);
    size_t fileSize = file.tellg();
    file.seekg(0, std::ios::beg);

    // Read the file into a vector<char>
    std::vector<char> buffer(fileSize);
    if (!file.read(buffer.data(), fileSize)) {
        throw std::runtime_error("Failed to read file");
    }

    size_t length = 0;
    std::string decompressedData = serial_bridge::decompress(buffer.data(), buffer.size());
    std::cout << "Decompressed data: " << decompressedData << std::endl;
}

void test_decode_with_clarity() {
    std::ifstream file("test/blocks.json.gzip", std::ios::binary | std::ios::ate);
    if (!file) {
        throw std::runtime_error("Failed to open file");
    }

    file.seekg(0, std::ios::end);
    size_t fileSize = file.tellg();
    file.seekg(0, std::ios::beg);

    // Read the file into a vector<char>
    std::vector<char> buffer(fileSize);
    if (!file.read(buffer.data(), fileSize)) {
        throw std::runtime_error("Failed to read file");
    }

    std::ifstream paramsFile("test/input.json");
    std::stringstream paramsStream;
    paramsStream << paramsFile.rdbuf();
    std::string params = paramsStream.str();

    auto resp = serial_bridge::extract_data_from_clarity_blocks_response_str(buffer.data(), buffer.size(), params);
    std::cout << resp << '\n';
}

int main() {
    test_encode();
    // test_decode();
    // test_decompress();
    test_decode_with_clarity();

    return 0;
}
