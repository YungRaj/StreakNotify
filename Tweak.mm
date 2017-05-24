/*
 *   This tweak notifies a user when a snapchat streak with another friend is running down in time.
 *   It also tells a user how much time is remanining in their feed. Customizable with a bunch of settings,
 *   custom time, custom friends, and even preset values that you can enable with a switch in preferences.
 *   Auto-send snap will be implemented soon so that the streak is kept with a person
 *
 */

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <rocketbootstrap/rocketbootstrap.h>

#import "Interfaces.h"

#ifdef DEBUG
#define SNLog(...) NSLog(__VA_ARGS__)
#else
#define SNLog(...) void(0)
#endif


static NSString *snapchatVersion = nil;
static NSDictionary *prefs = nil;
static NSMutableArray *customFriends = nil;
static UIImage *autoReplySnapstreakImage = nil;
// static CFStringRef applicationID = CFSTR("com.toyopagroup.picaboo");


/* Load Preferences and other relevant data */

static void LoadPreferences() {
    if(!snapchatVersion){
        NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
        snapchatVersion = [infoDict objectForKey:@"CFBundleVersion"];
    }
    if(!prefs){
        prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.YungRaj.streaknotify.plist"];
    }
    if(!customFriends){
        NSDictionary *friendmojiList = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.YungRaj.friendmoji.plist"];
        customFriends = [[NSMutableArray alloc] init];
        for(NSString *name in [friendmojiList allKeys]){
            if([friendmojiList[name] boolValue]){
                [customFriends addObject:name];
            }
        }
    }
    if(!autoReplySnapstreakImage){
        NSString *filePath = @"/var/mobile/Documents/streaknotify_autoreply.jpeg";
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL fileExists = [fileManager fileExistsAtPath:filePath];
        if(fileExists){
            autoReplySnapstreakImage = [[UIImage alloc] initWithContentsOfFile:filePath];
        }
    }
}

// DEPRECATED, should not be used
/* Gets the earliest snap that wasn't replied to, so 24 hours past that date is accurate enough to show time left.
 Not used anymore if SOJUFriendmoji class isn't sufficient.
 
 @param receive
 A flag that specifies if it is the user that we find earliest unreplied snap for
 */

static Snap* FindEarliestUnrepliedSnapForChat(BOOL receive, SCChat *chat){
    NSArray *snaps = [chat allSnapsArray];
    
    if(!snaps || ![snaps count]){
        return nil;
    }
    
    snaps = [snaps sortedArrayUsingComparator:^(id obj1, id obj2){
        if ([obj1 isKindOfClass:objc_getClass("Snap")] &&
            [obj2 isKindOfClass:objc_getClass("Snap")]) {
            Snap *s1 = obj1;
            Snap *s2 = obj2;
            
            if([s1.timestamp laterDate:s2.timestamp]) {
                return (NSComparisonResult)NSOrderedAscending;
            } else if ([s2.timestamp laterDate:s1.timestamp]) {
                return (NSComparisonResult)NSOrderedDescending;
            }
        }
        return (NSComparisonResult)NSOrderedSame;
    }];
    
    Snap *earliestUnrepliedSnap = nil;
    
    for(id obj in snaps){
        if([obj isKindOfClass:objc_getClass("Snap")]){
            Snap *snap = obj;
            if(receive){
                NSString *sender = [snap sender];
                if(!sender){
                    earliestUnrepliedSnap = nil;
                }else if(!earliestUnrepliedSnap && sender){
                    earliestUnrepliedSnap = snap;
                }
            } else {
                NSString *recipient = [snap recipient];
                if(!recipient){
                    earliestUnrepliedSnap = nil;
                } else if(!earliestUnrepliedSnap && recipient){
                    earliestUnrepliedSnap = snap;
                }
            }
        }
    }
    return earliestUnrepliedSnap;
}


static NSDictionary* GetFriendmojis(){
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    
    NSMutableDictionary *friendsWithStreaks = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *friendsWithoutStreaks = [[NSMutableDictionary alloc] init];
    
    Manager *manager = [objc_getClass("Manager") shared];
    User *user = [manager user];
    Friends *friends = [user friends];
    for(Friend *f in [friends getAllFriends]){
        
        NSString *displayName = [f display];
        NSString *friendmoji = [f getFriendmojiForViewType:0];
        
        if(displayName && ![displayName isEqual:@""]){
            if([f snapStreakCount] > 2){
                [friendsWithStreaks setObject:friendmoji forKey:displayName];
            }else {
                [friendsWithoutStreaks setObject:friendmoji forKey:displayName];
            }
        }else{
            NSString *username = [f name];
            if(username && ![username isEqual:@""]){
                if([f snapStreakCount] > 2){
                    [friendsWithStreaks setObject:friendmoji forKey:username];
                }else {
                    [friendsWithoutStreaks setObject:friendmoji forKey:username];
                }
            }
        }
        
    }
    
    [dictionary setObject:friendsWithStreaks forKey:@"friendsWithStreaks"];
    [dictionary setObject:friendsWithoutStreaks forKey:@"friendsWithoutStreaks"];
    
    return dictionary;
}

/* Sends a Mach message to the daemon using Distributed Notifications via the bootstrap server */

