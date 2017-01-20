#import <Cordova/CDV.h>

@interface TimezoneWatcher : CDVPlugin

typedef void (^CompletionHandlerBlock)(UIBackgroundFetchResult);
typedef void (^PerformFetchBlock)(UIApplication* application, CompletionHandlerBlock completionHandler) ;

@end