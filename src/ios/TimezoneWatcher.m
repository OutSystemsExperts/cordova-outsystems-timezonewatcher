/********* TimezoneWatcher.m Cordova Plugin Implementation *******/
#import "TimezoneWatcher.h"
#import "RSSwizzle.h"
#import <objc/runtime.h>
#import <UserNotifications/UserNotifications.h>

static NSString* const kOSTimezonePrefKey = @"com.outsystems.timezone.key";
static NSString* const kOSOptionsNotificationTitle = @"com.outsystems.notification.title";
static NSString* const kOSOptionsNotificationBody = @"com.outsystems.notification.body";
static NSString* const kOSOptionsNotificationIdentifier = @"com.outsystems.notification.identifier";
#define SYSTEM_VERSION_GRATERTHAN_OR_EQUALTO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

@interface TimezoneWatcher()

@property (nonatomic, strong) NSString* callbackId;
@property BOOL hasEventToDeliver;
@property BOOL deviceReady;

@property (nonatomic, strong) NSString* notificationTitle;
@property (nonatomic, strong) NSString* notificationBody;

@end

@implementation TimezoneWatcher

#pragma mark Life Cycle

-(void) pluginInitialize {
    self.notificationTitle = [self getSavedNotificationTitle];
    self.notificationBody = [self getSavedNotificationBody];
    
    if(!self.notificationTitle) {
        self.notificationTitle = @"Timezone";
    }
    if(!self.notificationBody) {
        self.notificationBody = @"System timezone has changed.";
    }
    
    //    self.hasEventToDeliver = NO;
    self.deviceReady = NO;
    if(self.hasEventToDeliver == NO) {
        self.hasEventToDeliver = [self hasTimezoneChanged];
    }
    
    [self setupUIApplicationDelegate];
    
    // Enable background fetch
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    [self registerObservers];
}

/**
 Cordova exposed method executed from Javascript when cordova's deviceready event is dispatched
 */
-(void) deviceReady:(CDVInvokedUrlCommand*)command {
    self.deviceReady = YES;
    NSString* title = [command argumentAtIndex:0];
    NSString* body = [command argumentAtIndex:1];
    
    if(title) {
        [self setSavedNotificationTitle:title];
        self.notificationTitle = title;
    }
    
    if(body) {
        [self setSavedNotificationBody:body];
        self.notificationBody = body;
    }
    
    self.callbackId = [command callbackId];
    [self fireTimezoneChangedEvent];
}

/**
 * OnResume is only called when application is background and comes to foreground.
 */
-(void) onResume {
    if(self.deviceReady) {
        [self fireTimezoneChangedEvent];
    }
}

/**
 * Handler for backgroundFetch execution
 */
-(void) handleBackgroundFetch:(NSNotification*) notification {
    CompletionHandlerBlock completionHandler = notification.object;
    if([self hasTimezoneChanged]) {
        [self scheduleLocalNotification];
    }
    completionHandler(UIBackgroundFetchResultNewData);
}

-(void) NSSystemTimeZoneDidChangeNotificationHandler {
    if([self hasTimezoneChanged]) {
        self.hasEventToDeliver = true;
    }
}

-(void) UIApplicationSignificantTimeChangeNotificationHandler {
    if([self hasTimezoneChanged]) {
        self.hasEventToDeliver = true;
    }
}

-(void) applicationDidFinishLaunching: (NSNotification*) notification {
    NSDictionary *userInfo = notification.userInfo;
    
    if ([[userInfo allKeys] containsObject:UIApplicationLaunchOptionsLocalNotificationKey]) {
        [self handleApplicationFromNotification:userInfo];
    } 
}



-(void) applicationDidEnterBackground: (NSNotification*) notification {
}

-(void) applicationWillEnterForeground: (NSNotification*) notification {
    // Clear notifications
    if(SYSTEM_VERSION_GRATERTHAN_OR_EQUALTO(@"10.0")){
        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
        [center removeDeliveredNotificationsWithIdentifiers:@[kOSOptionsNotificationIdentifier]];
    } else {
        NSArray* notifications = [[UIApplication sharedApplication] scheduledLocalNotifications];
        for(int i=0; i < notifications.count; i++) {
            UILocalNotification* localNotification = [notifications objectAtIndex:i];
            NSDictionary* userInfo = [localNotification userInfo];
            NSString* notificationId = [userInfo valueForKey:@"id"];
            if([notificationId isEqualToString:kOSOptionsNotificationIdentifier]) {
                [[UIApplication sharedApplication] cancelLocalNotification:localNotification];
                break;
            }
        }
    }
}

