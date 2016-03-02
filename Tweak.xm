
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
            
        }
        
        CFRelease(keyList);
    }
}

static void SizeLabelToRect(UILabel *label, CGRect labelRect){
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

%hook SCFeedTableViewCell

static NSMutableArray *instances = nil;
static NSMutableArray *labels = nil;


-(void)layoutSubviews{
    %orig();
    
    if(!instances){
        instances = [[NSMutableArray alloc] init];
    } if(!labels){
        labels = [[NSMutableArray alloc] init];
    }
    
    User *user = [%c(User) createUser];
    Friends *friends = [user friends];
    
    SCChatViewModelForFeed *feedItem = self.feedItem;
    SCChat *chat = [feedItem chat];
    
    NSString *recipient = [chat recipient];
        
    Friend *f = [friends friendForName:recipient];
    
    NSString *lastSnapSender = [[chat lastSnap] sender];
    
    NSString *friendName = [f name];
    
    UILabel *label;
    
    if(![instances containsObject:self]){
        
        CGSize size = self.frame.size;
        CGRect rect = CGRectMake(size.width*.55,
                                 size.height/8,
                                 size.width/4,
                                 size.height/4);
        label = [[UILabel alloc] initWithFrame:rect];
        
        [instances addObject:self];
        [labels addObject:label];
            
        SizeLabelToRect(label,rect);
        [self.containerView addSubview:label];
        
    }else {
        label = [labels objectAtIndex:[instances indexOfObject:self]];
    }
    
    if([f snapStreakCount] && [lastSnapSender isEqual:friendName]){
        label.text = [NSString stringWithFormat:@"Time remaining: %@",
                        GetTimeRemaining(f,chat)];
        label.hidden = NO;
    }else {
        label.text = @"";
        label.hidden = YES;
    }
    
}

-(void)dealloc{
    NSInteger index = [instances indexOfObject:self];
    UILabel *label = [labels objectAtIndex:index];
    [labels removeObjectAtIndex:index];
    [instances removeObjectAtIndex:index];
    [label removeFromSuperview];
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