static void SendFriendmojisToDaemon(){
    SNLog(@"StreakNotify::Sending friendmojis to Daemon");
    
    CPDistributedMessagingCenter *c = [CPDistributedMessagingCenter centerNamed:@"com.YungRaj.streaknotifyd"];
    rocketbootstrap_unlock("com.YungRaj.streaknotifyd");
    rocketbootstrap_distributedmessagingcenter_apply(c);
    [c sendMessageName:@"friendmojis"
              userInfo:GetFriendmojis()];
}

static void SizeLabelToRect(UILabel *label, CGRect labelRect){
    /* Fit text into UILabel */
    label.frame = labelRect;
    
    int fontSize = 15;
    int minFontSize = 3;
    
    CGSize constraintSize = CGSizeMake(label.frame.size.width, MAXFLOAT);
    
    do {
        label.font = [UIFont fontWithName:label.font.fontName size:fontSize];
        
        CGRect textRect = [[label text] boundingRectWithSize:constraintSize
                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                  attributes:@{NSFontAttributeName:label.font}
                                                     context:nil];
        
        CGSize size = textRect.size;
        if(size.height <= label.frame.size.height )
            break;
        
        fontSize -= 0.2;
        
    } while (fontSize > minFontSize);
}

SOJUFriendmoji* FindOnFireEmoji(NSArray *friendmojis){
    for(NSObject *obj in friendmojis){
        if([obj isKindOfClass:objc_getClass("SOJUFriendmoji")]){
            SOJUFriendmoji *friendmoji = (SOJUFriendmoji*)obj;
            if([[friendmoji categoryName] isEqual:@"on_fire"]){
                return friendmoji;
            }
        }
    }
    return nil;
}


static NSString* GetTimeRemaining(Friend *f,
                                  SCChat *c,
                                  NSDate *expirationDate){
    
    /* In the new chat 2.0 update to snapchat, the SOJUFriend and SOJUFriendBuilder class now sets a property called snapStreakExpiration/snapStreakExpiryTime which is basically a long long value that describes the time in seconds since 1970 of when the snap streak should end when that expiration date arrives.
     */
    /* Note: January 10, 2017
     In the newest versions of Snapchat, not sure which version this started, a class named SOJUFriendmoji contains data related to the friendmoji's. Since the fire emoji is a friendmoji, the SOJUFriendmoji class is what we were always looking for. There is a memeber of the class named categoryName and expirationTime. After some exploration, if the categoryName's value is @"on_fire", then the expirationTime is the exact time when the friendmoji is valid until. We can now use this for retrieving the time remaining */
    if(!f || !c){
        return @"";
    }
    
    NSDate *date = [NSDate date];
    
    NSCalendar *gregorianCal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSUInteger unitFlags = NSSecondCalendarUnit | NSMinuteCalendarUnit |NSHourCalendarUnit | NSDayCalendarUnit;
    NSDateComponents *components = [gregorianCal components:unitFlags
                                                   fromDate:date
                                                     toDate:expirationDate
                                                    options:0];
    NSInteger day = [components day];
    NSInteger hour = [components hour];
    NSInteger minute = [components minute];
    NSInteger second = [components second];
    
    if([prefs[@"kExactTime"] boolValue]){
        if(day){
            return [NSString stringWithFormat:@"%ldd %ldh %ldm",(long)day,long(hour),(long)minute];
        }else if(!day && hour){
            return [NSString stringWithFormat:@"%ldh %ldm",(long)hour,(long)minute];
        }else{
            goto NotExactTime;
        }
    }else{
        goto NotExactTime;
    }
NotExactTime:
    if(day){
        return [NSString stringWithFormat:@"%ld d",(long)day];
    }else if(hour){
        return [NSString stringWithFormat:@"%ld hr",(long)hour];
    }else if(minute){
        return [NSString stringWithFormat:@"%ld m",(long)minute];
    }else if(second){
        return [NSString stringWithFormat:@"%ld s",(long)second];
    }
    /* Shouldn't happen but to shut the compiler up this is needed */
    return @"Unknown";
}

static NSDictionary* SetUpNotification(NSDate *expirationDate,
                                       Friend *f,
                                       float seconds,
                                       float minutes,
                                       float hours){
    NSString *friendName = f.name;
    NSString *displayName = f.display;
    if([customFriends count] && ![customFriends containsObject:displayName]){
        SNLog(@"StreakNotify:: Not scheduling notification for %@, not enabled in custom friends",displayName);
        return nil;
    }
    SNLog(@"Using streaknotifyd helper service to schedule notification for %@",displayName);
    float t = hours ? hours : minutes ? minutes : seconds;
    NSString *time = hours ? @"hours" : minutes ? @"minutes" : @"seconds";
    NSDate *notificationDate = nil;
    if(objc_getClass("SOJUFriendmoji")){
        notificationDate = [[NSDate alloc] initWithTimeInterval:-60*60*hours - 60*minutes - seconds
                                                  sinceDate:expirationDate];
    }else{
        notificationDate = [[NSDate alloc] initWithTimeInterval:60*60*24 - 60*60*hours - 60*minutes - seconds
                                                  sinceDate:expirationDate];
    }
    NSString *notificationMessage = [NSString stringWithFormat:@"Keep streak with %@. %ld %@ left!",displayName,(long)t,time];
    
    if([notificationDate laterDate:[NSDate date]] == notificationDate)
        return [@{@"kNotificationFriendName" : friendName,
                  @"kNotificationMessage" : notificationMessage,
                  @"kNotificationDate" : notificationDate } retain];
    else {
        SNLog(@"Not setting up notification at %@ for friend %@",notificationDate,friendName);
        return nil;
    }
}

