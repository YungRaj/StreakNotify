/*
This tweak notifies a user when a snapchat streak with another friend is running down in time. It also tells a user how much time is remanining in their feed. Customizable with a bunch of settings, custom time, custom friends, and even preset values that you can enable with a switch in preferences 
 
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


static NSDictionary *prefs = nil;
static NSMutableArray *customFriends = nil;
static CFStringRef applicationID = CFSTR("com.YungRaj.streaknotify");

NSString *kSnapDidSendNotification = @"snapDidSendNotification";



/* load preferences and the custom friends that we must apply notifications to */
/* load the true values from the customFriends plist into an array so that they can be searched quicker */

static void LoadPreferences() {
    if(!prefs){
        prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.YungRaj.streaknotify.plist"];
    }if(!customFriends){
        NSDictionary *friendmojiList = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.YungRaj.friendmoji.plist"];
        customFriends = [[NSMutableArray alloc] init];
        
        for(NSString *name in [friendmojiList allKeys]){
            if([friendmojiList[name] boolValue]){
                [customFriends addObject:name];
            }
        }
    }
}

/* gets the earliest snap that wasn't replied to, it is important to do that because a user can just send a snap randomly and reset the 24 hours */

Snap* FindEarliestUnrepliedSnapForChat(SCChat *chat){
    NSArray *snaps = [chat allSnapsArray];
    
    if(!snaps || ![snaps count]){
        return nil;
    }
        
    snaps = [snaps sortedArrayUsingComparator:^(id obj1, id obj2){
        if ([obj1 isKindOfClass:%c(Snap)] && [obj2 isKindOfClass:%c(Snap)]) {
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
        if([obj isKindOfClass:%c(Snap)]){
            Snap *snap = obj;
            NSString *sender = [snap sender];
            if(!sender){
                earliestUnrepliedSnap = nil;
            }else if(!earliestUnrepliedSnap && sender){
                earliestUnrepliedSnap = snap;
            }
        }
    }
        
    NSLog(@"%@ is the earliest unreplied snap",earliestUnrepliedSnap);
    return earliestUnrepliedSnap;
}

/*
this might be useful later in the future
static NSString* UsernameForDisplay(NSString *display){
    Manager *manager = [%c(Manager) shared];
    User *user = [manager user];
    Friends *friends = [user friends];
    for(Friend *f in [friends getAllFriends]){
        if([display isEqual:f.display]){
            return f.name;
        }
    }
    /* this shouldn't happen if the display variable is coming from the friendmojilist settings plist
    return nil;
}
*/

static NSDictionary* GetFriendmojis(){
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    
    NSMutableDictionary *friendsWithStreaks = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *friendsWithoutStreaks = [[NSMutableDictionary alloc] init];
 
    Manager *manager = [%c(Manager) shared];
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
    NSLog(@"Sending request to Daemon");
    
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
        
        CGSize labelSize = textRect.size;
        if( labelSize.height <= label.frame.size.height )
            break;
        
        fontSize -= 0.5;
        
    } while (fontSize > minFontSize);
}


static NSString* GetTimeRemaining(Friend *f, SCChat *c, Snap *earliestUnrepliedSnap){
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
         again this could happen because we don't know how the streaks start and end because as far as I've know the server does all the work for that... might have to ask someone more intelligent to figure out a way around this
         if I use snapStreakExpiration/snapStreakExpiryTime then this shouldn't happen unless there's a bug in the Snapchat application
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
    }else{
    /* this shouldn't happen but to shut the compiler up this is needed */
        return @"Unknown";
    }
    
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
                                 NSString *displayName,
                                 float seconds,
                                 float minutes,
                                 float hours){
    /* schedules the notification and makes sure it isn't before the current time */
    /* I could be doing this with snapStreakExpiryTime and not have to check for this condition */
    if([customFriends count] && ![customFriends containsObject:displayName]){
        NSLog(@"Not scheduling notification for %@, not enabled in custom friends!",displayName);
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
    NSDate *latestDate = [notificationDate laterDate:[NSDate date]];
    if(latestDate==notificationDate){
        [[UIApplication sharedApplication] scheduleLocalNotification:notification];
        NSLog(@"Scheduling notification for %@, firing at %@",displayName,[notification fireDate]);
    }
}

static void ResetNotifications(){
    /* ofc set the local notifications based on the preferences, good utility function that is commonly used in the tweak
     */
    
    CancelScheduledLocalNotifications();
    Manager *manager = [%c(Manager) shared];
    User *user = [manager user];
    Friends *friends = [user friends];
    SCChats *chats = [user chats];
    
    for(SCChat *chat in [chats allChats]){
        
        Snap *earliestUnrepliedSnap = FindEarliestUnrepliedSnapForChat(chat);
        NSDate *snapDate = [earliestUnrepliedSnap timestamp];
        Friend *f = [friends friendForName:[chat recipient]];
        
        NSLog(@"%@ snapDate for %@",snapDate,[chat recipient]);
        
        if([f snapStreakCount]>2 && earliestUnrepliedSnap){
            NSString *displayName = [friends displayNameForUsername:[chat recipient]];
            if([prefs[@"kTwelveHours"] boolValue]){
                ScheduleNotification(snapDate,displayName,0,0,12);
                
            } if([prefs[@"kFiveHours"] boolValue]){
                ScheduleNotification(snapDate,displayName,0,0,5);
                
            } if([prefs[@"kOneHour"] boolValue]){
                ScheduleNotification(snapDate,displayName,0,0,1);
                
            } if([prefs[@"kTenMinutes"] boolValue]){
                ScheduleNotification(snapDate,displayName,0,10,0);
            }
            
            float seconds = [prefs[@"kCustomSeconds"] floatValue];
            float minutes = [prefs[@"kCustomMinutes"] floatValue];
            float hours = [prefs[@"kCustomHours"] floatValue] ;
            if(hours || minutes || seconds){
                ScheduleNotification(snapDate,displayName,seconds,minutes,hours);
            }
        }
    }
    
    NSLog(@"Resetting notifications success");
}

/* a remote notification has been sent from the APNS server and we must let the app know so that it can schedule a notification for the chat */
/* we need to fetch updates so that the new snap can be found */
/* otherwise we won't be able to set the notification properly because the new snap or message hasn't been tracked by the application */
void handleRemoteNotification(){
    NSLog(@"Resetting local notifications");
    [[%c(Manager) shared] fetchUpdatesWithCompletionHandler:^(BOOL success){
        NSLog(@"Finished fetching updates, resetting local notifications");
        ResetNotifications();
    }
                                            includeStories:NO
                                    didHappendWhenAppLaunch:YES];
}

%group iOS9

%hook MainViewController

-(void)viewDidLoad{
    
    /* easy way to tell the user that they haven't configured any settings, let's make sure that they know that so that can customize how they want to their notifications for streaks to work
     */
    
    NSLog(@"No preferences found on file, letting user know");
    
    %orig();
    if(!prefs) {
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
        
        
    }
}

%end

%hook AppDelegate


-(BOOL)application:(UIApplication*)application
didFinishLaunchingWithOptions:(NSDictionary*)launchOptions{
    
    /* just makes sure that the app is registered for local notifications, might be implemented in the app but haven't explored it, for now just do this.
     */
    
    UIUserNotificationType types = UIUserNotificationTypeBadge |
    UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    
    UIUserNotificationSettings *mySettings =
    [UIUserNotificationSettings settingsForTypes:types categories:nil];
    
    [application registerUserNotificationSettings:mySettings];
    
    NSLog(@"Just launched application successfully, resetting local notifications for streaks");
    
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
    handleRemoteNotification();
    %orig();
}

-(void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"Snapchat application exiting, daemon will handle the exit of the application");
    
    CPDistributedMessagingCenter *c = [CPDistributedMessagingCenter centerNamed:@"com.YungRaj.streaknotify"];
    rocketbootstrap_distributedmessagingcenter_apply(c);
    [c sendMessageName:@"applicationTerminated"
              userInfo:nil];
    %orig();
}

