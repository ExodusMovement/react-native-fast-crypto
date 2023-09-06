/*
 * Copyright (c) 2014, Airbitz, Inc.
 * All rights reserved.
 *
 * See the LICENSE file for more information.
 */

#include "native-crypto.h"
#include <secp256k1.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <serial_bridge_index.hpp>
#include <exception>

#define COMPRESSED_PUBKEY_LENGTH 33
#define DECOMPRESSED_PUBKEY_LENGTH 65
#define PRIVKEY_LENGTH 64

const char *create_blocks_request(int height, size_t *length) {
    return serial_bridge::create_blocks_request(height, length);
}

void extract_utxos_from_blocks_response(const char *buffer, size_t length, const char *szJsonParams, char **pszResult) {
    std::string strParams = szJsonParams;
    std::string result = serial_bridge::extract_data_from_blocks_response_str(buffer, length, strParams);

    int size = result.length() + 1;
    *pszResult = (char *) malloc(sizeof(char) * size);
    memcpy(*pszResult, result.c_str(), result.length() + 1);
}

void get_transaction_pool_hashes(const char *buffer, size_t length, char **pszResult) {
    std::string result;

    try {
        result = serial_bridge::get_transaction_pool_hashes_str(buffer, length);
    } catch (...) {
        result = "{\"err_msg\":\"mymonero-core-cpp threw an exception\"}";
    }

    int size = result.length() + 1;
    *pszResult = (char *) malloc(sizeof(char) * size);
    memcpy(*pszResult, result.c_str(), result.length() + 1);
}

void fast_crypto_monero_core(const char *szMethod, const char *szJsonParams, char **pszResult) {
    std::string strParams = szJsonParams;
    std::string method = szMethod;
    std::string result;

    try {
        if (method.compare("send_step1__prepare_params_for_get_decoys") == 0) {
            result = serial_bridge::send_step1__prepare_params_for_get_decoys(strParams);
        } else if (method.compare("pre_step2_tie_unspent_outs_to_mix_outs_for_all_future_tx_attempts") == 0) {
            result = serial_bridge::pre_step2_tie_unspent_outs_to_mix_outs_for_all_future_tx_attempts(strParams);
        } else if (method.compare("send_step2__try_create_transaction") == 0) {
            result = serial_bridge::send_step2__try_create_transaction(strParams);
        } else if (method.compare("decode_address") == 0) {
            result = serial_bridge::decode_address(strParams);
        } else if (method.compare("is_subaddress") == 0) {
            result = serial_bridge::is_subaddress(strParams);
        } else if (method.compare("is_integrated_address") == 0) {
            result = serial_bridge::is_integrated_address(strParams);
        } else if (method.compare("new_integrated_address") == 0) {
            result = serial_bridge::new_integrated_address(strParams);
        } else if (method.compare("new_payment_id") == 0) {
            result = serial_bridge::new_payment_id(strParams);
        } else if (method.compare("newly_created_wallet") == 0) {
            result = serial_bridge::newly_created_wallet(strParams);
        } else if (method.compare("are_equal_mnemonics") == 0) {
            result = serial_bridge::are_equal_mnemonics(strParams);
        } else if (method.compare("address_and_keys_from_seed") == 0) {
            result = serial_bridge::address_and_keys_from_seed(strParams);
        } else if (method.compare("mnemonic_from_seed") == 0) {
            result = serial_bridge::mnemonic_from_seed(strParams);
        } else if (method.compare("seed_and_keys_from_mnemonic") == 0) {
            result = serial_bridge::seed_and_keys_from_mnemonic(strParams);
        } else if (method.compare("validate_components_for_login") == 0) {
            result = serial_bridge::validate_components_for_login(strParams);
        } else if (method.compare("estimated_tx_network_fee") == 0) {
            result = serial_bridge::estimated_tx_network_fee(strParams);
        } else if (method.compare("generate_key_image") == 0) {
            result = serial_bridge::generate_key_image(strParams);
        } else if (method.compare("generate_key_derivation") == 0) {
            result = serial_bridge::generate_key_derivation(strParams);
        } else if (method.compare("derive_public_key") == 0) {
            result = serial_bridge::derive_public_key(strParams);
        } else if (method.compare("derive_subaddress_public_key") == 0) {
            result = serial_bridge::derive_subaddress_public_key(strParams);
        } else if (method.compare("decodeRct") == 0) {
            result = serial_bridge::decodeRct(strParams);
        } else if (method.compare("decodeRctSimple") == 0) {
            result = serial_bridge::decodeRctSimple(strParams);
        } else if (method.compare("derivation_to_scalar") == 0) {
            result = serial_bridge::derivation_to_scalar(strParams);
        } else if (method.compare("encrypt_payment_id") == 0) {
            result = serial_bridge::encrypt_payment_id(strParams);
        } else if (method.compare("extract_utxos") == 0) {
            result = serial_bridge::extract_utxos(strParams);
        } else {
            *pszResult = NULL;
            return;
        }
    } catch (std::exception &e) {
        std::string error_message;
        error_message.append("{\"err_msg\":\"mymonero-core-cpp threw an std::exception ");
        error_message.append(e.what());
        error_message.append("\"}");

        result = error_message;
    } catch (...) {
        result = "{\"err_msg\":\"mymonero-core-cpp threw an unknown type\"}";
    }
    int size = result.length() + 1;
    *pszResult = (char *) malloc(sizeof(char) * size);
    memcpy(*pszResult, result.c_str(), result.length() + 1);
}



