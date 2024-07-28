
#import "RNFastCrypto.h"
#import "native-crypto.h"
#import "NSArray+Map.h"
#import <Foundation/Foundation.h>

#include <stdbool.h>
#include <stdint.h>

@implementation RNFastCrypto

static NSOperationQueue *_downloadQueue = nil;
static NSOperationQueue *_processingQueue = nil;
static NSMutableArray *_downloadOperations = nil;
static NSMutableArray *_downloadOrder = nil;
static BOOL _shouldStopOperations = NO; 


- (instancetype)init 
{
    self = [super init];
    if (self) {
        _downloadQueue = [[NSOperationQueue alloc] init];
        _downloadQueue.name = @"io.exodus.RNFastCrypto.downloadQueue";
        _downloadQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount; 

        _processingQueue = [[NSOperationQueue alloc] init];
        _processingQueue.name = @"io.exodus.RNFastCrypto.processingQueue";
        _processingQueue.maxConcurrentOperationCount = 1;

        _downloadOperations = [[NSMutableArray alloc] init];
        _shouldStopOperations = NO;
    }
    return self;
}

+ (BOOL)shouldStopOperations {
    @synchronized(self) { // Ensure thread-safety when accessing _shouldStopOperations
        return _shouldStopOperations;
    }
}

+ (void)setShouldStopOperations:(BOOL)value {
    @synchronized(self) { // Ensure thread-safety when modifying _shouldStopOperations
        _shouldStopOperations = value;
    }
}

+ (NSOperationQueue *)downloadQueue {
    @synchronized(self) {
        if (_downloadQueue == nil) {
            _downloadQueue = [[NSOperationQueue alloc] init];
            _downloadQueue.name = @"io.exodus.RNFastCrypto.DownloadQueue";
            _downloadQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
        }
        return _downloadQueue;
    }
}

+ (NSOperationQueue *)processingQueue {
    @synchronized(self) {
        if (_processingQueue == nil) {
            _processingQueue = [[NSOperationQueue alloc] init];
            _processingQueue.name = @"io.exodus.RNFastCrypto.ProcessingQueue";
            _processingQueue.maxConcurrentOperationCount = 1; 
        }
        return _processingQueue;
    }
}

+ (NSMutableArray *)downloadOperations {
    @synchronized(self) {
        if (_downloadOperations == nil) {
            _downloadOperations = [[NSMutableArray alloc] init];
        }
        return _downloadOperations;
    }
}

+ (NSMutableArray *)downloadOrder {
    @synchronized(self) {
        if (_downloadOrder == nil) {
            _downloadOrder = [[NSMutableArray alloc] init];
        }
        return _downloadOrder;
    }
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

+ (void) handleDownloadFromClarityAndProcess:(NSString*) method
                                            :(NSString*) params
                                            :(RCTPromiseResolveBlock) resolve
                                            :(RCTPromiseRejectBlock) reject {

    NSData *paramsData = [params dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError;
    NSDictionary *jsonParams = [NSJSONSerialization JSONObjectWithData:paramsData options:kNilOptions error:&jsonError];
    
    if (jsonError) {
        NSString *errorJSON = @"{\"err_msg\":\"Failed to parse JSON parameters\"}";
        resolve(errorJSON);
        return;
    }

    if ([RNFastCrypto shouldStopOperations]) { 
        NSString *errorJSON = @"{\"err_msg\":\"Operations are stopped\"}";
        resolve(errorJSON);
        return;
    }

    NSString *addr = jsonParams[@"url"];
    NSURL *url = [NSURL URLWithString:addr];

    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    [urlRequest setHTTPMethod:@"GET"];
    [urlRequest setTimeoutInterval: 4 * 60];

    NSBlockOperation *downloadOperation = [NSBlockOperation blockOperationWithBlock:^{
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *downloadTask = [session dataTaskWithRequest:urlRequest completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
            if ([RNFastCrypto shouldStopOperations]) { 
                resolve(@"{\"err_msg\":\"Operations are stopped\"}");
                return;
            }

            if (error) {
                resolve(@"{\"err_msg\":\"[Clarity] Network request failed\"}");
                return;
            }

            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                NSString *errorMsg = [NSString stringWithFormat:@"HTTP Error: %ld", (long)httpResponse.statusCode];
                NSString *errorJSON = [NSString stringWithFormat:@"{\"err_msg\":\"[Clarity] %@\"}", errorMsg];
                resolve(errorJSON);
                return;
            }

            NSBlockOperation *processingOperation = [NSBlockOperation blockOperationWithBlock:^{
                if ([RNFastCrypto shouldStopOperations]) { 
                    resolve(@"{\"err_msg\":\"Operations are stopped\"}");
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

                if ([RNFastCrypto shouldStopOperations]) { 
                    resolve(@"{\"err_msg\":\"Operations are stopped\"}");
                    return;
                }

                resolve(jsonResult);
            }];
            @synchronized(self) {
                for (NSString *urlString in [RNFastCrypto downloadOrder]) {
                    if ([urlString isEqualToString:addr]) {
                        // Find the download operation for this URL
                        for (NSURLSessionDataTask *task in [RNFastCrypto downloadOperations]) {
                            if ([task.originalRequest.URL.absoluteString isEqualToString:urlString]) {
                                [processingOperation addDependency:task.taskDescription];
                                break;
                            }
                        }
                        [[RNFastCrypto downloadOrder] removeObject:urlString]; // Remove from order array
                        break;
                    }
                }
            }
            [[RNFastCrypto processingQueue] addOperation:processingOperation];
        }];

        // Set task description for dependency management
        downloadTask.taskDescription = [NSString stringWithFormat:@"%@ - %@", addr, downloadTask.originalRequest.URL.absoluteString]; 
        [[RNFastCrypto downloadOperations] addObject:downloadTask];
        [downloadTask resume];
    }];

    //  Add to Download Queue and Track Order
    @synchronized(self) {
        [[RNFastCrypto downloadOrder] addObject:addr];
        [[RNFastCrypto downloadQueue] addOperation:downloadOperation]; 
    }
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
    } else if ([method isEqualToString:@"start_processing_tasks"]) {
        [RNFastCrypto startProcessingTasks];
        resolve(nil);
    } else if ([method isEqualToString:@"stop_processing_tasks"]) {
        [RNFastCrypto stopProcessingTasks];
        resolve(nil);
    } else {
        [RNFastCrypto handleDefault:method :params :resolve :reject];
    }
}

+ (void)startProcessingTasks {
    [RNFastCrypto setShouldStopOperations:NO]; // Reset the flag
}

+ (void)stopProcessingTasks {
    [RNFastCrypto setShouldStopOperations:YES];
    [[RNFastCrypto downloadQueue] cancelAllOperations];

    // Use enumeration for safer cancellation of download tasks
    for (NSURLSessionDownloadTask *task in [RNFastCrypto downloadOperations]) {
        [task cancel];
    }
    [[RNFastCrypto downloadOperations] removeAllObjects];
    [[RNFastCrypto processingQueue] cancelAllOperations];
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
