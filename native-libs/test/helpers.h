#include <string>
#include <vector>

#include <boost/variant/get.hpp>

#include <cryptonote_basic/tx_extra.h>

static crypto::public_key get_extra_pub_key(const std::vector<cryptonote::tx_extra_field> &fields) {
    for (size_t n = 0; n < fields.size(); ++n) {
        if (typeid(cryptonote::tx_extra_pub_key) == fields[n].type()) {
            return boost::get<cryptonote::tx_extra_pub_key>(fields[n]).pub_key;
        }
    }

    return crypto::public_key{};
}