static void ScheduleNotifications(){
    Manager *manager = [objc_getClass("Manager") shared];
    User *user = [manager user];
    Friends *friends = [user friends];
    SCChats *chats = [user chats];
    
    NSMutableDictionary *notificationsInfo = [[NSMutableDictionary alloc] init];
    NSMutableArray *notifications = [[NSMutableArray alloc] init];
    SNLog(@"SCChats allChats %@",[chats allChats]);
    
    if([[chats allChats] count]){
        for(SCChat *chat in [chats allChats]){
            
            Snap *earliestUnrepliedSnap = FindEarliestUnrepliedSnapForChat(YES,chat);
            Friend *f = [friends friendForName:[chat recipient]];
            
            NSDate *expirationDate = nil;
            if(objc_getClass("SOJUFriendmoji")){
                NSArray *friendmojis = f.friendmojis;
                SOJUFriendmoji *friendmoji = FindOnFireEmoji(friendmojis);
                long long expirationTimeValue = [friendmoji expirationTimeValue];
                expirationDate = [NSDate dateWithTimeIntervalSince1970:expirationTimeValue/1000];
                
            }else{
                expirationDate = [earliestUnrepliedSnap timestamp];
            }
            
            SNLog(@"StreakNotify:: Name and date %@ for %@",expirationDate,[chat recipient]);
            
            if([f snapStreakCount]>2 &&
               (earliestUnrepliedSnap || objc_getClass("SOJUFriendmoji"))){
                if([prefs[@"kTwelveHours"] boolValue]){
                    SNLog(@"Scheduling for 12 hours %@",[f name]);
                    NSDictionary *twelveHours = SetUpNotification(expirationDate,f,0,0,12);
                    if(twelveHours){
                        [notifications addObject:twelveHours];
                    }
                    
                } if([prefs[@"kFiveHours"] boolValue]){
                    SNLog(@"Scheduling for 5 hours %@",[f name]);
                    NSDictionary *fiveHours = SetUpNotification(expirationDate,f,0,0,5);
                    if(fiveHours){
                        [notifications addObject:fiveHours];
                    }
                    
                } if([prefs[@"kOneHour"] boolValue]){
                    SNLog(@"Scheduling for 1 hour %@",[f name]);
                    NSDictionary *oneHour = SetUpNotification(expirationDate,f,0,0,1);
                    if(oneHour){
                        [notifications addObject:oneHour];
                    }
                    
                } if([prefs[@"kTenMinutes"] boolValue]){
                    SNLog(@"Scheduling for 10 minutes %@",[f name]);
                    NSDictionary *tenMinutes = SetUpNotification(expirationDate,f,0,10,0);
                    if(tenMinutes){
                        [notifications addObject:tenMinutes];
                    }
                }
                
                float seconds = [prefs[@"kCustomSeconds"] floatValue];
                float minutes = [prefs[@"kCustomMinutes"] floatValue];
                float hours = [prefs[@"kCustomHours"] floatValue] ;
                if(hours || minutes || seconds){
                    SNLog(@"Scheduling for custom time %@",[f name]);
                    NSDictionary *customTime = SetUpNotification(expirationDate,f,seconds,minutes,hours);
                    if(customTime){
                        [notifications addObject:customTime];
                    }
                }
            }
        }
    }
    [notificationsInfo setObject:notifications forKey:@"kNotifications"];
    SNLog(@"StreakNotify::Sending request to streaknotifyd");
    
    // Send a message with name notifications to streaknotifyd to handle dictionary data
    CPDistributedMessagingCenter *c = [CPDistributedMessagingCenter centerNamed:@"com.YungRaj.streaknotifyd"];
    rocketbootstrap_unlock("com.YungRaj.streaknotifyd");
    rocketbootstrap_distributedmessagingcenter_apply(c);
    [c sendMessageName:@"notifications"
                  userInfo:notificationsInfo];
}


static UILabel* GetLabelFromCell(UIView *cell,
                                 NSMutableArray *instances,
                                 NSMutableArray *labels){
    UILabel *label;
    
    if(![instances containsObject:cell]){
        
        CGSize size = cell.frame.size;
        CGRect rect = CGRectMake(size.width*.75,
                                 size.height*.7,
                                 size.width/5,
                                 size.height/4);
        
        label = [[UILabel alloc] initWithFrame:rect];
        label.textAlignment = NSTextAlignmentRight;
        
        [instances addObject:cell];
        [labels addObject:label];
        
        [cell addSubview:label];
        
        
    }else {
        label = [labels objectAtIndex:[instances indexOfObject:cell]];
    }
    return label;
}

static NSDate* GetExpirationDate(Friend *f,SCChat *chat,Snap *snap){
    if(objc_getClass("SOJUFriendmoji")){
        NSArray *friendmojis = f.friendmojis;
        SOJUFriendmoji *friendmoji = FindOnFireEmoji(friendmojis);
        long long expirationTimeValue = [friendmoji expirationTimeValue];
        return [NSDate dateWithTimeIntervalSince1970:expirationTimeValue/1000];
    }
    if(!snap){
        snap = FindEarliestUnrepliedSnapForChat(NO,chat);
    }
    NSDate *latestSnapDate = [snap timestamp];
    return [latestSnapDate dateByAddingTimeInterval:60*60*24];
}