void bytesToHex(uint8_t * in, int inlen, char * out)
{
    uint8_t * pin = in;
    const char * hex = "0123456789abcdef";
    char * pout = out;
    for(; pin < in+inlen; pout +=2, pin++){
        pout[0] = hex[(*pin>>4) & 0xF];
        pout[1] = hex[ *pin     & 0xF];
    }
    pout[0] = 0;
}

bool hexToBytes(const char * string, uint8_t *outBytes) {
    uint8_t *data = outBytes;

    if(string == NULL)
       return false;

    size_t slength = strlen(string);
    if(slength % 2 != 0) // must be even
       return false;

    size_t dlength = slength / 2;

    memset(data, 0, dlength);

    size_t index = 0;
    while (index < slength) {
        char c = string[index];
        int value = 0;
        if(c >= '0' && c <= '9')
            value = (c - '0');
        else if (c >= 'A' && c <= 'F')
            value = (10 + (c - 'A'));
        else if (c >= 'a' && c <= 'f')
             value = (10 + (c - 'a'));
        else
            return false;

        data[(index/2)] += value << (((index + 1) % 2) * 4);

        index++;
    }

    return true;
}

secp256k1_context *secp256k1ctx = NULL;

// Must pass a privateKey of length 64 bytes
void fast_crypto_secp256k1_ec_pubkey_create(const char *szPrivateKeyHex, char *szPublicKeyHex, int compressed)
{
    if (secp256k1ctx == NULL) {
        secp256k1ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY);
    }

    int flags = compressed ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED;
    uint8_t privateKey[PRIVKEY_LENGTH];
    szPublicKeyHex[0] = 0;

    bool success = hexToBytes(szPrivateKeyHex, privateKey);
    if (!success) {
        return;
    }

    secp256k1_pubkey public_key;
    if (secp256k1_ec_pubkey_create(secp256k1ctx, &public_key, privateKey) == 0) {
        return;
    }

    unsigned char output[DECOMPRESSED_PUBKEY_LENGTH];
    size_t output_length = DECOMPRESSED_PUBKEY_LENGTH;
    secp256k1_ec_pubkey_serialize(secp256k1ctx, &output[0], &output_length, &public_key, flags);
    bytesToHex(output, output_length, szPublicKeyHex);
}

// secp256k1_pubkey public_key;

void fast_crypto_secp256k1_ec_privkey_tweak_add(char *szPrivateKeyHex, const char *szTweak) {
    if (secp256k1ctx == NULL) {
        secp256k1ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY);
    }

    int privateKeyLen = strlen(szPrivateKeyHex) / 2;
    unsigned char privateKey[DECOMPRESSED_PUBKEY_LENGTH];
    unsigned char tweak[DECOMPRESSED_PUBKEY_LENGTH];

    bool success = hexToBytes(szPrivateKeyHex, privateKey);
    if (!success) {
        return;
    }
    success = hexToBytes(szTweak, tweak);
    if (!success) {
        return;
    }
    if (secp256k1_ec_privkey_tweak_add(secp256k1ctx, privateKey, (unsigned char *) tweak) == 1) {
        bytesToHex((uint8_t *)privateKey, privateKeyLen, szPrivateKeyHex);
    }
}

void fast_crypto_secp256k1_ec_pubkey_tweak_add(char *szPublicKeyHex, const char *szTweak, int compressed) {
    if (compressed != 1) {
        szPublicKeyHex[0] = 0;
        return;
    }

    if (secp256k1ctx == NULL) {
        secp256k1ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY);
    }

    int flags = compressed ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED;
    int publicKeyLen = compressed ? COMPRESSED_PUBKEY_LENGTH : DECOMPRESSED_PUBKEY_LENGTH;

    unsigned char publicKey[DECOMPRESSED_PUBKEY_LENGTH];
    unsigned char tweak[DECOMPRESSED_PUBKEY_LENGTH];

    bool success = hexToBytes(szPublicKeyHex, publicKey);
    if (!success) {
        szPublicKeyHex[0] = 0;
        return;
    }

    success = hexToBytes(szTweak, tweak);
    if (!success) {
        szPublicKeyHex[0] = 0;
        return;
    }

    secp256k1_pubkey public_key;
    if (secp256k1_ec_pubkey_parse(secp256k1ctx, &public_key, publicKey, publicKeyLen) == 0) {
        szPublicKeyHex[0] = 0;
        return;
    }

    if (secp256k1_ec_pubkey_tweak_add(secp256k1ctx, &public_key, tweak) == 0) {
        szPublicKeyHex[0] = 0;
        return;
    }

    unsigned char output[DECOMPRESSED_PUBKEY_LENGTH];
    size_t output_length = DECOMPRESSED_PUBKEY_LENGTH;
    secp256k1_ec_pubkey_serialize(secp256k1ctx, &output[0], &output_length, &public_key, flags);
    bytesToHex((uint8_t *)output, output_length, szPublicKeyHex);
}

