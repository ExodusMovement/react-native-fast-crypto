#include <stdlib.h>
#include <boost/chrono.hpp>

std::string fast_crypto_derive(std::string params);

class HDKey
{
private:
  std::string versions;
  int depth;
  int index;
  // int _fingerprint = 0;
  // int parentFingerprint = 0;
  unsigned char *_privateKey;
  unsigned char *_publicKey;
  unsigned char *chainCode;

public:
  HDKey(std::string versions);
  std::string getPrivateKey();
  HDKey *derive(std::string path);
  HDKey *deriveChild(int childIndex);
  static HDKey *fromMasterSeed(const unsigned char * seed, std::string versions);
};