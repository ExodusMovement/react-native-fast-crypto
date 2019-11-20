
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

+ (void) handleDownloadAndProcess:(NSString*) method
                                 :(NSString*) params
                                 :(RCTPromiseResolveBlock) resolve
                                 :(RCTPromiseRejectBlock) reject {
    NSString *addr = @"https://xmr.exodus-prod.io/get_blocks.bin";

    size_t length = 0;
    const char *m_body = create_blocks_request(1971000, &length);

    char *updated_body = malloc(length);
    memcpy(updated_body, m_body, length);

    // For some reason first 10 bytes are random bytes.
    updated_body[0] = 0x01;
    updated_body[1] = 0x11;
    updated_body[2] = 0x01;
    updated_body[3] = 0x01;
    updated_body[4] = 0x01;
    updated_body[5] = 0x01;
    updated_body[6] = 0x02;
    updated_body[7] = 0x01;
    updated_body[8] = 0x01;
    updated_body[9] = 0x14;

    NSURL *url = [NSURL URLWithString:addr];
    NSData *binaryData = [NSData dataWithBytes:updated_body length:length];
    free(updated_body);

    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setHTTPBody:binaryData];

    NSURLSession *session = [NSURLSession sharedSession];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:urlRequest completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        resolve([NSString stringWithFormat:@"Content-Length: %lu", (unsigned long) data.length]);
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
    } else {
        [RNFastCrypto handleDefault:method :params :resolve :reject];
    }
}
@end