-(void)applicationDidBecomeActive:(UIApplication*)application
{
    ResetNotifications();
    SendRequestToDaemon();
    %orig();
}


%end


static NSMutableArray *instances = nil;
static NSMutableArray *labels = nil;



%hook Snap

/* the number has changed for the friend and now we must let the daemon know of the changes so that they can be saved to file */
-(void)setSnapStreakCount:(long long)snapStreakCount{
    %orig(snapStreakCount);
    
    SendRequestToDaemon();
}

-(void)doSend{
    %orig();
    
    NSLog(@"Post send snap");
          
    Manager *manager = [%c(Manager) shared];
    User *user = [manager user];
    SCChats *chats = [user chats];
    [chats chatsDidChange];
}


%end

%hook SCFeedViewController


-(UITableViewCell*)tableView:(UITableView*)tableView
       cellForRowAtIndexPath:(NSIndexPath*)indexPath{
    
    /* updating tableview and we want to make sure the labels are updated too, if not created if the feed is now being populated
     */
    
    UITableViewCell *cell = %orig(tableView,indexPath);
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        /* want to do this on the main thread because all ui updates should be done on the main thread
         this should already be on the main thread but we should make sure of this
         */
        
        if([cell isKindOfClass:%c(SCFeedTableViewCell)]){
            SCFeedTableViewCell *feedCell = (SCFeedTableViewCell*)cell;
            
            if(!instances){
                instances = [[NSMutableArray alloc] init];
            } if(!labels){
                labels = [[NSMutableArray alloc] init];
            }
            
            SCChatViewModelForFeed *feedItem = feedCell.feedItem;
            SCChat *chat = [feedItem chat];
            Friend *f = [feedItem friendForFeedItem];
            
            
            Snap *earliestUnrepliedSnap = FindEarliestUnrepliedSnapForChat(chat);
            
            NSLog(@"%@ is earliest unreplied snap %@",earliestUnrepliedSnap,[earliestUnrepliedSnap timestamp]);
            
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
                
                [feedCell.containerView addSubview:label];
                
                
            }else {
                label = [labels objectAtIndex:[instances indexOfObject:cell]];
            }
            
            if([f snapStreakCount]>2 && earliestUnrepliedSnap){
                label.text = [NSString stringWithFormat:@"⏰ %@",GetTimeRemaining(f,chat,earliestUnrepliedSnap)];
                SizeLabelToRect(label,label.frame);
                label.hidden = NO;
            }else {
                label.text = @"";
                label.hidden = YES;
            }
        }
    });
    
    return cell;
}


-(void)didFinishReloadData{
    /* want to update notifications if something has changed after reloading data */
    %orig();
    ResetNotifications();
    
}


-(void)dealloc{
    [instances removeAllObjects];
    [labels removeAllObjects];
    %orig();
}



%end

%end

%group iOS8

%end

%group iOS7

%end


%ctor {
    
    /* constructor for the tweak, registers preferences stored in /var/mobile
     and uses the proper group based on the iOS version, might want to use Snapchat version instead but we'll see
     */
    
    
    
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    (CFNotificationCallback)LoadPreferences,
                                    CFSTR("YungRajStreakNotifyPreferencesChangedNotification"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    LoadPreferences();
    

    
    if (kiOS9)
        %init(iOS9);
}
