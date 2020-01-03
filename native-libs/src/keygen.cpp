#include "crypto/hmac_sha512.h"
#include <stdlib.h>
#include <boost/chrono.hpp>
#include <boost/algorithm/string.hpp>
#include <secp256k1.h>

int HARDENED_OFFSET = 0x80000000;
int LEN = 78;

class HDKey
{
private:
    std::string versions = "";
    int depth = 0;
    int index = 0;
    // int _fingerprint = 0;
    // int parentFingerprint = 0;
    unsigned char *_privateKey = NULL;
    unsigned char *_publicKey = NULL;
    unsigned char *chainCode = NULL;

public:
    HDKey(std::string versions)
    {
        this->versions = versions;
    }

    std::string getPrivateKey() {
        std::string out = (char *) _privateKey;
        return out;
    }

    HDKey(HDKey *hdkey)
    {
        this->versions = hdkey->versions;
        this->depth = hdkey->depth;
        this->index = hdkey->index;
        this->_privateKey = hdkey->_privateKey;
        this->_publicKey = hdkey->_publicKey;
        this->chainCode = hdkey->chainCode;
    }

    HDKey *derive(std::string path)
    {
        if (path == "m" || path == "M" || path == "m'" || path == "M'")
        {
            return this;
        }
        std::list<std::string> entries;
        boost::split(entries, path, boost::is_any_of("/"));

        HDKey *hdkey = this;

        bool first = true;
        for (const std::string &entry : entries)
        {
            if (first)
            {
                first = false;
                // todo assert
                continue;
            }
            bool hardened = entry.size() > 1 && &entry.back() == "'";
            int childIndex = std::stoi(entry);
            // todo assert
            if (hardened)
            {
                childIndex += HARDENED_OFFSET;
            }
            hdkey = hdkey->deriveChild(childIndex);
        }
        return hdkey;
    }

    HDKey *deriveChild(int childIndex)
    {
        bool isHardened = index >= HARDENED_OFFSET;
        char* indexBuffer = new char[4];
        strcpy(indexBuffer, std::to_string(index).c_str());

        std::string data;
        if (isHardened) {
            // todo assert
            data.assign((char *) _privateKey);
            char* zb = new char(0);
            data.append(zb);
            data.append(indexBuffer);

            // unsigned char *pk = (unsigned char*) calloc(strlen(_privateKey)+strlen(zb)+1, sizeof(unsigned char));
            // strcpy(pk, zb);
            // strcat(pk, _privateKey);
            // data = (unsigned char*) calloc(strlen(pk)+strlen(indexBuffer)+1, sizeof(unsigned char));;
            // strcpy(data, pk);
            // strcat(data, indexBuffer);
        }
        else {
            data.assign((char *) _publicKey);
            // // data = (std::string) _publicKey;
            data.append(indexBuffer);

            // data = (unsigned char*) calloc(strlen(_publicKey)+strlen(indexBuffer)+1, sizeof(unsigned char));
            // strcpy(data, _publicKey);
            // strcat(data, indexBuffer);
        }
        const unsigned char *data1 = (const unsigned char*) data.c_str();

        CHMAC_SHA512 *I = new CHMAC_SHA512(chainCode, 128);
        I = &I->Write(data1, strlen((const char *) data1));
        unsigned char hash[64];
        I->Finalize(hash);

        char *IL = new char[33];
        strncpy(IL, (const char*) hash, 32);
        IL[33] = '\0';
        char *IR = new char[33];
        strncpy(IR, (const char*) hash, 32); // todo use ther remainder of the hash
        IR[33] = '\0';


        HDKey *hd = new HDKey(versions);

        if (_privateKey) {
            secp256k1_context* ctx = secp256k1_context_create(SECP256K1_CONTEXT_NONE);
            unsigned char *pk = (unsigned char *) _privateKey;
            int out = secp256k1_ec_privkey_tweak_add(ctx, pk, (const unsigned char *) IL);
            if (out == 0) return this->deriveChild(index + 1);
            hd->_privateKey = pk;
        }
        else {
            secp256k1_context* ctx = secp256k1_context_create(SECP256K1_CONTEXT_NONE);
            secp256k1_pubkey pk = {(unsigned char) *_publicKey};
            int out = secp256k1_ec_pubkey_tweak_add(ctx, &pk, (const unsigned char *) IL);
            if (out == 0) return this->deriveChild(index + 1);
            hd->_publicKey = pk.data;
        }

        hd->chainCode = (unsigned char *) IR;
        hd->depth = depth + 1;
        // hd->parentFingerprint = fingerprint;
        hd->index = index;

        return hd;
    }

    static HDKey *fromMasterSeed(const unsigned char * seed, std::string versions) {
        const unsigned char *master_secret = (const unsigned char *) "Bitcoin seed";
        CHMAC_SHA512 *I = new CHMAC_SHA512(master_secret, (size_t) 128);
        I = &I->Write(seed, strlen((const char *) seed));
        unsigned char hash[64];
        I->Finalize(hash);

        char *IL = new char[33];
        strncpy(IL, (const char*) hash, 32);
        IL[33] = '\0';
        char *IR = new char[33];
        strncpy(IR, (const char*) hash+32, 32);
        IR[33] = '\0';

        HDKey *hd = new HDKey(versions);

        hd->chainCode = (unsigned char *) IR;
        hd->_privateKey = (unsigned char *) IL;

        return hd;
    }
};

// void BIP32Hash(const ChainCode &chainCode, unsigned int nChild, unsigned char header, const unsigned char data[32], unsigned char output[64])
// {
//     unsigned char num[4];
//     num[0] = (nChild >> 24) & 0xFF;
//     num[1] = (nChild >> 16) & 0xFF;
//     num[2] = (nChild >>  8) & 0xFF;
//     num[3] = (nChild >>  0) & 0xFF;
//     CHMAC_SHA512(chainCode.begin(), chainCode.size()).Write(&header, 1).Write(data, 32).Write(num, 4).Finalize(output);
// }


std::string fast_crypto_derive(std::string params)
{
    HDKey *hdkey = HDKey::fromMasterSeed((const unsigned char *) params.c_str(), "test");
    HDKey *derived;
    for (int i = 0; i < 20; i++) {
        derived = hdkey->derive("m/0/"+std::to_string(i));
    }
    // std::string out1 = hdkey.getPrivateKey();
    std::string out = "{\"pkey\": \" tested \"}";
    // std::string out = "{\"pkey\": \" test \"}";
    // std::string out = "test";
    return out;
    // return out;
}
