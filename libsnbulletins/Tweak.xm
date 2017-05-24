#include <dlfcn.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <rocketbootstrap/rocketbootstrap.h>
#import <BulletinBoard/BBLocalDataProviderStore.h>
#import <BulletinBoard/BBServer.h>
#import <BulletinBoard/BBDataProvider.h>
#import <BulletinBoard/BBBulletinRequest.h>

@interface CPDistributedMessagingCenter : NSObject

+ (instancetype)centerNamed:(NSString *)name;

- (void)runServer;
- (void)runServerOnCurrentThread;
- (void)stopServer;
- (void)registerForMessageName:(NSString *)messageName target:(id)target selector:(SEL)selector;
- (BOOL)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (NSDictionary*)sendMessageAndReceiveReplyName:(NSString*)messageName userInfo:(NSDictionary*)userInfo;
- (NSDictionary*)sendMessageAndReceiveReplyName:(NSString*)messageName userInfo:(NSDictionary*)userInfo error:(NSError **)error;

@end


// Firmware < 9.0
@interface SBSLocalNotificationClient : NSObject
+ (void)scheduleLocalNotification:(id)notification bundleIdentifier:(id)bundleIdentifier;
@end

// Firmware >= 9.0
@interface UNSNotificationScheduler
- (id)initWithBundleIdentifier:(NSString *)bundleIdentifier;
- (void)addScheduledLocalNotifications:(NSArray *)notifications waitUntilDone:(BOOL)waitUntilDone;
@end

static void ScheduleBulletin(NSDate *bulletinDate,
                             NSString *bulletinMessage){
    NSLog(@"libsnbulletins::Using BulletinBoard to schedule bulletin for message %@",bulletinMessage);
    
    BBBulletinRequest *bulletin = [[BBBulletinRequest alloc] init];
    bulletin.sectionID = @"com.toyopagroup.picaboo";
    bulletin.bulletinID = @"com.toyopagroup.picaboo";
    bulletin.publisherBulletinID = @"com.toyopagroup.picaboo";
    bulletin.recordID = @"com.toyopagroup.picaboo";
    bulletin.showsUnreadIndicator = NO;
    bulletin.message = bulletinMessage;
    bulletin.date = bulletinDate;
    bulletin.lastInterruptDate = bulletinDate;
    BBDataProviderAddBulletin(provider,bulletin);
}

static void ResetBulletins(NSDictionary *info){
    NSArray *bulletins = [info objectForKey:@"kBulletins"];
    for(NSDictionary *bulletin in bulletins){
        ScheduleBulletin(bulletin[@"kBulletinDate"],bulletin[@"kBulletinMessage"]);
    }
    
}

