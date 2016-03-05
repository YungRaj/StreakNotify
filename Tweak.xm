
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

#import "Interfaces.h"

#define kiOS7 (kCFCoreFoundationVersionNumber >= 847.20 && kCFCoreFoundationVersionNumber <= 847.27)
#define kiOS8 (kCFCoreFoundationVersionNumber >= 1140.10 && kCFCoreFoundationVersionNumber >= 1145.15)
#define kiOS9 (kCFCoreFoundationVersionNumber == 1240.10)


static NSDictionary* prefs = nil;
static CFStringRef applicationID = CFSTR("com.YungRaj.streaknotify");

static void LoadPreferences() {
    if (CFPreferencesAppSynchronize(applicationID)) {
        CFArrayRef keyList = CFPreferencesCopyKeyList(applicationID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) ?: CFArrayCreate(NULL, NULL, 0, NULL);
        if (access("/var/mobile/Library/Preferences/com.YungRaj.streaknotify", F_OK) != -1) {
            prefs = (__bridge NSDictionary *)CFPreferencesCopyMultiple(keyList, applicationID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        } else {
            prefs = @{@"kTwelveHours" : @YES,
                      @"kFiveHours" : @YES,
                      @"kOneHour" : @YES,
                      @"kTenMinutes" : @YES};
        }
        
        CFRelease(keyList);
    }
}

static void SizeLabelToRect(UILabel *label, CGRect labelRect){
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
        
        fontSize -= 2;
        
    } while (fontSize > minFontSize);
}


static NSString* GetTimeRemaining(Friend *f, SCChat *c){
    if(!f || !c){
        return @"";
    }
    
    NSDate *date = [NSDate date];
    Snap *lastSnap = [c lastSnap];
    
    NSDate *latestSnapDate = [lastSnap timestamp];
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
    
    if(day){
        return @"Limited";
    }else if(hour){
        return [NSString stringWithFormat:@"%ld hr",(long)hour];
    }else if(minute){
        return [NSString stringWithFormat:@"%ld m",(long)minute];
    }else if(second){
        return [NSString stringWithFormat:@"%ld s",(long)second];
    }else{
        return @"Unknown";
    }
    
                                   
    
}

%group iOS9


%hook AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions{
    
    [application cancelAllLocalNotifications];
    UIUserNotificationType types = UIUserNotificationTypeBadge |
    UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    
    UIUserNotificationSettings *mySettings =
    [UIUserNotificationSettings settingsForTypes:types categories:nil];
    
    [application registerUserNotificationSettings:mySettings];
    return %orig();
}

%end

%hook Snap

-(void)didSend{
    Manager *manager = [%c(Manager) shared];
    User *user = [manager user];
    Friends *friends = [user friends];
    SCChats *chats = [user chats];
    
    
    NSString *recipient = [self recipient];
    
    
    SCChat *chat = [chats chatForUsername:recipient];
    Friend *f = [friends friendForName:recipient];
    
    %log(chat,f);
    
    NSString *displayName = [friends displayNameForUsername:recipient];
    
    NSArray *localNotifications = [[UIApplication sharedApplication] scheduledLocalNotifications];
    
    for(UILocalNotification *localNotification in localNotifications){
        if([localNotification.alertBody containsString:displayName]){
            [[UIApplication sharedApplication] cancelLocalNotification:localNotification];
        }
    }
            
           
}


%end


static NSMutableArray *instances = nil;
static NSMutableArray *labels = nil;


%hook SCFeedViewController


