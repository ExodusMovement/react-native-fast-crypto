
#import "RNFastCrypto.h"
#import "native-crypto.h"
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
    NSURL *url = [NSURL URLWithString:@"https://xmr.exodus.io/get_transaction_pool_hashes.bin"];

    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setTimeoutInterval: 5];

    NSURLSession *session = [NSURLSession sharedSession];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:urlRequest completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            resolve(@"{\"err_msg\":\"Network request failed\"}");
            return;
        }

        NSRange dataRange = NSMakeRange(0, data.length);

        NSData *statusStop = [@"\"status\": \"OK\"" dataUsingEncoding:NSUTF8StringEncoding];
        NSData *txHashesStop = [@"\"tx_hashes\": \"" dataUsingEncoding:NSUTF8StringEncoding];
        NSData *quotationStop = [@"\",\r\n" dataUsingEncoding:NSUTF8StringEncoding];

        NSRange statusRange = [data rangeOfData:statusStop options:0 range:dataRange];
        NSRange txHashRange = [data rangeOfData:txHashesStop options:0 range:dataRange];
        NSRange quotationRange = [data rangeOfData:quotationStop options:0 range:NSMakeRange(txHashRange.location + txHashRange.length, data.length - txHashRange.location - txHashRange.length)];

        if (statusRange.location == NSNotFound || txHashRange.location == NSNotFound || quotationRange.location == NSNotFound) {
            resolve(@"{\"err_msg\":\"Network request failed\"}");
            return;
        }

        unsigned long start = txHashRange.location + txHashRange.length;
        NSRange hashesRange = NSMakeRange(start, quotationRange.location - start);
        NSData *hashesData = [data subdataWithRange:hashesRange];

        // TODO: Forward hashesData to native

        resolve(@"{\"err_msg\":\"X\"}");
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
    } else if ([method isEqualToString:@"test"]) {
        [RNFastCrypto handleGetTransactionPoolHashes:method :params :resolve :reject];
    } else {
        [RNFastCrypto handleDefault:method :params :resolve :reject];
    }
}
@end
