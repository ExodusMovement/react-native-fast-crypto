#include <string>
#include <vector>

#include <boost/variant/get.hpp>

#include <serial_bridge_index.hpp>
#include <cryptonote_basic/cryptonote_basic.h>
#include <cryptonote_basic/tx_extra.h>

static crypto::public_key get_extra_pub_key(const std::vector<cryptonote::tx_extra_field> &fields) {
    for (size_t n = 0; n < fields.size(); ++n) {
        if (typeid(cryptonote::tx_extra_pub_key) == fields[n].type()) {
            return boost::get<cryptonote::tx_extra_pub_key>(fields[n]).pub_key;
        }
    }

    return crypto::public_key{};
}

std::vector<serial_bridge::Output> get_utxos(const cryptonote::transaction &tx) {
    std::vector<serial_bridge::Output> outputs;

    for (size_t i = 0; i < tx.vout.size(); i++) {
        auto tx_out = tx.vout[i];

        if (tx_out.target.type() != typeid(cryptonote::txout_to_key)) continue;
        auto target = boost::get<cryptonote::txout_to_key>(tx_out.target);

        serial_bridge::Output output;
        output.index = i;
        output.pub = target.key;
        output.amount = std::to_string(tx_out.amount);

        outputs.push_back(output);
    }

    return outputs;
}
