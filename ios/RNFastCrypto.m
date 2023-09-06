
#import "RNFastCrypto.h"
#import "native-crypto.h"
#import "NSArray+Map.h"
#import <Foundation/Foundation.h>

#include <stdbool.h>
#include <stdint.h>

@implementation RNFastCrypto

- (dispatch_queue_t)methodQueue
{
    dispatch_queue_attr_t qosAttribute = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_BACKGROUND, 0);
    return dispatch_queue_create("io.exodus.RNFastCrypto.MainQueue", qosAttribute);
}

+ (void) handleGetTransactionPoolHashes:(NSString*) method
                                       :(NSString*) params
                                       :(RCTPromiseResolveBlock) resolve
                                       :(RCTPromiseRejectBlock) reject {
    NSData *paramsData = [params dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError;
    NSDictionary *jsonParams = [NSJSONSerialization JSONObjectWithData:paramsData options:kNilOptions error:&jsonError];

    NSString *addr = jsonParams[@"url"];
    NSURL *url = [NSURL URLWithString:addr];

    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setTimeoutInterval: 5];

    NSURLSession *session = [NSURLSession sharedSession];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:urlRequest completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            resolve(@"{\"err_msg\":\"Network request failed\"}");
            return;
        }

        char *pszResult = NULL;

        get_transaction_pool_hashes(data.bytes, data.length, &pszResult);

        NSString *jsonResult = [NSString stringWithUTF8String:pszResult];
        free(pszResult);
        resolve(jsonResult);
    }];
    [task resume];
}

+ (void) handleDownloadAndProcess:(NSString*) method
                                 :(NSString*) params
                                 :(RCTPromiseResolveBlock) resolve
                                 :(RCTPromiseRejectBlock) reject {

    NSData *paramsData = [params dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError;
    NSDictionary *jsonParams = [NSJSONSerialization JSONObjectWithData:paramsData options:kNilOptions error:&jsonError];

    NSString *addr = jsonParams[@"url"];
    NSString *startHeight = jsonParams[@"start_height"];


    size_t length = 0;
    const char *m_body = create_blocks_request([startHeight intValue], &length);

    NSURL *url = [NSURL URLWithString:addr];
    NSData *binaryData = [NSData dataWithBytes:m_body length:length];
    free((void *)m_body);

    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setHTTPBody:binaryData];
    [urlRequest setTimeoutInterval: 4 * 60];

    NSURLSession *session = [NSURLSession sharedSession];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:urlRequest completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            resolve(@"{\"err_msg\":\"Network request failed\"}");
            return;
        }

        char *pszResult = NULL;

        extract_utxos_from_blocks_response(data.bytes, data.length, [params UTF8String], &pszResult);

        NSString *jsonResult = [NSString stringWithUTF8String:pszResult];
        free(pszResult);
        resolve(jsonResult);
    }];
    [task resume];
}

+ (void) handleDefault:(NSString*) method
                      :(NSString*) params
                      :(RCTPromiseResolveBlock) resolve
                      :(RCTPromiseRejectBlock) reject {
    char *pszResult = NULL;

    fast_crypto_monero_core([method UTF8String], [params UTF8String], &pszResult);

    if (pszResult == NULL) {
        resolve(NULL);
        return;
    }

    NSString *jsonResult = [NSString stringWithUTF8String:pszResult];
    free(pszResult);
    resolve(jsonResult);
}

RCT_EXPORT_MODULE()

RCT_REMAP_METHOD(moneroCore, :(NSString*) method
                 :(NSString*) params
                 :(RCTPromiseResolveBlock) resolve
                 :(RCTPromiseRejectBlock) reject)
{
    if ([method isEqualToString:@"download_and_process"]) {
        [RNFastCrypto handleDownloadAndProcess:method :params :resolve :reject];
    } else if ([method isEqualToString:@"get_transaction_pool_hashes"]) {
        [RNFastCrypto handleGetTransactionPoolHashes:method :params :resolve :reject];
    } else {
        [RNFastCrypto handleDefault:method :params :resolve :reject];
    }
}

