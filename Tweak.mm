/*
This tweak notifies a user when a snapchat streak with another friend is running down in time. It also tells a user how much time is remanining in their feed. Customizable with a bunch of settings, custom time, custom friends, and even preset values that you can enable with a switch in preferences. Auto-send snap will be implemented soon so that the streak is kept with a person
 
*/

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <rocketbootstrap/rocketbootstrap.h>

#import "Interfaces.h"

#define kiOS7 (kCFCoreFoundationVersionNumber >= 847.20 && kCFCoreFoundationVersionNumber <= 847.27)
#define kiOS8 (kCFCoreFoundationVersionNumber >= 1140.10 && kCFCoreFoundationVersionNumber >= 1145.15)
#define kiOS9 (kCFCoreFoundationVersionNumber == 1240.10)


static NSString *snapchatVersion = nil;
static NSDictionary *prefs = nil;
static NSMutableArray *customFriends = nil;
static UIImage *autoReplySnapstreakImage = nil;
// static CFStringRef applicationID = CFSTR("com.YungRaj.streaknotify");


/* load preferences and the custom friends that we must apply notifications to */
/* load the true values from the customFriends plist into an array so that they can be searched quicker
    make sure the custom friends and the prefs objects are memory managed properly otherwise we will have a memory leak or a dangling pointer
 */
/* load the image that the user wants to auto reply to a streak to */

