#include <unistd.h>
#include <curl/curl.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <cstdlib>
#include <chrono>
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

void test_decompress(const std::string &filePath) {
    std::ifstream file(filePath, std::ios::binary | std::ios::ate);
    if (!file) {
        throw std::runtime_error("Failed to open file: " + filePath);
    }

    // Get file size
    size_t fileSize = file.tellg();
    file.seekg(0, std::ios::beg);

    // Read file into a buffer
    std::vector<char> buffer(fileSize);
    if (!file.read(buffer.data(), fileSize)) {
        throw std::runtime_error("Failed to read file: " + filePath);
    }

    // Check if the file is Gzip compressed
    bool isGzip = serial_bridge::is_gzip_compressed(buffer.data(), fileSize);
    std::cout << "File: " << filePath << " | Is Gzip Compressed: " << (isGzip ? "Yes" : "No") << '\n';

    // Process the content based on type
    std::string jsonData;
    if (isGzip) {
        try {
            jsonData = serial_bridge::decompress(buffer.data(), fileSize);
        } catch (const std::exception &e) {
            std::cerr << "Decompression failed for " << filePath << ": " << e.what() << '\n';
            return;
        }
        std::cout << "Decompressed JSON Length: " << jsonData.size() << '\n';
    } else {
        jsonData.assign(buffer.begin(), buffer.end());
        std::cout << "Plain JSON Length: " << jsonData.size() << '\n';
    }

    // Validate JSON format (basic check)
    assert(!jsonData.empty() && "JSON data should not be empty!");
    assert(jsonData.front() == '{' || jsonData.front() == '[' && "JSON must start with { or [");

    // Print a small portion of the JSON for validation
    std::cout << "JSON Preview: " << jsonData.substr(0, 200) << "...\n\n";
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
    CURL *curl = curl_easy_init();
    if (!curl) {
        std::cerr << "Failed to initialize CURL\n";
        return false;
    }

    CURLcode res;
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &buffer);

    res = curl_easy_perform(curl);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK) {
        std::cerr << "CURL error: " << curl_easy_strerror(res) << '\n';
        return false;
    }

    return true;
}

// Generic function to test JSON/Gzip processing
void test_full_flow_with_url_clarity(const std::string& url) {
    auto start_time = std::chrono::high_resolution_clock::now();
    std::vector<char> buffer;

    std::cout << "Start downloading file from: " << url << '\n';
    if (!downloadFile(url, buffer)) {
        std::cerr << "Failed to download file\n";
        return;
    }
    std::cout << "Download complete. File size: " << buffer.size() << " bytes\n";

    // Read input parameters from a file
    std::ifstream paramsFile("test/input/input.json");
    if (!paramsFile) {
        std::cerr << "Failed to open parameter file\n";
        return;
    }

    std::stringstream paramsStream;
    paramsStream << paramsFile.rdbuf();
    std::string params = paramsStream.str();

    // Pass the downloaded buffer directly to the function
    auto resp = serial_bridge::extract_data_from_clarity_blocks_response_str(buffer.data(), buffer.size(), params);

    std::cout << "Response: " << resp << '\n';

    auto end_time = std::chrono::high_resolution_clock::now(); // End timer
    std::chrono::duration<double> duration = end_time - start_time;
    std::cout << "Execution Time: " << duration.count() << " seconds\n";
}


int main() {
    test_encode();
    test_decode();

    std::cout << "Testing Gzip JSON File...\n";
    test_decompress("test/input/blocks.json.gzip");

    std::cout << "\nTesting Plain JSON File...\n";
    test_decompress("test/input/blocks.json");

    // test_decode_with_clarity();
    test_full_flow_with_url_clarity("https://xmr-proxy-d.a.exodus.io/v1/monero/get_blocks_file/3148308.json.gzip");
    test_full_flow_with_url_clarity("https://xmr-proxy-d.a.exodus.io/v1/monero/get_blocks_file/3148308.json");

    return 0;
}
