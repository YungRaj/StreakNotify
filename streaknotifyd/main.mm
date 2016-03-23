/*
This is a daemon that handles requests to the Snapchat application and retrieves information from models that are only available in classes that the app uses, what I can do later is send requests to the Snapchat server for the information wanted (it is possible if I decide to make this an application later for those not able to jailbreak their iPhones), but this is probably a easier solution for the time being.
 
    -YungRaj
*/

#import <Foundation/Foundation.h>
#import <objc/runtime.h>


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

@interface SNDaemon : NSObject {
    NSArray *_displayNames;
}
@end

@implementation SNDaemon

-(id)init{
    self = [super init];
    if(self){
        
        /* start the server so that clients can start listening to us, and sends a notification to us if a client does in fact start listening, at this point none of the clients are created and the daemon is being initialized after a reboot/respring of the device */
        
        /* the daemon is a client and a server in this case, a client of the app (tweak) and a server to the preferences bundle */
    
        CPDistributedNotificationCenter* notificationCenter;
        notificationCenter = [CPDistributedNotificationCenter centerNamed:@"com.YungRaj.streaknotifyd"];
        [notificationCenter runServer];
        [notificationCenter retain];
        
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self
               selector:@selector(clientDidStartListening:)
                   name:@"CPDistributedNotificationCenterClientDidStartListeningNotification"
                 object:notificationCenter];
        
    }
    return self;
}

-(void)clientDidStartListening:(NSNotification*)notification{
    // NSDictionary* userInfo = [notification userInfo];
   // NSString *bundleIdentifier = [userInfo objectForKey:@"CPBundleIdentifier"];
    
    
    /* once the daemon's server has a client that means we can become a client of the app (tweak), so that the notification for getting the display names will be triggered */
    
    CPDistributedNotificationCenter *notificationCenter = [CPDistributedNotificationCenter centerNamed:@"com.YungRaj.streaknotify"];
    [notificationCenter startDeliveringNotificationsToMainThread];
        
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(displayNamesFromApp:)
                name:@"displayNamesFromApp"
                object:nil];
}

-(void)displayNamesFromApp:(NSNotification*)notification{
    if([[notification name] isEqual:@"displayNamesFromApp"]){
        
        /* once the app's server sends this notification after the client (the daemon [us]) starts listening that means we have the display names and we can safely hand them over to the preferences bundle */
        
        /* sets the displayNames ivar just in case requesting them from the app (tweak) is not needed, most likely a good idea in the future cause then we don't need to keep talking to the app (tweak) each time */
        NSDictionary *userInfo = [notification userInfo];
        CPDistributedNotificationCenter *notificationCenter = [CPDistributedNotificationCenter centerNamed:@"com.YungRaj.streaknotifyd"];
        if([[userInfo objectForKey:@"displayNames"] isKindOfClass:[NSArray class]]){
            _displayNames = (NSArray*)[userInfo objectForKey:@"displayNames"];
            [notificationCenter postNotificationName:@"displayNamesFromDaemon"
                                            userInfo:@{_displayNames:
                                                       @"displayNames"}];
        }
    }
}



@end


int main(int argc, char **argv, char **envp) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    SNDaemon *daemon = [[SNDaemon alloc] init];
    
    /* found this code in an example daemon, but since we are adding the daemon already as a target/observer for notifications, I don't believe this is needed. Notifications will fire and on their own and the daemon will not be deallocated right after allocation when the release message is sent to the daemon object */
    
    /*NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate date]
                                              interval:60.0
                                                target:daemon
                                              selector:@selector(randomMethod???:)
                                              userInfo:nil
                                               repeats:NO];
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop addTimer:timer forMode:NSDefaultRunLoopMode];
    [runLoop run];*/
    
    [daemon release];
    [pool release];
    
	return 0;
}