static void LoadPreferences() {
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

/* gets the earliest snap that wasn't replied to, it is important to do that because a user can just send a snap randomly and reset the 24 hours. basically forces you to respond if you just keep opening messages 
   this is a better solution than the private SnapStreakData class that the app uses in the new chat 2.0 update
 */

Snap* FindEarliestUnrepliedSnapForChat(BOOL receive, SCChat *chat){
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

/* sends the request to the daemon of the different names of the friends and their corresponding friendmoji */
/* triggered when the application is open, coming from the background, or when the friends values change */

static void SendRequestToDaemon(){
    NSLog(@"StreakNotify::Sending request to Daemon");
    
    CPDistributedMessagingCenter *c = [CPDistributedMessagingCenter centerNamed:@"com.YungRaj.streaknotifyd"];
    rocketbootstrap_unlock("com.YungRaj.streaknotifyd");
    rocketbootstrap_distributedmessagingcenter_apply(c);
    [c sendMessageName:@"tweak-daemon"
              userInfo:GetFriendmojis()];
}

static void SizeLabelToRect(UILabel *label, CGRect labelRect){
    /* utility method to make sure that the label's size doesn't truncate the text that it is supposed to display */
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
        
        fontSize -= 0.5;
        
    } while (fontSize > minFontSize);
}


static
NSString*
GetTimeRemaining(Friend *f,SCChat *c,Snap *earliestUnrepliedSnap){
    
    /* good utility method to figure out the time remaining for the streak
     
     in the new chat 2.0 update to snapchat, the SOJUFriend and SOJUFriendBuilder class now sets a property called snapStreakExpiration/snapStreakExpiryTime which is basically a long long value that describes the time in seconds since 1970 of when the snap streak should end when that expiration date arrives.
     
     if I decide to support only the newest revisions of Snapchat, then I will implement it this way. however even though in the last revisions of Snapchat that API wasn't there it could be possible that it was private and thus not available on headers dumped via class-dump.
     
     for now I am just using 24 hours past the earliest snap sent that wasn't replied to
     */
    if(!f || !c){
        return @"";
    }
    
    NSDate *date = [NSDate date];
    
    
    NSDate *latestSnapDate = [earliestUnrepliedSnap timestamp];
    int daysToAdd = 1;
    NSDate *latestSnapDateDayAfter = [latestSnapDate dateByAddingTimeInterval:60*60*24*daysToAdd];
    NSCalendar *gregorianCal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSUInteger unitFlags = NSSecondCalendarUnit | NSMinuteCalendarUnit |NSHourCalendarUnit | NSDayCalendarUnit;
    NSDateComponents *components = [gregorianCal components:unitFlags
                                                fromDate:date
                                                  toDate:latestSnapDateDayAfter
                                                 options:0];
    NSInteger day = [components day];
    NSInteger hour = [components hour];
    NSInteger minute = [components minute];
    NSInteger second = [components second];
    
    if(day<0 || hour<0 || minute<0 || second<0){
        return @"Limited";
        /*this means that the last snap + 24 hours later is earlier than the current time... and a streak is still valid assuming that the function that called this checked for a valid streak
         in the new chat 2.0 update the new properties introduced into the public API for the SOJUFriend and SOJUFriendBuilder class allow us to know when the server will end the streak
         if I use snapStreakExpiration/snapStreakExpiryTime then this shouldn't happen unless there's a bug in the Snapchat application
         this API isn't available (or public) so for previous versions of Snapchat this would not work
         */
    }
    
    if(day){
        return [NSString stringWithFormat:@"%ldd",(long)day];
    }else if(hour){
        return [NSString stringWithFormat:@"%ld hr",(long)hour];
    }else if(minute){
        return [NSString stringWithFormat:@"%ld m",(long)minute];
    }else if(second){
        return [NSString stringWithFormat:@"%ld s",(long)second];
    }
    /* this shouldn't happen but to shut the compiler up this is needed */
    return @"Unknown";
}

/* easier to read when viewing the code, can call [application cancelAllLocalNotfiications] though */
static void CancelScheduledLocalNotifications(){
    UIApplication *application = [UIApplication sharedApplication];
    NSArray *scheduledLocalNotifications = [application scheduledLocalNotifications];
    for(UILocalNotification *notification in scheduledLocalNotifications){
        [application cancelLocalNotification:notification];
    }
}

static void ScheduleNotification(NSDate *snapDate,
                                 Friend *f,
                                 float seconds,
                                 float minutes,
                                 float hours){
    /* schedules the notification and makes sure it isn't before the current time */
    NSString *displayName = f.display;
    NSString *username = f.name;
    if([customFriends count] && ![customFriends containsObject:displayName]){
        NSLog(@"StreakNotify:: Not scheduling notification for %@, not enabled in custom friends!",displayName);
        return;
    }
    float t = hours ? hours : minutes ? minutes : seconds;
    NSString *time =  hours ? @"hours" : minutes ? @"minutes" : @"seconds";
    NSDate *notificationDate =
    [[NSDate alloc] initWithTimeInterval:60*60*24 - 60*60*hours - 60*minutes - seconds
                               sinceDate:snapDate];
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.fireDate = notificationDate;
    notification.alertBody = [NSString stringWithFormat:@"Keep streak with %@. %ld %@ left!",displayName,(long)t,time];
    notification.userInfo = @{@"Username" : username};
    NSDate *latestDate = [notificationDate laterDate:[NSDate date]];
    if(latestDate==notificationDate){
        [[UIApplication sharedApplication] scheduleLocalNotification:notification];
        NSLog(@"StreakNotify:: Scheduling notification for %@, firing at %@",displayName,[notification fireDate]);
    }
}

static void ResetNotifications(){
    /* ofc set the local notifications based on the preferences, good utility function that is commonly used in the tweak
     */
    
    CancelScheduledLocalNotifications();
    Manager *manager = [objc_getClass("Manager") shared];
    User *user = [manager user];
    Friends *friends = [user friends];
    SCChats *chats = [user chats];
    
    for(SCChat *chat in [chats allChats]){
        
        Snap *earliestUnrepliedSnap = FindEarliestUnrepliedSnapForChat(YES,chat);
        NSDate *snapDate = [earliestUnrepliedSnap timestamp];
        Friend *f = [friends friendForName:[chat recipient]];
        
        NSLog(@"StreakNotify:: %@ for %@",snapDate,[chat recipient]);
        
        if([f snapStreakCount]>2 && earliestUnrepliedSnap){
            if([prefs[@"kTwelveHours"] boolValue]){
                ScheduleNotification(snapDate,f,0,0,12);
                
            } if([prefs[@"kFiveHours"] boolValue]){
                ScheduleNotification(snapDate,f,0,0,5);
                
            } if([prefs[@"kOneHour"] boolValue]){
                ScheduleNotification(snapDate,f,0,0,1);
                
            } if([prefs[@"kTenMinutes"] boolValue]){
                ScheduleNotification(snapDate,f,0,10,0);
            }
            
            float seconds = [prefs[@"kCustomSeconds"] floatValue];
            float minutes = [prefs[@"kCustomMinutes"] floatValue];
            float hours = [prefs[@"kCustomHours"] floatValue] ;
            if(hours || minutes || seconds){
                ScheduleNotification(snapDate,f,seconds,minutes,hours);
            }
        }
    }
    
    NSLog(@"StreakNotify:: Resetting notifications success %@",[[UIApplication sharedApplication] scheduledLocalNotifications]);
}

static void ConfigureCell(UITableViewCell *cell,
                          NSMutableArray *instances,
                          NSMutableArray *labels,
                          Friend *f,
                          SCChat *chat,
                          Snap *snap){
    UILabel *label;
    
    if(![instances containsObject:cell]){
        
        CGSize size = cell.frame.size;
        CGRect rect = CGRectMake(size.width*.83,
                                 size.height*.7,
                                 size.width/8,
                                 size.height/4);
        
        label = [[UILabel alloc] initWithFrame:rect];
        
        [instances addObject:cell];
        [labels addObject:label];
        
        [cell addSubview:label];
        
        
    }else {
        label = [labels objectAtIndex:[instances indexOfObject:cell]];
    }
    
    if([f snapStreakCount]>2 && snap){
        label.text = [NSString stringWithFormat:@"⏰ %@",GetTimeRemaining(f,chat,snap)];
        SizeLabelToRect(label,label.frame);
        label.hidden = NO;
    }else if([f snapStreakCount]>2){
        Snap *sentUnrepliedSnap = FindEarliestUnrepliedSnapForChat(NO,chat);
        label.text = [NSString stringWithFormat:@"⌛️ %@",GetTimeRemaining(f,chat,sentUnrepliedSnap)];
        SizeLabelToRect(label,label.frame);
        label.hidden = NO;
    }else{
        label.text = @"";
        label.hidden = YES;
    }
}

void SendAutoReplySnapToUser(NSString *username){
    UIImage *image = [UIImage imageWithContentsOfFile:@"/var/mobile/Documents/streaknotify_autoreply.jpeg"];
    if(image){
        Snap *snap = [[objc_getClass("Snap") alloc] init];
        snap.media.mediaDataToUpload = UIImageJPEGRepresentation(image,0.7);
        snap.media.captionText = prefs[@"kAutoReplySnapstreakCaption"];
        snap.recipient = username;
        
        NSLog(@"StreakNotify:: Snap has been created successfully, preparing to send");
        
        /* todo gotta figure out how to configure the snap that I want to send before it can be sent, right now we have the recipient and the image that we want to send but there are more routines to be done before it can be sent successfully */
        
        [snap send];
        NSLog(@"StreakNotify:: Snap has been requested to send");
    }
    
}

/* a remote notification has been sent from the APNS server and we must let the app know so that it can schedule a notification for the chat */
/* we need to fetch updates so that the new snap can be found */
/* otherwise we won't be able to set the notification properly because the new snap or message hasn't been tracked by the application */

void HandleRemoteNotification(){
    Manager *manager = [objc_getClass("Manager") shared];
    if([manager respondsToSelector:@selector(fetchUpdatesWithCompletionHandler:
                                             includeStories:
                                             didHappendWhenAppLaunch:)]){
        [[objc_getClass("Manager") shared] fetchUpdatesWithCompletionHandler:^{
            NSLog(@"StreakNotify:: Finished fetching updates, resetting local notifications");
            ResetNotifications();
        }
                                                              includeStories:YES
                                                     didHappendWhenAppLaunch:YES];
        // Snapchat 9.40 and less
        
    }else{
        
        [[objc_getClass("Manager") shared] fetchUpdatesWithCompletionHandler:^{
            NSLog(@"StreakNotify:: Finished fetching updates, resetting local notifications");
            ResetNotifications();
        }
                                                              includeStories:YES
                                                        includeConversations:YES
                                                     didHappendWhenAppLaunch:YES];
        // Snapchat 9.40 and greater
    }
}

void HandleLocalNotification(NSString *username){
    NSLog(@"StreakNotify:: Handling local notification, sending auto reply snap to %@",username);
    /* handle local notification and send auto reply message for a streak */
    /* let's say that someone hasn't enabled custom friends and receives a notification, that means that we can send the auto reply snap regardless... if custom friends is enabled for the friend the notification wouldn't have been scheduled in the first place without it being enabled in custom friends */
    if(prefs[@"kAutoReplySnapstreak"]){
        SendAutoReplySnapToUser(username);
    }
    
}

#ifdef THEOS
%group SnapchatHooks
%hook MainViewController
#else
@interface SnapchatHooks
#endif

-(void)viewDidLoad{
    /* easy way to tell the user that they haven't configured any settings, let's make sure that they know that so that can customize how they want to their notifications for streaks to work
     it's ok if the custom friends hasn't been configured because it's ok for none to be selected
     */
    
    %orig();
    if(!prefs) {
        NSLog(@"StreakNotify:: No preferences found on file, letting user know");
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
                                       prefs = @{@"kTwelveHours" : @NO,
                                                 @"kFiveHours" : @NO,
                                                 @"kOneHour" : @NO,
                                                 @"kTenMinutes" : @NO,
                                                 @"kCustomHours" : @"0",
                                                 @"kCustomMinutes" : @"0",
                                                 @"kCustomSeconds" : @"0"};
                                   }];
            [controller addAction:cancel];
            [controller addAction:ok];
            [self presentViewController:controller animated:NO completion:nil];
        } else{
            NSLog(@"StreakNotify:: UIAlertController class not available, iOS 9 and earlier");
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

#ifdef THEOS
%new
#endif

-(void)alertView:(UIAlertView *)alertView
clickedButtonAtIndex:(NSInteger)buttonIndex{
    if(buttonIndex==0){
        NSLog(@"StreakNotify:: using default preferences");
        NSDictionary *preferences = [@{@"kTwelveHours" : @YES,
                                      @"kFiveHours" : @NO,
                                      @"kOneHour" : @NO,
                                      @"kTenMinutes" : @NO,
                                      @"kCustomHours" : @"1",
                                      @"kCustomMinutes" : @"1",
                                      @"kCustomSeconds" : @"1"} retain] ;
        [preferences writeToFile:@"/var/mobile/Library/Preferences/com.YungRaj.streaknotify.plist" atomically:YES];
        prefs = preferences;
        NSLog(@"StreakNotify:: saved default preferences to file, default settings will now appear in the preferences bundle");
    }else {
        NSLog(@"StreakNotify:: exiting application - user denied default settings");
        exit(0);
    }
}

#ifdef THEOS
%end
#endif

#ifdef THEOS
%hook AppDelegate
#endif

-(BOOL)application:(UIApplication*)application
didFinishLaunchingWithOptions:(NSDictionary*)launchOptions{
    
    /* just makes sure that the app is registered for local notifications, might be implemented in the app but haven't explored it, for now just do this.
     */
    
    snapchatVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationSettings* notificationSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
    } else {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes: (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    }
    
    NSLog(@"StreakNotify:: Just launched application successfully, resetting local notifications for streaks");
    
    ResetNotifications();
    
    CPDistributedMessagingCenter *c = [CPDistributedMessagingCenter centerNamed:@"com.YungRaj.streaknotifyd"];
    rocketbootstrap_distributedmessagingcenter_apply(c);
    [c sendMessageName:@"applicationLaunched" userInfo:nil];
    
    SendRequestToDaemon();
    
    
    return %orig();
}

-(void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
    /* everytime we receive a snap or even a chat message, we want to make sure that the notifications are updated each time*/
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
    NSLog(@"StreakNotify:: Snapchat application exiting, daemon will handle the exit of the application");
    
    CPDistributedMessagingCenter *c = [CPDistributedMessagingCenter centerNamed:@"com.YungRaj.streaknotify"];
    rocketbootstrap_distributedmessagingcenter_apply(c);
    [c sendMessageName:@"applicationTerminated"
              userInfo:nil];
    %orig();
}

-(void)applicationDidBecomeActive:(UIApplication*)application
{
    LoadPreferences();
    ResetNotifications();
    SendRequestToDaemon();
    %orig();
}

#ifdef THEOS
%end
#endif


#ifdef THEOS
%hook Snap
#endif

/* the number has changed for the friend and now we must let the daemon know of the changes so that they can be saved to file */
-(void)setSnapStreakCount:(long long)snapStreakCount{
    %orig(snapStreakCount);
    
    SendRequestToDaemon();
}

/* call the chatsDidMethod on the chats object so that the SCFeedViewController tableview can reload safely */

-(void)postSend{
    %orig();
    NSLog(@"StreakNotify::snap to %@ has sent successfully",[self recipient])
    ;
    Manager *manager = [objc_getClass("Manager") shared];
    User *user = [manager user];
    SCChats *chats = [user chats];
    [chats chatsDidChange];
}


#ifdef THEOS
%end
#endif

static NSMutableArray *feedCells = nil;
static NSMutableArray *feedCellLabels = nil;

#ifdef THEOS
%hook SCFeedViewController
#endif


-(UITableViewCell*)tableView:(UITableView*)tableView
       cellForRowAtIndexPath:(NSIndexPath*)indexPath{
    
    /* updating tableview and we want to make sure the feedCellLabels are updated too, if not created if the feed is now being populated
    */
    
    UITableViewCell *cell = %orig(tableView,indexPath);
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        /* want to do this on the main thread because all ui updates should be done on the main thread
         this should already be on the main thread but we should make sure of this
        */
        
        if([cell isKindOfClass:objc_getClass("SCFeedTableViewCell")]
           && [cell respondsToSelector:@selector(viewModel)]){
            SCFeedTableViewCell *feedCell = (SCFeedTableViewCell*)cell;
            
            if(!feedCells){
                feedCells = [[NSMutableArray alloc] init];
            } if(!feedCellLabels){
                feedCellLabels = [[NSMutableArray alloc] init];
            }
            
            NSString *username = nil;
            if([[feedCell viewModel] isKindOfClass:objc_getClass("SCChatFeedCellViewModel")]){
                SCChatFeedCellViewModel *viewModel = (SCChatFeedCellViewModel*)feedCell.viewModel;
                username = [viewModel friendUsername];
            } else if([[feedCell viewModel] respondsToSelector:@selector(username)]){
                SCChatViewModelForFeed *viewModel = (SCChatViewModelForFeed*)feedCell.viewModel;
                username = [viewModel username];
            } else if([[feedCell viewModel] respondsToSelector:@selector(friendUsername)]){
                SCFeedChatCellViewModel *viewModel = (SCFeedChatCellViewModel*)feedCell.viewModel;
                username = [viewModel friendUsername];
            }
            
            if(username){
                NSLog(@"StreakNotify::%@ username found, showing label if possible",username);
                Manager *manager = [objc_getClass("Manager") shared];
                User *user = [manager user];
                
                SCChats *chats = [user chats];
                SCChat * chat = [chats chatForUsername:username];
                Friends *friends = [user friends];
                Friend *f = [friends friendForName:username];
                
                // Friend *f = [feedItem friendForFeedItem];
                /* deprecated/removed in Snapchat 9.34.0 */
                /* this caused the crash in that update */
                
                Snap *earliestUnrepliedSnap = FindEarliestUnrepliedSnapForChat(YES,chat);
                
                NSLog(@"StreakNotify::%@ is earliest unreplied snap %@",earliestUnrepliedSnap,[earliestUnrepliedSnap timestamp]);
                
                ConfigureCell(cell, feedCells, feedCellLabels, f, chat, earliestUnrepliedSnap);
            } else{
                NSLog(@"StreakNotify::username not found, Snapchat was updated and no selector was found");
                // todo: let the user know that the timer could not added to the cells
            }
        }
    });
    
    return cell;
}


