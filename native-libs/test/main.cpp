#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <cstdlib>
#include <serial_bridge_index.hpp>
#include <storages/portable_storage_template_helper.h>
#include <cryptonote_basic/cryptonote_format_utils.h>
#include "helpers.h"

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

    std::string m_body(input, size);
    delete[] input;

    cryptonote::COMMAND_RPC_GET_BLOCKS_FAST::response resp;
    epee::serialization::load_t_from_binary(resp, m_body);

    auto blocks = resp.blocks;

    cryptonote::block b;
    cryptonote::transaction tx;
    for (auto &block_entry : resp.blocks) {
        crypto::hash block_hash;
        if (!parse_and_validate_block_from_blob(block_entry.block, b, block_hash)) {
            continue;
        }

        auto gen_tx = b.miner_tx.vin[0];
        if (gen_tx.type() != typeid(cryptonote::txin_gen)) {
            continue;
        }

        int height = boost::get<cryptonote::txin_gen>(gen_tx).height;
        std::cout << "Height: " << height << '\n';

        for (size_t i = 0; i < block_entry.txs.size(); i++) {
            auto tx_entry = block_entry.txs[i];

            bool tx_parsed = cryptonote::parse_and_validate_tx_from_blob(tx_entry.blob, tx) || cryptonote::parse_and_validate_tx_base_from_blob(tx_entry.blob, tx);
            if (!tx_parsed) continue;

            std::vector<cryptonote::tx_extra_field> fields;
            bool extra_parsed = cryptonote::parse_tx_extra(tx.extra, fields);
            if (!extra_parsed) continue;

            serial_bridge::Transaction bridge_tx;
            bridge_tx.id = epee::string_tools::pod_to_hex(b.tx_hashes[i]);
            bridge_tx.pub = get_extra_pub_key(fields);
            bridge_tx.version = tx.version;
            bridge_tx.rv = tx.rct_signatures;
            bridge_tx.outputs = get_utxos(tx);
        }
    }
}

int main() {
    test_decode();

    return 0;
}
