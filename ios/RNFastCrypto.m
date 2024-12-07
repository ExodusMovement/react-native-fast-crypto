
#import "RNFastCrypto.h"
#import "native-crypto.h"
#import "NSArray+Map.h"
#import <Foundation/Foundation.h>

#include <stdbool.h>
#include <stdint.h>

@implementation RNFastCrypto

static NSOperationQueue *_processingQueue = nil;
static BOOL _stopProcessing = NO; // Flag to control operation cancellation
static NSDictionary *_qosMapping;

+ (BOOL)shouldStopProcessing {
    return _stopProcessing;
}

+ (NSOperationQueue *)processingQueue {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _processingQueue = [[NSOperationQueue alloc] init];
        _processingQueue.name = @"io.exodus.RNFastCrypto.ProcessingQueue";
        _processingQueue.maxConcurrentOperationCount = 1;
    });
    return _processingQueue;
}

+ (NSDictionary *)qosMapping {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _qosMapping = @{
            @"user_interactive": @(NSQualityOfServiceUserInteractive),
            @"user_initiated": @(NSQualityOfServiceUserInitiated),
            @"utility": @(NSQualityOfServiceUtility),
            @"background": @(NSQualityOfServiceBackground)
        };
    });
    return _qosMapping;
}

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
    _stopProcessing = NO; // Reset the flag

    if (jsonError) {
        NSString *errorJSON = @"{\"err_msg\":\"Failed to parse JSON parameters\"}";
        resolve(errorJSON);
        return;
    }

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
    [urlRequest setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];

    NSBlockOperation *processOperation = [NSBlockOperation blockOperationWithBlock:^{
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

         NSURLSessionDataTask *task = [session dataTaskWithRequest:urlRequest completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSString *errorJSON = [NSString stringWithFormat:@"{\"err_msg\":\"Network request failed: %@\"}", error.localizedDescription];
                resolve(errorJSON);
                return;
            }

            if ([RNFastCrypto shouldStopProcessing]) { 
                resolve(@"{\"err_msg\":\"Processing stopped\"}");
                return;
            }

            char *pszResult = NULL;

            extract_utxos_from_blocks_response(data.bytes, data.length, [params UTF8String], &pszResult);

            if (pszResult == NULL) {
                NSString *errorJSON = @"{\"err_msg\":\"Internal error: Memory allocation failed\"}";
                resolve(errorJSON);
                return;
            }

            NSString *jsonResult = [NSString stringWithUTF8String:pszResult];
            free(pszResult);

            if ([RNFastCrypto shouldStopProcessing]) { 
                resolve(@"{\"err_msg\":\"Operations are stopped\"}");
                return;
            }

            resolve(jsonResult);
        }];
        [task resume];
    }];
    if (@available(iOS 8.0, *)) {
        NSString *qosString = jsonParams[@"qos"];
        processOperation.qualityOfService = [RNFastCrypto convertToQosFromString:qosString];
    }
    [[RNFastCrypto processingQueue] addOperation:processOperation];
}

+ (void) handleDownloadFromClarityAndProcess:(NSString*) method
                                            :(NSString*) params
                                            :(RCTPromiseResolveBlock) resolve
                                            :(RCTPromiseRejectBlock) reject {

    NSData *paramsData = [params dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError;
    NSDictionary *jsonParams = [NSJSONSerialization JSONObjectWithData:paramsData options:kNilOptions error:&jsonError];
    _stopProcessing = NO; // Reset the flag

    if (jsonError) {
        NSString *errorJSON = @"{\"err_msg\":\"Failed to parse JSON parameters\"}";
        resolve(errorJSON);
        return;
    }

    NSString *addr = jsonParams[@"url"];
    NSURL *url = [NSURL URLWithString:addr];

    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    [urlRequest setHTTPMethod:@"GET"];
    [urlRequest setTimeoutInterval: 4 * 60];

    NSBlockOperation *processOperation = [NSBlockOperation blockOperationWithBlock:^{
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
        NSURLSessionDataTask *downloadTask = [session dataTaskWithRequest:urlRequest completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSString *errorJSON = [NSString stringWithFormat:@"{\"err_msg\":\"[Clarity] Network request failed: %@\"}", error.localizedDescription];
                resolve(errorJSON);
                return;
            }

            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                NSString *errorMsg = @"Unknown error";
                if (data != nil) {
                    NSDictionary *errorResponse = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
                    if (errorResponse && [errorResponse objectForKey:@"message"]) {
                        errorMsg = errorResponse[@"message"];
                    }
                }

                NSString *errorJSON = [NSString stringWithFormat:@"{\"err_msg\":\"[Clarity] HTTP Error %ld: %@\"}", (long)httpResponse.statusCode, errorMsg];
                resolve(errorJSON);
                return;
            }

            if ([RNFastCrypto shouldStopProcessing]) { 
                resolve(@"{\"err_msg\":\"Processing stopped\"}");
                return;
            }

            char *pszResult = NULL;

            extract_utxos_from_clarity_blocks_response(data.bytes, data.length, [params UTF8String], &pszResult);

            if (pszResult == NULL) {
                NSString *errorJSON = @"{\"err_msg\":\"Internal error: Memory allocation failed\"}";
                resolve(errorJSON);
                return;
            }

            NSString *jsonResult = [NSString stringWithUTF8String:pszResult];
            free(pszResult);

            if ([RNFastCrypto shouldStopProcessing]) { 
                resolve(@"{\"err_msg\":\"Operations are stopped\"}");
                return;
            }

            resolve(jsonResult);
        }];
        [downloadTask resume];
    }];
    
    if (@available(iOS 8.0, *)) {
        NSString *qosString = jsonParams[@"qos"];
        processOperation.qualityOfService = [RNFastCrypto convertToQosFromString:qosString];
    }

    [[RNFastCrypto processingQueue] addOperation:processOperation];
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
    } else if ([method isEqualToString:@"stop_processing_task"]) {
        [RNFastCrypto stopProcessingTasks];
        resolve(@"{\"success\":true}");
    } else {
        [RNFastCrypto handleDefault:method :params :resolve :reject];
    }
}

+ (void)allowProcessingTasks {
    _stopProcessing = NO; // Reset the flag
}

+ (void)stopProcessingTasks {
    _stopProcessing = YES;
    [[RNFastCrypto processingQueue] cancelAllOperations];
    [[RNFastCrypto processingQueue] waitUntilAllOperationsAreFinished]; 
}

+ (NSQualityOfService)convertToQosFromString:(NSString *)qosString {
    NSNumber *qosValue = [RNFastCrypto qosMapping][qosString];
    if (qosValue) {
        return qosValue.integerValue;
    }

    // Default value
    return NSQualityOfServiceUtility;
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
