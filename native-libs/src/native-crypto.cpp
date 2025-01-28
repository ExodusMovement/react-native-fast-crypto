/*
 * Copyright (c) 2014, Airbitz, Inc.
 * All rights reserved.
 *
 * See the LICENSE file for more information.
 */

#include "native-crypto.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <serial_bridge_index.hpp>
#include <exception>

const char *create_blocks_request(int height, size_t *length) {
    return serial_bridge::create_blocks_request(height, length);
}

void extract_utxos_from_blocks_response(const char *buffer, size_t length, const char *szJsonParams, char **pszResult) {
    std::string strParams = szJsonParams;
    std::string result = serial_bridge::extract_data_from_blocks_response_str(buffer, length, strParams);

    int size = result.length() + 1;
    *pszResult = (char *) malloc(sizeof(char) * size);
    if (*pszResult == nullptr) {
        // Memory allocation failed
        return;
    }
    
    memcpy(*pszResult, result.c_str(), result.length() + 1);
}

void extract_utxos_from_clarity_blocks_response(const char *buffer, size_t length, const char *szJsonParams, char **pszResult) {
    std::string strParams = szJsonParams;
    std::string result = serial_bridge::extract_data_from_clarity_blocks_response_str(buffer, length, strParams);

    int size = result.length() + 1;
    *pszResult = (char *) malloc(sizeof(char) * size);
    
    if (*pszResult == nullptr) {
        // Memory allocation failed
        return;
    }
    
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
    if (*pszResult == nullptr) {
        // Memory allocation failed
        return;
    }
    
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
    if (*pszResult == nullptr) {
        // Memory allocation failed
        return;
    }

    memcpy(*pszResult, result.c_str(), result.length() + 1);
}