static NSString *TextForLabel(Friend *f,
                              SCChat *chat,
                              Snap *snap){
    NSDate *expirationDate = GetExpirationDate(f,chat,snap);
    if([expirationDate laterDate:[NSDate date]]!=expirationDate){
        return @"";
    }else if([f snapStreakCount]>2 &&
             (snap || (objc_getClass("SOJUFriendmoji") && [[chat lastSnap] sender]))){
        return [NSString stringWithFormat:@"⏰ %@",GetTimeRemaining(f,chat,expirationDate)];
    }else if([f snapStreakCount]>2){
        return [NSString stringWithFormat:@"⌛️ %@",GetTimeRemaining(f,chat,expirationDate)];
    }
    return @"";
}

static NSString* ConfigureCell(UIView *cell,
                               NSMutableArray *instances,
                               NSMutableArray *labels,
                               Friend *f,
                               SCChat *chat,
                               Snap *snap){
    UILabel *label = GetLabelFromCell(cell,instances,labels);
    
    NSString *text = TextForLabel(f,chat,snap);
    label.text = text;
    
    if([text isEqualToString:@""]){
        label.hidden = YES;
    }else{
        label.hidden = NO;
        SizeLabelToRect(label,label.frame);
    }
    return label.text;
}

void SendAutoReplySnapToUser(NSString *username){
#ifdef AUTO_REPLY
    UIImage *image = [UIImage imageWithContentsOfFile:@"/var/mobile/Documents/streaknotify_autoreply.jpeg"];
    if(image){
        Snap *snap = [[objc_getClass("Snap") alloc] init];
        snap.media.mediaDataToUpload = UIImageJPEGRepresentation(image,0.7);
        snap.media.captionText = prefs[@"kAutoReplySnapstreakCaption"];
        snap.recipient = username;
        
        SNLog(@"StreakNotify:: Snap has been created successfully, preparing to send");
        
        /* UNFINISHED: this is clearly not enough to send a Snap successfully */
        
        [snap send];
        SNLog(@"StreakNotify:: Snap has been requested to send");
    }
#endif
    
}

/* Remote notification has been sent from the APNS server and we must let the app know so that it can schedule a notification for the chat */
/* We need to fetch updates so that the new snap that was sent from the notification can now be recognized as far as notifications go */
/* Otherwise we won't be able to set the notification properly because the new snap or message hasn't been tracked by the application */

void FetchUpdates(){
    Manager *manager = [objc_getClass("Manager") shared];
    if([manager respondsToSelector:@selector(fetchUpdatesWithCompletionHandler:
                                             includeStories:
                                             didHappendWhenAppLaunch:)]){
        [[objc_getClass("Manager") shared] fetchUpdatesWithCompletionHandler:^{
            SNLog(@"StreakNotify:: Finished fetching updates from remote notification, resetting local notifications");
            ScheduleNotifications();
        }
                                                              includeStories:NO
                                                     didHappendWhenAppLaunch:YES];
        // Snapchat 9.40 and less
        
    }else if([manager respondsToSelector:@selector(fetchUpdatesWithCompletionHandler:
                                                   includeStories:
                                                   includeConversations:
                                                   didHappendWhenAppLaunch:)]){
        
        [manager fetchUpdatesWithCompletionHandler:^{
            SNLog(@"StreakNotify:: Finished fetching updates from remote notification, resetting local notifications");
            ScheduleNotifications();
        }
                                    includeStories:NO
                              includeConversations:YES
                           didHappendWhenAppLaunch:YES];
        // Snapchat 9.40 and greater
    }else{
        [objc_getClass("Manager") fetchAllUpdatesWithParameters:nil successBlock:^{
            SNLog(@"StreakNotify:: Finished fetching updates from remote notification, resetting local notifications");
            ScheduleNotifications();
        } failureBlock:nil];
        // Snapchat 9.45.x and greater
    }
}

void HandleRemoteNotification(){
    // FetchUpdates();
}

void HandleLocalNotification(NSString *username){
    SNLog(@"StreakNotify:: Handling local notification, attempting to send auto-reply snap to %@",username);
    /* Callback from LocalNotification which means we check if it is necessary to reply using AutoReply */
    
#ifdef AUTO_REPLY
    if(prefs[@"kAutoReplySnapstreak"]){
        SendAutoReplySnapToUser(username);
    }
#endif
    
}

#ifdef THEOS
%group SnapchatHooks
%hook MainViewController
#else
// @implementation SnapchatHooks
#endif