-(SCFeedTableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath{
    
    SCFeedTableViewCell *cell = %orig(tableView,indexPath);
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if(!instances){
            instances = [[NSMutableArray alloc] init];
        } if(!labels){
            labels = [[NSMutableArray alloc] init];
        }
        
        Manager *manager = [%c(Manager) shared];
        User *user = [manager user];
        Friends *friends = [user friends];
        
        SCChatViewModelForFeed *feedItem = cell.feedItem;
        SCChat *chat = [feedItem chat];
        
        NSString *recipient = [chat recipient];
        
        Friend *f = [friends friendForName:recipient];
        
        NSString *lastSnapSender = [[chat lastSnap] sender];
        
        NSString *friendName = [f name];
        
        UILabel *label;
        
        
        if(![instances containsObject:cell]){
            
            CGSize size = cell.frame.size;
            CGRect rect = CGRectMake(size.width*.55,
                                     size.height/8,
                                     size.width/4,
                                     size.height/4);
            label = [[UILabel alloc] initWithFrame:rect];
            
            [instances addObject:cell];
            [labels addObject:label];
            
            [cell.containerView addSubview:label];
            
            
        }else {
            label = [labels objectAtIndex:[instances indexOfObject:cell]];
        }
        
        if([f snapStreakCount]>2 && [lastSnapSender isEqual:friendName]){
            label.text = [NSString stringWithFormat:@"Time remaining: %@",GetTimeRemaining(f,chat)];
            SizeLabelToRect(label,label.frame);
            label.hidden = NO;
        }else {
            label.text = @"";
            label.hidden = YES;
        }
    });
    
    return cell;
}


-(void)didFinishReloadData{
    %orig();
    Manager *manager = [%c(Manager) shared];
    User *user = [manager user];
    Friends *friends = [user friends];
    SCChats *chats = [user chats];
    
    
    for(SCChat *chat in [chats allChats]){
        NSDate *snapDate = [[chat lastSnap] timestamp];
        Friend *f = [friends friendForName:[chat recipient]];
        NSString *lastSnapSender = [[chat lastSnap] sender];
        NSString *friendName = [f name];
        if([f snapStreakCount]<=0 && ![lastSnapSender isEqual:friendName]){
            continue;
        }
        
        NSString *displayName = [friends displayNameForUsername:[chat recipient]];
        if([prefs[@"kTwelveHours"] boolValue]){
            NSDate *notificationDate =
                                [[NSDate alloc] initWithTimeInterval:60*60*24 - 60*60*12
                                                        sinceDate:snapDate];
            UILocalNotification *notification = [[UILocalNotification alloc] init];
            notification.fireDate = notificationDate;
            notification.alertBody = [NSString stringWithFormat:@"Reply to streak with %@. 12 hours left!",displayName];
            [[UIApplication sharedApplication] scheduleLocalNotification:notification];
            
        } if([prefs[@"kFiveHours"] boolValue]){
            NSDate *notificationDate =
            [[NSDate alloc] initWithTimeInterval:60*60*24 - 60*60*5
                                       sinceDate:snapDate];
            UILocalNotification *notification = [[UILocalNotification alloc] init];
            notification.fireDate = notificationDate;
            notification.alertBody = [NSString stringWithFormat:@"Reply to streak with %@. 5 hours left!",displayName];
            [[UIApplication sharedApplication] scheduleLocalNotification:notification];
            
        } if([prefs[@"kOneHour"] boolValue]){
            NSDate *notificationDate =
            [[NSDate alloc] initWithTimeInterval:60*60*24 - 60*60
                                       sinceDate:snapDate];
            UILocalNotification *notification = [[UILocalNotification alloc] init];
            notification.fireDate = notificationDate;
            notification.alertBody = [NSString stringWithFormat:@"Reply to streak with %@. 1 hour left!",displayName];
            [[UIApplication sharedApplication] scheduleLocalNotification:notification];
            
        } if([prefs[@"kTenMinutes"] boolValue]){
            NSDate *notificationDate =
            [[NSDate alloc] initWithTimeInterval:60*60*24 - 60*10
                                       sinceDate:snapDate];
            UILocalNotification *notification = [[UILocalNotification alloc] init];
            notification.fireDate = notificationDate;
            notification.alertBody = [NSString stringWithFormat:@"Reply to streak with %@. 10 minutes left!",displayName];
            [[UIApplication sharedApplication] scheduleLocalNotification:notification];
            
        }
    }
    
    
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
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    (CFNotificationCallback)LoadPreferences,
                                    CFSTR("YungRajStreakNotifyDeletePreferencesChangedNotification"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    prefs = @{@"kTwelveHours" : @YES,
              @"kFiveHours" : @YES,
              @"kOneHour" : @YES,
              @"kTenMinutes" : @YES};

    
    if (kiOS9)
        %init(iOS9);
    if (kiOS8)
        %init(iOS8);
    if (kiOS7)
        %init(iOS7)
}