/**
 * Clear all registered obversvers
 */
- (void)dealloc
{
    [self unregisterObservers];
}

#pragma mark Core Logic

/**
 * Saves the current systemTimeZone into UserDefaults
 */
-(NSTimeZone*) saveCurrentTimezone {
    NSUserDefaults* preferences = [NSUserDefaults standardUserDefaults];
    [NSTimeZone resetSystemTimeZone];
    NSTimeZone* currentSystemsTimezone = [NSTimeZone systemTimeZone];
    
    [preferences setValue:[currentSystemsTimezone abbreviation] forKey:kOSTimezonePrefKey];
    [preferences synchronize];
    return currentSystemsTimezone;
}

/**
 * Retrieve the last timezone abbreviation saved on UserDefaults
 */
-(NSString*) getLastTimezoneAbbreviation {
    NSUserDefaults* preferences = [NSUserDefaults standardUserDefaults];
    return [preferences stringForKey:kOSTimezonePrefKey];
}

/**
 * Check if the TimeZone has changed comparing the current system
 * timezone with the previous saved timezone abbreviation.
 */
-(BOOL) hasTimezoneChanged {
    NSString* lastTimezoneName = [self getLastTimezoneAbbreviation];
    BOOL timezoneChanged = NO;
    if(lastTimezoneName) {
        timezoneChanged = ![lastTimezoneName isEqualToString:[[NSTimeZone systemTimeZone] abbreviation]];
        if(timezoneChanged) {
        }
    } else {
        [self saveCurrentTimezone];
        timezoneChanged = NO;
    }

    return timezoneChanged;
}

-(void) registerObservers {
    
    // Register observers for timezone change
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(UIApplicationSignificantTimeChangeNotificationHandler)
                                                 name:UIApplicationSignificantTimeChangeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(NSSystemTimeZoneDidChangeNotificationHandler)
                                                 name:NSSystemTimeZoneDidChangeNotification
                                               object:nil];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleBackgroundFetch:)
                                                 name:@"BackgroundFetch"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onResume)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidFinishLaunching:)
                                                 name:UIApplicationDidFinishLaunchingNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    
    
    [self registerForRemoteNotifications];
}

-(void) unregisterObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationSignificantTimeChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSSystemTimeZoneDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"BackgroundFetch" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidFinishLaunchingNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void) fireTimezoneChangedEvent {
    
    if([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        return;
    }
    
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* result;
        if(self.hasEventToDeliver) {
            NSString* timezoneAbbreviation = [[NSTimeZone systemTimeZone] abbreviation];
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:timezoneAbbreviation];
            self.hasEventToDeliver = NO;
            [self saveCurrentTimezone];
        } else {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
        }
        
        // Keep the channel open for native<->js communication
        
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:_callbackId];
    }];
}

#pragma mark UIApplicationDelegate


/**
 * Prepares the default UIApplicationDelegate to either have a default implementation for
 * @selector(application:performFetchWithCompletionHandler:) or to swizzle it
 * so that we can inject our logic into it.
 */
-(void) setupUIApplicationDelegate {
    PerformFetchBlock fetchBlock =^(UIApplication* application, CompletionHandlerBlock completionHandler){
        [self application:application performFetchWithCompletionHandler:completionHandler];
    };
    
    SEL selector = @selector(application:performFetchWithCompletionHandler:);
    Class klass = [[[UIApplication sharedApplication] delegate] class];
    
    if(![[[UIApplication sharedApplication] delegate] respondsToSelector:selector]) {
        // delegate doesn't have an implementation of @selector(application:performFetchWithCompletionHandler:)
        // So had one!
        Protocol* protocol = @protocol(UIApplicationDelegate);
        Method origMethod = class_getInstanceMethod(klass, selector);
        
        if(!origMethod) {
            struct objc_method_description methodDescription = protocol_getMethodDescription(protocol, selector, NO, YES);
            IMP implementation = class_getMethodImplementation([self class], selector);
            class_addMethod(klass, selector, implementation, methodDescription.types);
        }
    } else {
        // delegate already has a implementation for @selector(application:performFetchWithCompletionHandler:)
        // so lets swizzle it.
        [RSSwizzle swizzleInstanceMethod:selector inClass:klass newImpFactory:^id(RSSwizzleInfo *swizzleInfo) {
            return ^void(__unsafe_unretained id self, UIApplication* application, CompletionHandlerBlock completionHandler){
                
                fetchBlock(application, completionHandler);
                
                int (*originalIMP)(__unsafe_unretained id, SEL, UIApplication*, CompletionHandlerBlock);
                originalIMP = (__typeof(originalIMP))[swizzleInfo getOriginalImplementation];
                originalIMP(self, selector, application, completionHandler);
            };
        } mode:RSSwizzleModeAlways key:NULL];
    }
}