-(void)didFinishReloadData{
    /* want to update notifications if something has changed after reloading data */
    NSLog(@"StreakNotify::Finished reloading data");
    %orig();
    ResetNotifications();
    
}


-(void)dealloc{
    NSLog(@"StreakNotify::Deallocating feedViewController");
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
                NSLog(@"StreakNotify::contactsViewController:%@ friend found displaying timer",[f name]);
                Manager *manager = [objc_getClass("Manager") shared];
                User *user = [manager user];
                SCChats *chats = [user chats];
                SCChat *chat = [chats chatForUsername:[f name]];
                
                Snap *earliestUnrepliedSnap = FindEarliestUnrepliedSnapForChat(YES,chat);
                
                NSLog(@"StreakNotify::%@ is earliest unreplied snap %@",earliestUnrepliedSnap,[earliestUnrepliedSnap timestamp]);
                ConfigureCell(cell, contactCells, contactCellLabels, f, chat, earliestUnrepliedSnap);
            }else{
                NSLog(@"StreakNotify::contactsViewController: friend not found, no selector was found to find the model!");
            }
        }
    });
    
    
    return cell;
}

-(void)dealloc{
    NSLog(@"StreakNotify::Deallocating contactsViewController");
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
            
            NSLog(@"StreakNotify::%@ is earliest unreplied snap %@",earliestUnrepliedSnap,[earliestUnrepliedSnap timestamp]);
            
            ConfigureCell(cell, storyCells, storyCellLabels, f, chat, earliestUnrepliedSnap);
            
        }
    });

    
    return cell;
}

-(void)dealloc{
    NSLog(@"StreakNotify::Deallocating storiesViewController");
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
%end
#else
@end
#endif

#ifdef THEOS
%ctor
#else
void constructor()
#endif
{
    
    /* constructor for the tweak, registers preferences stored in /var/mobile
     and uses the proper group based on the iOS version, might want to use Snapchat version instead but we'll see
     */
    
    LoadPreferences();
    if(![prefs[@"kStreakNotifyDisabled"] boolValue]){
        %init(SnapchatHooks);
        // this has to be done otherwise our hooks would not be used!
    }
}
