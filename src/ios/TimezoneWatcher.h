#import <Cordova/CDV.h>
#import <CoreLocation/CoreLocation.h>

@interface TimezoneWatcher : CDVPlugin

typedef void (^CompletionHandlerBlock)(UIBackgroundFetchResult);
typedef void (^PerformFetchBlock)(UIApplication* application, CompletionHandlerBlock completionHandler) ;

@end
