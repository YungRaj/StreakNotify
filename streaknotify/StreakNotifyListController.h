
#import <Preferences/Preferences.h>


@class NSLock, NSMutableDictionary, NSString;

@interface CPDistributedNotificationCenter : NSObject {
    NSString* _centerName;
    NSLock* _lock;
    CFRunLoopSourceRef _receiveNotificationSource;
    BOOL _isServer;
    NSMutableDictionary* _sendPorts;
    unsigned _startCount;
}
+(CPDistributedNotificationCenter*)centerNamed:(NSString*)centerName;
-(id)_initWithServerName:(NSString*)serverName;
-(NSString*)name;
-(void)_createReceiveSourceForRunLoop:(CFRunLoopRef)runLoop;
-(void)_checkIn;
-(void)_checkOutAndRemoveSource;
-(void)_notificationServerWasRestarted;
-(void)runServer;
-(void)startDeliveringNotificationsToMainThread;
-(void)postNotificationName:(NSString*)name;
-(void)postNotificationName:(NSString*)name userInfo:(NSDictionary*)info;
-(BOOL)postNotificationName:(NSString*)name userInfo:(NSDictionary*)info toBundleIdentifier:(NSString*)bundleIdentifier;
@end

@interface SpringBoard : UIApplication

-(void)_relaunchSpringBoardNow;
-(BOOL)launchApplicationWithIdentifier:(NSString*)identifier suspended:(BOOL)suspended;
@end


@interface StreakNotifyListController : PSListController

-(void)respring;

@end