-(void)viewDidLoad{
    /* Setting up all the user specific data */
    
    %orig();
    
    if(!prefs) {
        SNLog(@"StreakNotify:: No preferences found on file, letting user know");
        if([UIAlertController class]){
            UIAlertController *controller =
            [UIAlertController alertControllerWithTitle:@"StreakNotify"
                                                message:@"You haven't selected any preferences yet in Settings, use defaults?"
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *cancel =
            [UIAlertAction actionWithTitle:@"Cancel"
                                     style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction* action){
                                       exit(0);
                                   }];
            UIAlertAction *ok =
            [UIAlertAction actionWithTitle:@"Ok"
                                     style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction* action){
                                       NSDictionary *preferences = [@{@"kStreakNotifyDisabled" : @NO,
                                                                      @"kExactTime" : @YES,
                                                                      @"kTwelveHours" : @YES,
                                                                      @"kFiveHours" : @NO,
                                                                      @"kOneHour" : @NO,
                                                                      @"kTenMinutes" : @NO,
                                                                      @"kCustomHours" : @"0",
                                                                      @"kCustomMinutes" : @"0",
                                                                      @"kCustomSeconds" : @"0"} retain];
                                       [preferences writeToFile:@"/var/mobile/Library/Preferences/com.YungRaj.streaknotify.plist" atomically:YES];
                                       prefs = preferences;
                                       SNLog(@"StreakNotify:: saved default preferences to file, default settings will now appear in the preferences bundle");
                                   }];
            [controller addAction:cancel];
            [controller addAction:ok];
            [self presentViewController:controller animated:NO completion:nil];
        } else{
            SNLog(@"StreakNotify:: UIAlertController class not available, iOS 9 and earlier");
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"StreakNotify"
                                                            message:@"You haven't selected any preferences yet in Settings, use defaults?"
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:@"Ok", @"Cancel", nil];
            [alert show];
            [alert release];
        }
    }
}

-(void)didSendSnap:(Snap*)snap{
    %orig();
    SNLog(@"StreakNotify::Snap to %@ has sent successfully",[snap recipient])
    ;
    Manager *manager = [objc_getClass("Manager") shared];
    User *user = [manager user];
    SCChats *chats = [user chats];
    [chats chatsDidChange];
    /*
     *  This is expected to show the changes in a SCChat after sending a Snap
     *  Works great but ever since SOJUFriendmoji we rely on the lastSnap property
     *  rather than the sorted array we created for tracking Snaps. This method call
     *  doesn't update it though, which should be the case.
     */
}

#ifdef THEOS
%new
#endif

-(void)alertView:(UIAlertView *)alertView
clickedButtonAtIndex:(NSInteger)buttonIndex{
    if(buttonIndex==0){
        SNLog(@"StreakNotify:: using default preferences");
        NSDictionary *preferences = [@{@"kStreakNotifyDisabled" : @NO,
                                       @"kExactTime" : @YES,
                                       @"kTwelveHours" : @YES,
                                       @"kFiveHours" : @NO,
                                       @"kOneHour" : @NO,
                                       @"kTenMinutes" : @NO,
                                       @"kCustomHours" : @"0",
                                       @"kCustomMinutes" : @"0",
                                       @"kCustomSeconds" : @"0"} retain] ;
        [preferences writeToFile:@"/var/mobile/Library/Preferences/com.YungRaj.streaknotify.plist" atomically:YES];
        prefs = preferences;
        SNLog(@"StreakNotify:: saved default preferences to file, default settings will now appear in the preferences bundle");
    }else {
        SNLog(@"StreakNotify:: exiting application - user denied default settings");
        exit(0);
    }
}

#ifdef THEOS
%end
#endif

#ifdef THEOS
%hook SCAppDelegate
#endif

-(BOOL)application:(UIApplication*)application
didFinishLaunchingWithOptions:(NSDictionary*)launchOptions{
    
    /* Register for local notifications, and do what we normally do */
    
    snapchatVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationSettings* notificationSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
    } else {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes: (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    }
    
    SNLog(@"StreakNotify:: Just launched application successfully running Snapchat version %@",snapchatVersion);
    
    
    CPDistributedMessagingCenter *c = [CPDistributedMessagingCenter centerNamed:@"com.YungRaj.streaknotifyd"];
    rocketbootstrap_distributedmessagingcenter_apply(c);
    [c sendMessageName:@"applicationLaunched" userInfo:nil];
    
    SendFriendmojisToDaemon();
    
    
    return %orig();
}

-(void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
    /* Update LocalNotifications when a RemoteNotification is received */
    LoadPreferences();
    HandleRemoteNotification();
    %orig();
}

-(void)application:(UIApplication *)application
didReceiveLocalNotification:(UILocalNotification *)notification{
    %orig();
    LoadPreferences();
    HandleLocalNotification(notification.userInfo[@"Username"]);
}

-(void)applicationWillTerminate:(UIApplication *)application {
    SNLog(@"StreakNotify:: Snapchat application exiting, daemon will handle the exit of the application");
    
    /*
     CPDistributedMessagingCenter *c = [CPDistributedMessagingCenter centerNamed:@"com.YungRaj.streaknotify"];
     rocketbootstrap_distributedmessagingcenter_apply(c);
     [c sendMessageName:@"applicationTerminated"
     userInfo:nil];*/
    %orig();
}


#ifdef THEOS
%end
#endif

static NSMutableArray *feedCells = nil;
static NSMutableArray *feedCellLabels = nil;

#ifdef THEOS
%hook SCFeedSwipeableTableViewCell
#endif

-(void)updateReplyButtonWithIdentifer:(id)arg1 updateFriendMoji:(_Bool)arg2{
    
}

#if THEOS
%end
#endif


