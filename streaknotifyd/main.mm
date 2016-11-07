/*
This is a daemon that handles requests to the Snapchat application and retrieves information from models that are only available in classes that the app uses, what I can do later is send requests to the Snapchat server for the information wanted (it is possible if I decide to make this an application later for those not able to jailbreak their iPhones), but this is probably a easier solution for the time being.
 
    -YungRaj
*/
#include <dlfcn.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <rocketbootstrap/rocketbootstrap.h>

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


@interface SNDaemon : NSObject {
    BOOL _snapchatOpen;
}

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
    /* load the data from the application if it is saved to file, if not then open the snapchat application and wait for the message to be sent from the client */
    /* the daemon should have a copy of the data saved to file always unless the daemon is running on the device for the first time (if yes, then start the snapchat application so that we can retrieve them immediately after the SpringBoard starts) */
    
    NSDictionary *friendNamesAndEmojis;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"streaknotifyd"];
    
    friendNamesAndEmojis = [NSDictionary dictionaryWithContentsOfFile:filePath];
    
    

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
    
    _snapchatOpen = NO;
    
    /* run a messaging center server on the daemon so that the client (tweak) can send us messages when it needs to update anything that we need */
    
    CPDistributedMessagingCenter *c = [CPDistributedMessagingCenter centerNamed:@"com.YungRaj.streaknotifyd"];
    rocketbootstrap_unlock("com.YungRaj.streaknotifyd");
    rocketbootstrap_distributedmessagingcenter_apply(c);
    [c runServerOnCurrentThread];
    [c retain];
    [c registerForMessageName:@"friendmojis"
                       target:self
                     selector:@selector(friendmojis:userInfo:)];
    
    /* start the server so that clients can start listening to us, and sends a notification to us if a client does in fact start listening, at this point none of the clients are created and the daemon is being initialized after a reboot/respring of the device */
    
    /* the daemon is only a server of both the app and the preferences bundle but not a client (could make the daemon a client of the app but can't as of now because of Sandboxing. RocketBootstrap's functionality is only to expose services to the sandboxed app and not vice versa [can't register sandboxed services]) */
    
}


-(void)saveDataToPlist{
    /* saves the dictionary containing the data that we need for the preferences bundle to disk so that it can be recycled */
    /* this is a workaround so that we don't have to request to the snapchat application every time the preferences bundle wants information it */
    /* make sure that the file in /var/root/Documents is valid so that it doesn't fail saving to file */
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
        
        /* the snapchat application has started or friends have changed and it has sent us this message so that we can grab a copy of the data that we need and save it to file. So that when the preferences bundle requests the display names, we will have them. We should have them already if the daemon is not running for the first time, but it could be an updated list when a friend has been added or the snap streak count has been updated for a friend. We can keep this data and have it stored in the daemon if the preferences bundle is open but still store it so that the next time it is open we can use it  */
        
        NSLog(@"Got dictionary from tweak, updating for preferences on next launch");
        self.friendNamesAndEmojis = userInfo;
        NSLog(@"%@",userInfo);
        [self saveDataToPlist];
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