RCT_EXPORT_METHOD(readSettings:(NSString *)dirPath
                  prefix:(NSString *)filePrefix
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;

    NSArray *contents = [fileManager contentsOfDirectoryAtPath:dirPath error:&error];

    if (error) {
        reject(@"error", @"can't read settings file", error);
        return;
    }

    NSPredicate *predicateHasPrefix = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", filePrefix];
    NSArray *filteredArray = [contents filteredArrayUsingPredicate:predicateHasPrefix];
    
    NSArray *values = [filteredArray rnfs_mapObjectsUsingBlock:^id(NSString *obj, NSUInteger idx) {
        NSString *name = [obj stringByReplacingOccurrencesOfString:@".json" withString:@""];
        NSArray *components = [name componentsSeparatedByString:filePrefix];

        if ([components count] != 2 || [components[1] isEqual:@"enabled"]) return [NSNumber numberWithInt:0];

        return [NSNumber numberWithInteger: [components[1] integerValue]];
    }];

    NSPredicate *predicateNotNil = [NSPredicate predicateWithFormat:@"SELF != 0"];
    NSArray *valuesClean = [values filteredArrayUsingPredicate:predicateNotNil];

    if (valuesClean.count == 0) {
        resolve(@{});
        return;
    }

    NSDictionary *r = @{
        @"size": [NSNumber numberWithInteger:valuesClean.count],
        @"oldest": [valuesClean valueForKeyPath:@"@min.self"],
        @"latest": [valuesClean valueForKeyPath:@"@max.self"],
    };

    resolve(r);
}

RCT_REMAP_METHOD(secp256k1EcPubkeyCreate,
                 secp256k1EcPubkeyCreate:(NSString *)privateKeyHex
                 compressed:(NSInteger)compressed
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  char *szPublicKeyHex = malloc(sizeof(char) * [privateKeyHex length] * 2);
  fast_crypto_secp256k1_ec_pubkey_create([privateKeyHex UTF8String], szPublicKeyHex, compressed);
  NSString *publicKeyHex = [NSString stringWithUTF8String:szPublicKeyHex];
  free(szPublicKeyHex);
  resolve(publicKeyHex);
}

RCT_REMAP_METHOD(secp256k1EcPrivkeyTweakAdd,
                 secp256k1EcPrivkeyTweakAdd:(NSString *)privateKeyHex
                 tweak:(NSString *)tweakHex
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  int privateKeyHexLen = [privateKeyHex length] + 1;
  char szPrivateKeyHex[privateKeyHexLen];
  const char *szPrivateKeyHexConst = [privateKeyHex UTF8String];

  strcpy(szPrivateKeyHex, szPrivateKeyHexConst);
  fast_crypto_secp256k1_ec_privkey_tweak_add(szPrivateKeyHex, [tweakHex UTF8String]);
  NSString *privateKeyTweakedHex = [NSString stringWithUTF8String:szPrivateKeyHex];
  resolve(privateKeyTweakedHex);
}

RCT_REMAP_METHOD(secp256k1EcPubkeyTweakAdd,
                 secp256k1EcPubkeyTweakAdd:(NSString *)publicKeyHex
                 tweak:(NSString *)tweakHex
                 compressed:(NSInteger) compressed
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  int publicKeyHexLen = [publicKeyHex length] + 1;
  char szPublicKeyHex[publicKeyHexLen];
  const char *szPublicKeyHexConst = [publicKeyHex UTF8String];

  strcpy(szPublicKeyHex, szPublicKeyHexConst);
  fast_crypto_secp256k1_ec_pubkey_tweak_add(szPublicKeyHex, [tweakHex UTF8String], compressed);
  NSString *publicKeyTweakedHex = [NSString stringWithUTF8String:szPublicKeyHex];
  resolve(publicKeyTweakedHex);
}
@end