#ifdef THEOS
%hook SCFeedViewController
#endif


-(UITableViewCell*)tableView:(UITableView*)tableView
cellForRowAtIndexPath:(NSIndexPath*)indexPath{
    /*
     *  updating tableview and we want to make sure the feedCellLabels are updated too, if not
     *  created if the feed is now being populated
     */
    
    UITableViewCell *cell = %orig(tableView,indexPath);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        /*
         *  Do this on the main thread because all UI updates should be done on the main
         *  thread
         *  This should already be on the main thread but we should make sure of this
         */
        
        if([cell isKindOfClass:objc_getClass("SCFeedSwipeableTableViewCell")]
           && [cell respondsToSelector:@selector(viewModel)]){
            SCFeedSwipeableTableViewCell *feedCell = (SCFeedSwipeableTableViewCell*)cell;
            
            if(!feedCells){
                feedCells = [[NSMutableArray alloc] init];
            } if(!feedCellLabels){
                feedCellLabels = [[NSMutableArray alloc] init];
            }
            
            NSString *username = nil;
            if([[feedCell viewModel] respondsToSelector:@selector(identifier)]){
                username = [(SCFeedChatCellViewModel*)[feedCell viewModel] identifier];
                /* after reversing snapToHandle in the SCFeedChatCellViewModel class, it seems to use the identifier property to get the snapToHandle from the SCChats class */
            }else if([[feedCell viewModel] respondsToSelector:@selector(snapToHandle)]){
                SCFeedChatCellViewModel *viewModel = (SCFeedChatCellViewModel*)[feedCell viewModel];
                NSString *recipient = [[viewModel snapToHandle] recipient];
                NSString *sender = [[viewModel snapToHandle] sender];
                if(recipient){
                    username = recipient;
                }else{
                    username = sender;
                }
                /* this is an ugly way to do this, but for now it'll work as I reverse more of the SCFeedChatViewModel/SCFeedItem realm */
            }else if([[feedCell viewModel] isKindOfClass:objc_getClass("SCChatFeedCellViewModel")]){
                SCChatFeedCellViewModel *viewModel = (SCChatFeedCellViewModel*)feedCell.viewModel;
                username = [viewModel friendUsername];
            } else if([[feedCell viewModel] respondsToSelector:@selector(username)]){
                SCChatViewModelForFeed *viewModel = (SCChatViewModelForFeed*)feedCell.viewModel;
                username = [viewModel username];
            } else if([[feedCell viewModel] respondsToSelector:@selector(friendUsername)]){
                SCFeedChatCellViewModel *viewModel = (SCFeedChatCellViewModel*)feedCell.viewModel;
                username = [viewModel friendUsername];
            }
            
            /*
             *  find the username of the friend we are trying to show the timer for
             *  SCFeedViewController has changed a lot throughout many Snapchat versions
             */
            
            if(username){
                SNLog(@"StreakNotify::%@ username found, showing label if possible",username);
                Manager *manager = [objc_getClass("Manager") shared];
                User *user = [manager user];
                
                SCChats *chats = [user chats];
                SCChat *chat = [chats chatForUsername:username];
                Friends *friends = [user friends];
                Friend *f = [friends friendForName:username];
                
                // Friend *f = [feedItem friendForFeedItem];
                /* Deprecated/removed in Snapchat 9.34.0 */
                /* Caused the crash in that update */
                
                Snap *earliestUnrepliedSnap = FindEarliestUnrepliedSnapForChat(YES,chat);
                
                SNLog(@"StreakNotify::%@ is earliest unreplied snap %@",earliestUnrepliedSnap,[earliestUnrepliedSnap timestamp]);
                
                if(!MSHookIvar<SCReplyButton*>(feedCell.feedComponentView,"_replyButton")){
                    ConfigureCell(feedCell.feedComponentView, feedCells, feedCellLabels, f, chat, earliestUnrepliedSnap);
                }else{
                    UILabel *label = GetLabelFromCell(cell,feedCells,feedCellLabels);
                    label.text = @"";
                    label.hidden = YES;
                }
            } else{
                SNLog(@"StreakNotify::username not found, Snapchat was updated and no selector was found");
                // Todo: let the user know that the timer could not added to the cells
            }
        }
    });
    
    return cell;
}

// Deprecated in a recent Snapchat version
-(void)didFinishReloadData{
    /* Want to update notifications if something has changed after reloading data */
    SNLog(@"StreakNotify::Finished reloading data");
    %orig();
    ScheduleNotifications();
    
}

// Still active in the current Snapchat version
-(void)pullToRefreshDidFinish{
    SNLog(@"StreakNotify::Finished reloading data");
    %orig();
    ScheduleNotifications();
}


-(void)dealloc{
    SNLog(@"StreakNotify::Deallocating feedViewController");
    [feedCells removeAllObjects];
    [feedCellLabels removeAllObjects];
    [feedCells release];
    [feedCellLabels release];
    feedCells = nil;
    feedCellLabels = nil;
    %orig();
}

#ifdef THEOS
%end
#endif

static NSMutableArray *contactCells = nil;
static NSMutableArray *contactCellLabels = nil;

#ifdef THEOS
%hook SCMyContactsViewController
#endif

