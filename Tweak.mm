
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

NSString *kSnapDidSendNotification = @"snapDidSendNotification";

static void LoadPreferences() {
    prefs = [NSMutableDictionary dictionaryWithContentsOfFile: @"/var/mobile/Library/Preferences/com.YungRaj.streaknotify.plist"];
    
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
    
    if(!lastSnap){
        return @"";
    }
    
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
    
    if(day<0 || hour<0 || minute<0 || second<0){
        return @"Limited";
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
        return @"Unknown";
    }
    
}

static void ScheduleNotification(NSDate *snapDate,
                                 NSString *displayName,
                                 int seconds,
                                 int minutes,
                                 int hours){
    float t = hours ? hours : minutes ? minutes : seconds;
    NSString *time =  hours ? @"hours" : minutes ? @"minutes" : @"seconds";
    NSDate *notificationDate =
    [[NSDate alloc] initWithTimeInterval:60*60*24 - 60*60*hours - 60*minutes - seconds
                               sinceDate:snapDate];
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.fireDate = notificationDate;
    notification.alertBody = [NSString stringWithFormat:@"Reply to streak with %@. %ld %@ left!",displayName,(long)t,time];
    NSDate *latestDate = [notificationDate laterDate:[NSDate date]];
    if(latestDate==notificationDate){
        [[UIApplication sharedApplication] scheduleLocalNotification:notification];
    }
}

static void ResetNotifications(){
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    Manager *manager = [%c(Manager) shared];
    User *user = [manager user];
    Friends *friends = [user friends];
    SCChats *chats = [user chats];
    
    for(SCChat *chat in [chats allChats]){
        NSDate *snapDate = [[chat lastSnap] timestamp];
        Friend *f = [friends friendForName:[chat recipient]];
        NSString *lastSnapSender = [[chat lastSnap] sender];
        NSString *friendName = [f name];
        
        if([f snapStreakCount]>2 && [lastSnapSender isEqual:friendName]){
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
}

%group iOS9

%hook MainViewController

-(void)viewDidLoad{
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

-(BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions{
    
    UIUserNotificationType types = UIUserNotificationTypeBadge |
    UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    
    UIUserNotificationSettings *mySettings =
    [UIUserNotificationSettings settingsForTypes:types categories:nil];
    
    [application registerUserNotificationSettings:mySettings];
    
    ResetNotifications();
    
    return %orig();
}

-(void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    %orig();
    ResetNotifications();
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
    
    
#pragma mark hide the UILabels if they are not being used 
    
    
    
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
        
        if(![chat lastSnap]){
            return;
        }
        
        NSString *lastSnapSender = [[chat lastSnap] sender];
        
        NSString *friendName = [f name];
        
        UILabel *label;
        
        
        if(![instances containsObject:cell]){
            
            CGSize size = cell.frame.size;
            CGRect rect = CGRectMake(size.width*.7,
                                     size.height*.65,
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
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    (CFNotificationCallback)LoadPreferences,
                                    CFSTR("YungRajStreakNotifyDeletePreferencesChangedNotification"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    LoadPreferences();

    
    if (kiOS9)
        %init(iOS9);
    if (kiOS8)
        %init(iOS8);
    if (kiOS7)
        %init(iOS7)
}