-(void) application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    void (^safeHandler)(UIBackgroundFetchResult) = ^(UIBackgroundFetchResult result){
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(result);
        });
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BackgroundFetch" object:safeHandler];
}

#pragma mark Local Notifications

/**
 * Schedules a local notification
 */
- (void) scheduleLocalNotification {
    [self.commandDelegate runInBackground:^{
        if(SYSTEM_VERSION_GRATERTHAN_OR_EQUALTO(@"10.0")){
            
            UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
            content.title = self.notificationTitle;
            content.body = self.notificationBody;
            content.sound = [UNNotificationSound defaultSound];
            content.userInfo = @{@"timezone-changed":@"timezone-changed"};
            
            
            // Deliver the notification in five seconds.
            UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger
                                                          triggerWithTimeInterval:5 repeats:NO];
            UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:kOSOptionsNotificationIdentifier
                                                                                  content:content trigger:trigger];
            
            // Schedule the notification.
            UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
            center.delegate = self;
            [center addNotificationRequest:request withCompletionHandler:nil];
        } else {
            
            UILocalNotification* localNotification = [[UILocalNotification alloc] init];
            localNotification.alertTitle = self.notificationTitle;
            localNotification.alertBody = [NSString stringWithFormat:@"%@\n%@", self.notificationTitle, self.notificationBody];
            localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:5];
            localNotification.repeatInterval = 0; // Do not repeat!
            localNotification.userInfo = @{@"timezone-changed":@"timezone-changed", @"id":kOSOptionsNotificationIdentifier};
            
            
            [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
        }
    }];
}

/**
 * Asks user for permission in order to use Local Notifications capabilities
 */
- (void)registerForRemoteNotifications {
    if(SYSTEM_VERSION_GRATERTHAN_OR_EQUALTO(@"10.0")){
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        //        center.delegate = self;
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError * _Nullable error){
            if(!error){
                //[[UIApplication sharedApplication] registerForRemoteNotifications];
            }
        }];
    } else {
        if([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
            UIUserNotificationType types;
            UIUserNotificationSettings *settings;
            
            settings = [[UIApplication sharedApplication] currentUserNotificationSettings];
            
            types = settings.types|UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound;
            
            settings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
            
            
            [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
            //            [[UIApplication sharedApplication] registerUserNotificationSettings:UIUserNotification]
        }
    }
}

/**
 * Called when a notification is delivered to a foreground app.
 */
-(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler{
    completionHandler(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge);
}

/**
 * Called to let your app know which action was selected by the user for a given notification.
 */
-(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)())completionHandler{
    [self handleApplicationFromNotification:response.notification.request.content.userInfo];
    completionHandler();
}


-(void) handleApplicationFromNotification: (NSDictionary*) userInfo {
    if([userInfo objectForKey:@"timezone-changed"]) {
        self.hasEventToDeliver = YES;
    }
}

#pragma mark Utilities

/**
 *
 * Fetch the state of Background Refresh on the device
 *
 */
- (void) getBackgroundRefreshStatus: (CDVInvokedUrlCommand*)command
{
    NSString* status;
    
    if ([[UIApplication sharedApplication] backgroundRefreshStatus] == UIBackgroundRefreshStatusAvailable) {
        status = @"authorized";
        NSLog(@"Background updates are available for the app.");
    }else if([[UIApplication sharedApplication] backgroundRefreshStatus] == UIBackgroundRefreshStatusDenied){
        status = @"denied";
        NSLog(@"The user explicitly disabled background behavior for this app or for the whole system.");
    }else if([[UIApplication sharedApplication] backgroundRefreshStatus] == UIBackgroundRefreshStatusRestricted){
        status = @"restricted";
        NSLog(@"Background updates are unavailable and the user cannot enable them again. For example, this status can occur when parental controls are in effect for the current user.");
    }
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:status];
    
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    
}

-(NSString*) getSavedNotificationTitle {
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    return [prefs stringForKey:kOSOptionsNotificationTitle];
}

-(NSString*) getSavedNotificationBody {
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    return [prefs stringForKey:kOSOptionsNotificationBody];
}

-(void) setSavedNotificationTitle:(NSString*) title {
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:title forKey:kOSOptionsNotificationTitle];
}

-(void) setSavedNotificationBody:(NSString*) body {
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:body forKey:kOSOptionsNotificationBody];
}

@end