-(UITableViewCell*)tableView:(UITableView*)tableView
cellForRowAtIndexPath:(NSIndexPath*)indexPath{
    UITableViewCell *cell = %orig(tableView,indexPath);
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if([cell isKindOfClass:objc_getClass("SCFriendProfileCell")]){
            SCFriendProfileCell *friendCell = (SCFriendProfileCell*)cell;
            
            if(!contactCells){
                contactCells = [[NSMutableArray alloc] init];
            } if(!contactCellLabels){
                contactCellLabels = [[NSMutableArray alloc] init];
            }
            
            Friend *f = nil;
            
            if([friendCell respondsToSelector:@selector(cellView)]){
                SCFriendProfileCellView *friendCellView = friendCell.cellView;
                f = [friendCellView friend];
            } else if([friendCell respondsToSelector:@selector(currentFriend)]){
                f = [friendCell currentFriend];
            }
            
            if(f){
                SNLog(@"StreakNotify::contactsViewController:%@ friend found displaying timer",[f name]);
                Manager *manager = [objc_getClass("Manager") shared];
                User *user = [manager user];
                SCChats *chats = [user chats];
                SCChat *chat = [chats chatForUsername:[f name]];
                
                Snap *earliestUnrepliedSnap = FindEarliestUnrepliedSnapForChat(YES,chat);
                
                SNLog(@"StreakNotify::%@ is earliest unreplied snap %@",earliestUnrepliedSnap,[earliestUnrepliedSnap timestamp]);
                ConfigureCell(cell, contactCells, contactCellLabels, f, chat, earliestUnrepliedSnap);
            }else{
                SNLog(@"StreakNotify::contactsViewController: friend not found, no selector was found to find the model!");
            }
        }
    });
    
    
    return cell;
}

-(void)dealloc{
    SNLog(@"StreakNotify::Deallocating contactsViewController");
    [contactCells removeAllObjects];
    [contactCellLabels removeAllObjects];
    [contactCells release];
    [contactCellLabels release];
    contactCells = nil;
    contactCellLabels = nil;
    %orig();
}

#ifdef THEOS
%end
#endif

static NSMutableArray *storyCells = nil;
static NSMutableArray *storyCellLabels = nil;


#ifdef THEOS
%hook SCStoriesViewController
#endif

-(UITableViewCell*)tableView:(UITableView*)tableView
cellForRowAtIndexPath:(NSIndexPath*)indexPath{
    UITableViewCell *cell = %orig(tableView,indexPath);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        /* want to do this on the main thread because all ui updates should be done on the main thread
         this should already be on the main thread but we should make sure of this
         */
        
        if([cell isKindOfClass:objc_getClass("StoriesCell")]){
            StoriesCell *storiesCell = (StoriesCell*)cell;
            
            if(!storyCells){
                storyCells = [[NSMutableArray alloc] init];
            } if(!storyCellLabels){
                storyCellLabels = [[NSMutableArray alloc] init];
            }
            
            FriendStories *stories = storiesCell.friendStories;
            
            NSString *username = stories.username;
            
            Manager *manager = [objc_getClass("Manager") shared];
            User *user = [manager user];
            
            SCChats *chats = [user chats];
            Friends *friends = [user friends];
            
            SCChat *chat = [chats chatForUsername:username];
            Friend *f = [friends friendForName:username];
            
            // Friend *f = [feedItem friendForFeedItem];
            /* deprecated/removed in Snapchat 9.34.0 */
            
            Snap *earliestUnrepliedSnap = FindEarliestUnrepliedSnapForChat(YES,chat);
            
            SNLog(@"StreakNotify::%@ is earliest unreplied snap %@",earliestUnrepliedSnap,[earliestUnrepliedSnap timestamp]);
            
            if([storiesCell respondsToSelector:@selector(isTapToReplyMode)]
               && ![storiesCell isTapToReplyMode]){
                ConfigureCell(cell, storyCells, storyCellLabels, f, chat, earliestUnrepliedSnap);
            }else{
                UILabel *label = GetLabelFromCell(cell,storyCells,storyCellLabels);
                label.text = @"";
                label.hidden = YES;
            }
        }
    });
    
    
    return cell;
}

-(void)dealloc{
    SNLog(@"StreakNotify::Deallocating storiesViewController");
    [storyCells removeAllObjects];
    [storyCellLabels removeAllObjects];
    [storyCells release];
    [storyCellLabels release];
    storyCells = nil;
    storyCellLabels = nil;
    %orig();
}

#ifdef THEOS
%end
#endif

#ifdef THEOS
%hook SCSelectRecipientsView
#endif

-(UITableViewCell*)tableView:(UITableView*)tableView
cellForRowAtIndexPath:(NSIndexPath*)indexPath{
    UITableViewCell *cell = %orig(tableView,indexPath);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if([cell isKindOfClass:objc_getClass("SelectContactCell")]){
            SelectContactCell *contactCell = (SelectContactCell*)cell;
            Manager *manager = [objc_getClass("Manager") shared];
            User *user = [manager user];
            SCChats *chats = [user chats];
            
            Friend *f = [self getFriendAtIndexPath:indexPath];
            if(f && [f isKindOfClass:objc_getClass("Friend")]){
                SCChat *chat = [chats chatForUsername:[f name]];
                Snap *snap = FindEarliestUnrepliedSnapForChat(YES,chat);
                
                UILabel *label = contactCell.subNameLabel;
                NSString *text = TextForLabel(f,chat,snap);
                label.text = text;
                
                if([text isEqualToString:@""]){
                    label.hidden = YES;
                }else{
                    label.hidden = NO;
                }
            }
        }
    });
    return cell;
}


