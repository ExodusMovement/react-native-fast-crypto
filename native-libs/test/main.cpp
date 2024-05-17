#include <unistd.h>
#include <curl/curl.h>
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

    std::ofstream out("test/output/req.bin", std::ios::binary);
    out.write(body, length);

    out.close();

    std::free((void *)body);
}

void test_decode() {
    std::ifstream in("test/input/d.bin", std::ios::binary | std::ios::ate);
    if (!in) {
        std::cout << "No file\n";
        return;
    }

    int size = in.tellg();
    in.seekg(0, std::ios::beg);
    char *input = new char[size];
    in.read(input, size);
    std::string m_body(input, size);

    std::ifstream paramsFile("test/input/input.json");
    std::stringstream paramsStream;
    paramsStream << paramsFile.rdbuf();
    std::string params = paramsStream.str();

    auto resp = serial_bridge::extract_data_from_blocks_response_str(input, size, params);
    std::cout << resp << '\n';

    delete[] input;
}

void test_decompress() {
    std::ifstream file("test/input/blocks.json.gzip", std::ios::binary | std::ios::ate);
    if (!file) {
        throw std::runtime_error("Failed to open file");
    }

    file.seekg(0, std::ios::end);
    size_t fileSize = file.tellg();
    file.seekg(0, std::ios::beg);

    // Read the file into a vector<char>
    char *buffer = new char[fileSize];
    if (!file.read(buffer, fileSize)) {
        throw std::runtime_error("Failed to read file");
    }

    size_t length = 0;
    std::string decompressedData = serial_bridge::decompress(buffer, fileSize);

    delete[] buffer;
}

void test_decode_with_clarity() {
    std::ifstream file("test/input/blocks.json.gzip", std::ios::binary | std::ios::ate);
    if (!file) {
        throw std::runtime_error("Failed to open file");
    }

    file.seekg(0, std::ios::end);
    size_t fileSize = file.tellg();
    file.seekg(0, std::ios::beg);

    // Read the file into a vector<char>
    char *buffer = new char[fileSize];
    if (!file.read(buffer, fileSize)) {
        throw std::runtime_error("Failed to read file");
    }

    std::ifstream paramsFile("test/input.json");
    std::stringstream paramsStream;
    paramsStream << paramsFile.rdbuf();
    std::string params = paramsStream.str();

    auto resp = serial_bridge::extract_data_from_clarity_blocks_response_str(buffer, fileSize, params);
    std::cout << resp << '\n';

    delete[] buffer;
}

static size_t WriteCallback(void *contents, size_t size, size_t nmemb, void *userp) {
    std::vector<char>* buffer = (std::vector<char>*)userp;
    const char* data = (const char*)contents;
    buffer->insert(buffer->end(), data, data + size * nmemb);  // Append data to vector
    return size * nmemb;
}

bool downloadFile(const std::string& url, std::vector<char>& buffer) {
    CURL *curl;
    CURLcode res;
    curl = curl_easy_init();
    if (curl) {
        curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &buffer);
        res = curl_easy_perform(curl);
        curl_easy_cleanup(curl);
        return (res == CURLE_OK);
    }
    curl_easy_cleanup(curl);  // Clean up even if curl_easy_init fails
    return false;
}

void test_full_flow_with_clarity() {
    std::string url = "https://xmr-proxy-d.a.exodus.io/v1/monero/get_blocks_file/3148308.json.gzip"; 
    std::vector<char> buffer;

    downloadFile(url, buffer);
    if (!downloadFile(url, buffer)) {
        std::cerr << "Failed to download file\n";
        return;
    }

    std::ifstream paramsFile("test/input/input.json");
    if (!paramsFile) {
        std::cerr << "Failed to open parameter file\n";
        return;
    }

    std::stringstream paramsStream;
    paramsStream << paramsFile.rdbuf();
    std::string params = paramsStream.str();

    auto resp = serial_bridge::extract_data_from_clarity_blocks_response_str(buffer.data(), buffer.size(), params);
    std::cout << resp << '\n';
    return;
}

int main() {
    test_encode();
    test_decode();
    test_decompress();
    // test_decode_with_clarity();
    test_full_flow_with_clarity();

    return 0;
}
