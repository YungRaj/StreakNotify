#import "Bulletins.h"
#import <BulletinBoard/BBBulletinRequest.h>


@interface SBBulletinBannerItem : NSObject

+(SBBulletinBannerItem *)itemWithBulletin:(BBBulletin *)bulletin;

@end

@interface SBBulletinBannerController : NSObject

+(SBBulletinBannerController *)sharedInstance;
-(id)_presentBannerForItem:(SBBulletinBannerItem *)item;

@end

static SNDataProvider *provider = nil;

static void ScheduleBulletin(NSDate *snapDate,
                             Friend *f,
                             float seconds,
                             float minutes,
                             float hours){
    NSString *displayName = f.display;
    if([customFriends count] && ![customFriends containsObject:displayName]){
        NSLog(@"StreakNotify:: Not scheduling bulletin for %@, not enabled in custom friends",displayName);
        return;
    }
    NSLog(@"Using BulletinBoard Framework to schedule bulletin for %@",displayName);
    float t = hours ? hours : minutes ? minutes : seconds;
    NSString *time = hours ? @"hours" : minutes ? @"minutes" : @"seconds";
    NSDate *bulletinDate = [[NSDate alloc] initWithTimeInterval:60*60*24 - 60*60*hours - 60*minutes - seconds
                                                      sinceDate:snapDate];
    
    BBBulletinRequest *bulletin = [[BBBulletinRequest alloc] init];
    bulletin.sectionID = @"com.toyopagroup.picaboo";
    // bulletin.defaultAction = [BBAction actionWithLaunchURL:[NSURL URLWithString:@"music://"] callblock:nil];
    bulletin.bulletinID = @"com.toyopagroup.picaboo";
    bulletin.publisherBulletinID = @"com.toyopagroup.picaboo";
    bulletin.recordID = @"com.toyopagroup.picaboo";
    bulletin.showsUnreadIndicator = NO;
    bulletin.message = [NSString stringWithFormat:@"Keep streak with %@. %ld %@ left!",displayName,(long)t,time];
    bulletin.date = bulletinDate;
    bulletin.lastInterruptDate = bulletinDate;
    BBDataProviderAddBulletin(provider,bulletin);
}

static void ResetBulletins(){
    BBDataProviderWithdrawBulletinsWithRecordID(provider, @"com.toyopagroup.picaboo");
    Manager *manager = [objc_getClass("Manager") shared];
    User *user = [manager user];
    Friends *friends = [user friends];
    SCChats *chats = [user chats];
    
    NSLog(@"SCChats allChats %@",[chats allChats]);
    
    for(SCChat *chat in [chats allChats]){
        
        Snap *earliestUnrepliedSnap = FindEarliestUnrepliedSnapForChat(YES,chat);
        NSDate *snapDate = [earliestUnrepliedSnap timestamp];
        Friend *f = [friends friendForName:[chat recipient]];
        
        NSLog(@"StreakNotify:: Name and date %@ for %@",snapDate,[chat recipient]);
        
        if([f snapStreakCount]>2 && earliestUnrepliedSnap){
            if([prefs[@"kTwelveHours"] boolValue]){
                NSLog(@"Scheduling for 12 hours %@",[f name]);
                ScheduleBulletin(snapDate,f,0,0,12);
                
            } if([prefs[@"kFiveHours"] boolValue]){
                NSLog(@"Scheduling for 5 hours %@",[f name]);
                ScheduleBulletin(snapDate,f,0,0,5);
                
            } if([prefs[@"kOneHour"] boolValue]){
                NSLog(@"Scheduling for 1 hour %@",[f name]);
                ScheduleBulletin(snapDate,f,0,0,1);
                
            } if([prefs[@"kTenMinutes"] boolValue]){
                NSLog(@"Scheduling for 10 minutes %@",[f name]);
                ScheduleBulletin(snapDate,f,0,10,0);
            }
            
            float seconds = [prefs[@"kCustomSeconds"] floatValue];
            float minutes = [prefs[@"kCustomMinutes"] floatValue];
            float hours = [prefs[@"kCustomHours"] floatValue] ;
            if(hours || minutes || seconds){
                NSLog(@"Scheduling for custom time %@",[f name]);
                ScheduleBulletin(snapDate,f,seconds,minutes,hours);
            }
        }
    }
}

@implementation SNDataProvider

+(SNDataProvider *)sharedProvider{
    return [[provider retain] autorelease];
}

-(id)init{
    if([super init]){
        provider = self;
    }
    return self;
}

-(void)dealloc{
    [super dealloc];
}

-(NSString *)sectionIdentifier{
    return @"com.toyopagroup.picaboo";
}

-(NSArray *)sortDescriptors{
    return [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
}

-(NSArray *)bulletinsFilteredBy:(NSUInteger)by count:(NSUInteger)count lastCleared:(id)cleared{
    return nil;
}

-(NSString *)sectionDisplayName{
    return @"StreakNotify";
}

-(void)dataProviderDidLoad{
    ResetBulletins();
}
@end