#ifdef THEOS
%end
#endif

static NSMutableArray *chatCells = nil;
static NSMutableArray *chatCellLabels = nil;

#ifdef THEOS
%hook SCChatTableViewDataSourceV2
#endif

-(UITableViewCell*)tableView:(UITableView*)tableView
cellForRowAtIndexPath:(NSIndexPath*)indexPath{
    UITableViewCell *cell = %orig(tableView, indexPath);
    dispatch_async(dispatch_get_main_queue(), ^{
        if([cell isKindOfClass:objc_getClass("SCSnapChatTableViewCellV2")]){
            SCSnapChatTableViewCellV2 *chatCell = (SCSnapChatTableViewCellV2*)cell;
            SCChatV2SnapChatTableViewCellViewModel *viewModel = (SCChatV2SnapChatTableViewCellViewModel*)chatCell.viewModel;
            Snap *message = viewModel.message;
            NSDate *date = [message timestamp];
            
            SCSnapMediaCardView *mediaCardView = MSHookIvar<SCSnapMediaCardView*>(chatCell, "_mediaCardView");
            
            SNLog(@"StreakNotify::%@ is the date for Snap",date);
            
            CGSize size = mediaCardView.frame.size;
            CGRect rect = CGRectMake(size.width*.1,
                                     size.height*.65,
                                     size.width/2.5,
                                     size.height/4);
            
            if(!chatCells){
                chatCells = [[NSMutableArray alloc] init];
            } if(!chatCellLabels){
                chatCellLabels = [[NSMutableArray alloc] init];
            }
            
            UILabel *label;
            
            if(![chatCells containsObject:cell]){
                label = [[UILabel alloc] initWithFrame:rect];
                label.textAlignment = NSTextAlignmentLeft;
                
                
                [chatCells addObject:cell];
                [chatCellLabels addObject:label];
                
                [mediaCardView addSubview:label];
            }else {
                label = [chatCellLabels objectAtIndex:[chatCells indexOfObject:cell]];
            }
            
            label.frame = rect;
            
            NSCalendar* calendar = [NSCalendar currentCalendar];
            
            BOOL today = [calendar isDateInToday:date];
            BOOL yesterday = [calendar isDateInYesterday:date];
            
            NSString *timeSinceSnap = nil;
            
            if(today){
                NSUInteger unitFlags = NSSecondCalendarUnit | NSMinuteCalendarUnit | NSHourCalendarUnit | NSDayCalendarUnit;
                NSDateComponents *components = [calendar components:unitFlags
                                                           fromDate:date
                                                             toDate:[NSDate date]
                                                            options:0];
                NSInteger hour = [components hour];
                NSInteger minute = [components minute];
                NSInteger second = [components second];
                
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"hh:mm a"];
                NSString *clockTime = [dateFormatter stringFromDate:date];
                
                if(hour){
                    timeSinceSnap = [NSString stringWithFormat:@"%ld hour%@ ago at %@",(long)hour,hour==1 ? @"" : @"s",clockTime];
                }else if(minute){
                    timeSinceSnap = [NSString stringWithFormat:@"%ld minute%@ ago at %@",(long)minute,minute==1 ? @"" : @"s",clockTime];
                }else if(second){
                    timeSinceSnap = [NSString stringWithFormat:@"%ld second%@ ago at %@",(long)second,second==1 ? @"" : @"s",clockTime];
                }
                
            }else if(yesterday){
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"hh:mm a"];
                NSString *clockTime = [dateFormatter stringFromDate:date];
                timeSinceSnap = [NSString stringWithFormat:@"Yesterday %@",clockTime];
            }else{
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"MMM dd, YYYY hh:mm a"];
                timeSinceSnap = [dateFormatter stringFromDate:date];
            }
            label.text = timeSinceSnap;
            SizeLabelToRect(label,label.frame);
        }
    });
    return cell;
}

-(void)dealloc{
    [chatCells removeAllObjects];
    [chatCellLabels removeAllObjects];
    [chatCells release];
    [chatCellLabels release];
    chatCells = nil;
    chatCellLabels = nil;
    %orig();
}

#ifdef THEOS
%end
%end
#else
// @end
#endif



#ifdef THEOS
%ctor
#else
void constructor()
#endif
{
    
    /*
     *  Coming from MobileLoader, which loads into Snapchat via the DYLD_INSERT_LIBRARIES
     *  variable. Let's start doing some fun hooks into Snapchat to keep the streak going
     *  I don't know why I made this, I just found that people took streaks seriously, so
     *  might as well. A tweak like this isn't that serious so why not make it open source
     */
    
    LoadPreferences();
    if(![prefs[@"kStreakNotifyDisabled"] boolValue]){
        // Class Friend = objc_getClass("Friend");
        // Was going to create a unconventional hook to Friend but SOJUFriendmoji saved my ass
        
        %init(SnapchatHooks);
        // this has to be done otherwise our hooks would not be used!
        
    }
}

#ifdef THEOS
%dtor
#else
void deconstructor()
#endif
{
    
}
