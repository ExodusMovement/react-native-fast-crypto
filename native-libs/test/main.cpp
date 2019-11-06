#include <iostream>
#include <string>
#include <serial_bridge_index.hpp>

int main() {
    std::string decoded = serial_bridge::do_http_request("");

    std::cout << decoded << std::endl;
    return 0;
}
