
#import "RNFastCrypto.h"
#import "native-crypto.h"
#import "NSArray+Map.h"
#import <Foundation/Foundation.h>
#import <Sentry/Sentry.h>

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
    id<SentrySpan> transaction = [SentrySDK startTransactionWithName:@"handleDownloadAndProcess" operation:@"task"];

    NSData *paramsData = [params dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError;
    NSDictionary *jsonParams = [NSJSONSerialization JSONObjectWithData:paramsData options:kNilOptions error:&jsonError];

    NSString *addr = jsonParams[@"url"];
    NSString *startHeight = jsonParams[@"start_height"];

    id<SentrySpan> *paramSpan = [transaction startChildWithOperation:@"create-blocks-request" description:@"Create blocks request"];

    size_t length = 0;
    const char *m_body = create_blocks_request([startHeight intValue], &length);
    [paramSpan finish];
    
    NSURL *url = [NSURL URLWithString:addr];
    NSData *binaryData = [NSData dataWithBytes:m_body length:length];
    free((void *)m_body);

    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setHTTPBody:binaryData];
    [urlRequest setTimeoutInterval: 4 * 60];
    [urlRequest setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];

    NSURLSession *session = [NSURLSession sharedSession];
    id<SentrySpan> networkSpan = [transaction startChildWithOperation:@"http-request" description:@"Download data from Clarity"];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:urlRequest completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            resolve(@"{\"err_msg\":\"Network request failed\"}");
            [SentrySDK captureError:error];
            [networkSpan finishWithStatus:kSentrySpanStatusInternalError];
            [transaction finishWithStatus:kSentrySpanStatusInternalError];
            return;
        }

        char *pszResult = NULL;

        id<SentrySpan> extractUtxosSpan = [transaction startChildWithOperation:@"process-response" description:@"Extract UTXOs from response"];

        extract_utxos_from_blocks_response(data.bytes, data.length, [params UTF8String], &pszResult);

        NSString *jsonResult = [NSString stringWithUTF8String:pszResult];
        free(pszResult);
        resolve(jsonResult);
        [extractUtxosSpan finish];
        [transaction finish];
    }];
    [task resume];
}

+ (void) handleDownloadFromClarityAndProcess:(NSString*) method
                                            :(NSString*) params
                                            :(RCTPromiseResolveBlock) resolve
                                            :(RCTPromiseRejectBlock) reject {
    id<SentrySpan> transaction = [SentrySDK startTransactionWithName:@"handleDownloadFromClarityAndProcess" operation:@"task"];
                                            
    NSData *paramsData = [params dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError;
    NSDictionary *jsonParams = [NSJSONSerialization JSONObjectWithData:paramsData options:kNilOptions error:&jsonError];
    
    if (jsonError) {
        NSString *errorJSON = @"{\"err_msg\":\"Failed to parse JSON parameters\"}";
        resolve(errorJSON);
        [transaction finishWithStatus:kSentrySpanStatusInvalidArgument];
        return;
    }

    NSString *addr = jsonParams[@"url"];
    NSURL *url = [NSURL URLWithString:addr];

    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    [urlRequest setHTTPMethod:@"GET"];
    [urlRequest setTimeoutInterval: 4 * 60];

    NSURLSession *session = [NSURLSession sharedSession];

    id<SentrySpan> networkSpan = [transaction startChildWithOperation:@"http-request" description:@"Download data from Clarity"];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:urlRequest completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            resolve(@"{\"err_msg\":\"[Clarity] Network request failed\"}");
            [SentrySDK captureError:error];
            [networkSpan finishWithStatus:kSentrySpanStatusInternalError];
            [transaction finishWithStatus:kSentrySpanStatusInternalError];
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            NSString *errorMsg = [NSString stringWithFormat:@"HTTP Error: %ld", (long)httpResponse.statusCode];
            NSString *errorJSON = [NSString stringWithFormat:@"{\"err_msg\":\"[Clarity] %@\"}", errorMsg];
            resolve(errorJSON);
            [networkSpan setStatus:kSentrySpanStatusNotFound];
            [networkSpan finish];
            [transaction finishWithStatus:kSentrySpanStatusNotFound];
            return;
        }

        char *pszResult = NULL;

        id<SentrySpan> extractUtxosSpan = [transaction startChildWithOperation:@"process-response" description:@"Extract UTXOs from Clarity response"];
        extract_utxos_from_clarity_blocks_response(data.bytes, data.length, [params UTF8String], &pszResult);

        if (pszResult == NULL) {
            NSString *errorJSON = @"{\"err_msg\":\"Internal error: Memory allocation failed\"}";
            resolve(errorJSON);
            [extractUtxosSpan finishWithStatus:kSentrySpanStatusResourceExhausted];
            [transaction finishWithError:nil];
            return;
        }

        NSString *jsonResult = [NSString stringWithUTF8String:pszResult];
        free(pszResult);
        resolve(jsonResult);
        [extractUtxosSpan finish];
        [transaction finish];
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
    } else if ([method isEqualToString:@"download_from_clarity_and_process"]) {
        [RNFastCrypto handleDownloadFromClarityAndProcess:method :params :resolve :reject];
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
@end
