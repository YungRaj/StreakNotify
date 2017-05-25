/* 
 * This daemon is a helper process that processes Mach messages using the Distributed Notifications API's
 * in efforts to respond to events that are crucial to the tweak's functionality. It registers a service via
 * the bootstrap context and uses a CFRunLoop in order to keep the daemon running continuously
 */

#include <asl.h>
#include <dlfcn.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <rocketbootstrap/rocketbootstrap.h>

#ifndef kCFCoreFoundationVersionNumber_iOS_9_0
#define kCFCoreFoundationVersionNumber_iOS_9_0 1240.10
#endif

#define IOS_LT(version) (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_##version)

@interface SpringBoard : UIApplication

-(BOOL)launchApplicationWithIdentifier:(NSString*)identifier suspended:(BOOL)suspended;
@end

@interface CPDistributedMessagingCenter : NSObject

+ (instancetype)centerNamed:(NSString *)name;
- (void)runServer;
- (void)runServerOnCurrentThread;
- (void)stopServer;
- (void)registerForMessageName:(NSString *)messageName target:(id)target selector:(SEL)selector;
- (BOOL)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (NSDictionary*)sendMessageAndReceiveReplyName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (NSDictionary*)sendMessageAndReceiveReplyName:(NSString *)messageName userInfo:(NSDictionary *)userInfo error:(NSError **)error;

@end

// Firmware < 9.0
@interface SBSLocalNotificationClient : NSObject
+ (id)scheduledLocalNotificationsForBundleIdentifier:(id)arg1;
+ (void)setScheduledLocalNotifications:(id)arg1 bundleIdentifier:(id)arg2;
+ (void)cancelAllLocalNotificationsForBundleIdentifier:(id)arg1;
+ (void)cancelLocalNotification:(id)arg1 bundleIdentifier:(id)arg2 waitUntilDone:(_Bool)arg3;
+ (void)cancelLocalNotification:(id)arg1 bundleIdentifier:(id)arg2;
+ (void)scheduleLocalNotification:(id)arg1 bundleIdentifier:(id)arg2 waitUntilDone:(_Bool)arg3;
+ (void)scheduleLocalNotification:(id)arg1 bundleIdentifier:(id)arg2;
+ (id)scheduledLocalNotifications;
+ (void)setScheduledLocalNotifications:(id)arg1;
+ (void)cancelAllLocalNotifications;
+ (void)cancelLocalNotification:(id)arg1;
+ (void)scheduleLocalNotification:(id)arg1;
+ (void)_scheduleLocalNotifications:(id)arg1 cancel:(_Bool)arg2 replace:(_Bool)arg3 optionalBundleIdentifier:(id)arg4;
+ (void)_scheduleLocalNotifications:(id)arg1 cancel:(_Bool)arg2 replace:(_Bool)arg3 optionalBundleIdentifier:(id)arg4 waitUntilDone:(_Bool)arg5;
+ (id)getPendingNotification;
@end

// Firmware >= 9.0
@interface UNSNotificationScheduler
- (void)_addScheduledLocalNotifications:(id)arg1 withCompletion:(id /* block */)arg2;
- (void)_cancelScheduledLocalNotifications:(id)arg1 withCompletion:(id /* block */)arg2;
- (void)addScheduledLocalNotifications:(id)arg1;
- (void)addScheduledLocalNotifications:(id)arg1 waitUntilDone:(bool)arg2;
- (id)bundleIdentifier;
- (void)cancelAllScheduledLocalNotifications;
- (void)cancelScheduledLocalNotifications:(id)arg1;
- (void)cancelScheduledLocalNotifications:(id)arg1 waitUntilDone:(bool)arg2;
- (void)dealloc;
- (id)delegate;
- (id)init;
- (id)initWithBundleIdentifier:(id)arg1;
- (id)scheduledLocalNotifications;
- (void)scheduledLocalNotificationsWithResult:(id /* block */)arg1;
- (void)setBundleIdentifier:(id)arg1;
- (void)setDelegate:(id)arg1;
- (void)setScheduledLocalNotifications:(id)arg1;
- (void)setUserNotificationCenter:(id)arg1;
- (void)snoozeScheduledLocalNotifications:(id)arg1;
- (void)snoozeScheduledLocalNotifications:(id)arg1 withCompletion:(id /* block */)arg2;
- (id)userNotificationCenter;
- (void)userNotificationCenter:(id)arg1 didChangePendingNotificationRequests:(id)arg2;
- (void)userNotificationCenter:(id)arg1 didDeliverNotifications:(id)arg2;
@end


static void ScheduleNotification(NSDate *date,
                                 NSString *message,
                                 NSString *friendName){
    NSLog(@"Scheduling notification at %@ with message \"%@\" for friend %@",date,message,friendName);
    
    // Load UIKit to setup notification for SpringBoardServices/UserNotificationServices
    void *uikit = dlopen("/System/Library/Frameworks/UIKit.framework/UIKit", RTLD_LAZY);
    if(uikit){
        UILocalNotification *notification = [[objc_getClass("UILocalNotification") alloc] init];
        notification.alertBody = message;
        notification.fireDate = date;
        notification.userInfo = @{@"Username" : friendName};
        
        // Detect firmware version to select the correct API's
        if (IOS_LT(9_0)) {
            [objc_getClass("SBSLocalNotificationClient") scheduleLocalNotification:notification
                                                                  bundleIdentifier:@"com.toyopagroup.picaboo"];
        } else {
            UNSNotificationScheduler *scheduler = [[objc_getClass("UNSNotificationScheduler") alloc] initWithBundleIdentifier:@"com.toyopagroup.picaboo"];
            [scheduler addScheduledLocalNotifications:@[notification] waitUntilDone:NO];
        }
        dlclose(uikit);
    }
    
}

