
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

#import "Interfaces.h"

#define kiOS7 (kCFCoreFoundationVersionNumber >= 847.20 && kCFCoreFoundationVersionNumber <= 847.27)
#define kiOS8 (kCFCoreFoundationVersionNumber >= 1140.10 && kCFCoreFoundationVersionNumber >= 1145.15)
#define kiOS9 (kCFCoreFoundationVersionNumber == 1240.10)

#pragma mark App freezes when retrieving data 

static NSDictionary* prefs = nil;
static CFStringRef applicationID = CFSTR("com.YungRaj.streaknotify");

static void LoadPreferences() {
    if (CFPreferencesAppSynchronize(applicationID)) { //sharedRoutine - MSGAutoSave8
        CFArrayRef keyList = CFPreferencesCopyKeyList(applicationID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) ?: CFArrayCreate(NULL, NULL, 0, NULL);
        if (access("/var/mobile/Library/Preferences/com.YungRaj.streaknotify", F_OK) != -1) {
            prefs = (__bridge NSDictionary *)CFPreferencesCopyMultiple(keyList, applicationID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        } else { //register defaults for first launch
            
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
    NSDate *date = [NSDate date];
    NSArray *snapsToView = [c snapsToView];
    NSDate *latestSnapDate = [[NSDate alloc] initWithTimeIntervalSince1970:0];
    for(Snap *snap in snapsToView){
        latestSnapDate = [latestSnapDate laterDate:snap.timestamp];
    }
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

%hook SCFeedTableViewCell

static NSMutableArray *instances;
static NSMutableArray *labels;


-(void)layoutSubviews{
    
    %orig();
    if(!instances && !labels){
        instances = [[NSMutableArray alloc] init];
        labels = [[NSMutableArray alloc] init];
    }
    
    if(![instances containsObject:self]){
        User *user = [%c(User) createUser];
        Friends *friends = [user friends];
        
        SCChatViewModelForFeed *feedItem = self.feedItem;
        
        SCChat *chat = [feedItem chat];
        NSString *recipient = [chat recipient];
        
        Friend *f = [friends friendForName:recipient];
        
        
        if([f snapStreakCount] && [chat hasUnviewedSnaps]){
            CGSize size = self.frame.size;
            CGRect rect = CGRectMake(size.width*.55,
                                     size.height/8,
                                     size.width/4,
                                     size.height/4);
            UILabel *label = [[UILabel alloc] initWithFrame:rect];
            label.text = [NSString stringWithFormat:@"Time remaining: %@",GetTimeRemaining(f,chat)];
            [instances addObject:self];
            [labels addObject:labels];
            
            SizeLabelToRect(label,rect);
            [self.containerView addSubview:label];
        }
    }
    
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