static void ResetNotifications(NSDictionary *info){
    // Lazy loading/binding of a required library to schedule a notifications
    
    void *uns = NULL;
    if (IOS_LT(9_0)) {
        // SpringBoardServices
        [objc_getClass("SBSLocalNotificationClient") cancelAllLocalNotificationsForBundleIdentifier:@"com.toyopagroup.picaboo"];
    } else {
        // UserNotificationServices
        uns = dlopen("/System/Library/PrivateFrameworks/UserNotificationServices.framework/UserNotificationServices", RTLD_LAZY);
        if (uns) {
            UNSNotificationScheduler *scheduler = [[objc_getClass("UNSNotificationScheduler") alloc] initWithBundleIdentifier:@"com.toyopagroup.picaboo"];
            [scheduler cancelAllScheduledLocalNotifications];
        }
        
    }
    
    NSArray *notifications = [info objectForKey:@"kNotifications"];
    for(NSDictionary *notification in notifications){
        ScheduleNotification(notification[@"kNotificationDate"],
                             notification[@"kNotificationMessage"],
                             notification[@"kNotificationFriendName"]);
    }
    
    if(uns){
        UNSNotificationScheduler *scheduler = [[objc_getClass("UNSNotificationScheduler") alloc] initWithBundleIdentifier:@"com.toyopagroup.picaboo"];
        NSLog(@"Scheduled notifications succcess %@",[scheduler scheduledLocalNotifications]);
        dlclose(uns);
    } else {
        NSLog(@"Scheduled notifications success %@",[objc_getClass("SBSLocalNotificationClient") scheduledLocalNotificationsForBundleIdentifier:@"com.toyopagroup.picaboo"]);
    }
}


@interface SNDaemon : NSObject {
    
}

@property (assign,nonatomic) BOOL applicationLaunched;
@property (strong,nonatomic) NSDictionary *friendNamesAndEmojis;

@end

@implementation SNDaemon

-(id)init{
    self = [super init];
    if(self){
        [self setUpDaemon];
        
    }
    return self;
}

-(void)setUpDaemon{
    /* Load previously saved data from file */
    
    NSDictionary *friendNamesAndEmojis;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"streaknotifyd"];
    
    friendNamesAndEmojis = [NSDictionary dictionaryWithContentsOfFile:filePath];
    
    
    /* Start the Snapchat Application in the background suspended so that the friendmojis get saved */

    if(!friendNamesAndEmojis){
        void *sbServices = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        int (*SBSLaunchApplicationWithIdentifier)(CFStringRef identifier, Boolean suspended) = (int (*)(CFStringRef, Boolean))dlsym(sbServices, "SBSLaunchApplicationWithIdentifier");
        SBSLaunchApplicationWithIdentifier(
                            (CFStringRef)@"com.toyopagroup.picaboo",true);
        dlclose(sbServices);
    } else{
        NSLog(@"File found at %@\n Contents:%@",filePath,friendNamesAndEmojis);
        self.friendNamesAndEmojis = friendNamesAndEmojis;
    }
    
    
    
    NSLog(@"Running servers on the daemon");
    
    self.applicationLaunched = NO;
    
    /* Register a server through the bootstrap context that allows IPC between Snapchat and streaknotifyd */
    
    CPDistributedMessagingCenter *c = [CPDistributedMessagingCenter centerNamed:@"com.YungRaj.streaknotifyd"];
    rocketbootstrap_unlock("com.YungRaj.streaknotifyd");
    rocketbootstrap_distributedmessagingcenter_apply(c);
    [c runServerOnCurrentThread];
    [c retain];
    [c registerForMessageName:@"friendmojis"
                       target:self
                     selector:@selector(friendmojis:userInfo:)];
    [c registerForMessageName:@"notifications"
                       target:self
                     selector:@selector(notifications:userInfo:)];
    
    /* The daemon is only a server of the Snapchat application because it processes Mach Messages between
     * my tweak and streaknotifyd */
    
}


-(void)saveDataToPlist{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentsDirectory]){
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:documentsDirectory withIntermediateDirectories:NO attributes:nil error:&error];
    }
    
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"streaknotifyd"];
    
    NSLog(@"Writing names and friendmojis to file %@",filePath);

    
    [self.friendNamesAndEmojis writeToFile:filePath atomically:YES];
    
}


-(void)friendmojis:(NSString*)name userInfo:(NSDictionary*)userInfo{
    if([name isEqual:@"friendmojis"]){
        // Received friendmojis, handle them by saving to file
        NSLog(@"Got dictionary from tweak, updating for preferences on next launch");
        self.friendNamesAndEmojis = userInfo;
        NSLog(@"%@",userInfo);
        [self saveDataToPlist];
    }
}

-(void)notifications:(NSString*)name userInfo:(NSDictionary*)userInfo{
    if([name isEqual:@"notifications"]){
        // Received notification data, schedule them using bootstrap
        NSLog(@"Resetting notifications");
        ResetNotifications(userInfo);
    }
}


@end


int main(int argc, char **argv, char **envp) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    SNDaemon *daemon = [[SNDaemon alloc] init];
    [[NSRunLoop currentRunLoop] run];
    
    [daemon release];
    [pool drain];
    
    // should never reach this point
    
    NSLog(@"Unexpectedly returned from CFRunLoop, service is closing");
    
	return 0;
}

