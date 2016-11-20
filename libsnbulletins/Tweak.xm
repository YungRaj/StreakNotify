#include <dlfcn.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <rocketbootstrap/rocketbootstrap.h>
#import <BulletinBoard/BBLocalDataProviderStore.h>
#import <BulletinBoard/BBServer.h>
#import <BulletinBoard/BBDataProvider.h>
#import <BulletinBoard/BBBulletinRequest.h>

@interface CPDistributedMessagingCenter : NSObject

+ (instancetype)centerNamed:(NSString *)name;

- (void)runServer;
- (void)runServerOnCurrentThread;
- (void)stopServer;
- (void)registerForMessageName:(NSString *)messageName target:(id)target selector:(SEL)selector;
- (BOOL)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (NSDictionary*)sendMessageAndReceiveReplyName:(NSString*)messageName userInfo:(NSDictionary*)userInfo;
- (NSDictionary*)sendMessageAndReceiveReplyName:(NSString*)messageName userInfo:(NSDictionary*)userInfo error:(NSError **)error;

@end

__attribute__((visibility("hidden")))
@interface SNDataProvider : NSObject <BBDataProvider>

+(SNDataProvider*)sharedProvider;
-(void)dataProviderDidLoad;

@end

@interface SBBulletinBannerItem : NSObject

+(SBBulletinBannerItem *)itemWithBulletin:(BBBulletin *)bulletin;

@end

@interface SBBulletinBannerController : NSObject

+(SBBulletinBannerController *)sharedInstance;
-(id)_presentBannerForItem:(SBBulletinBannerItem *)item;

@end

static SNDataProvider *provider = nil;

static void ScheduleBulletin(NSDate *bulletinDate,
                             NSString *bulletinMessage){
    NSLog(@"libsnbulletins::Using BulletinBoard to schedule bulletin for message %@",bulletinMessage);
    
    BBBulletinRequest *bulletin = [[BBBulletinRequest alloc] init];
    bulletin.sectionID = @"com.toyopagroup.picaboo";
    bulletin.bulletinID = @"com.toyopagroup.picaboo";
    bulletin.publisherBulletinID = @"com.toyopagroup.picaboo";
    bulletin.recordID = @"com.toyopagroup.picaboo";
    bulletin.showsUnreadIndicator = NO;
    bulletin.message = bulletinMessage;
    bulletin.date = bulletinDate;
    bulletin.lastInterruptDate = bulletinDate;
    BBDataProviderAddBulletin(provider,bulletin);
}

static void ResetBulletins(SNDataProvider *provider,
                           NSDictionary *info){
    BBDataProviderWithdrawBulletinsWithRecordID(provider, @"com.toyopagroup.picaboo");
    NSArray *bulletins = [info objectForKey:@"kBulletins"];
    for(NSDictionary *bulletin in bulletins){
        ScheduleBulletin(bulletin[@"kBulletinDate"],bulletin[@"kBulletinMessage"]);
    }
    
}

@implementation SNDataProvider

+(SNDataProvider *)sharedProvider{
    return [[provider retain] autorelease];
}

-(id)init{
    if(self = [super init]){
        provider = self;
        CPDistributedMessagingCenter *server = [CPDistributedMessagingCenter centerNamed:@"com.YungRaj.libsnbulletins"];
        rocketbootstrap_unlock("com.YungRaj.libsnbulletins");
        rocketbootstrap_distributedmessagingcenter_apply(server);
        [server runServerOnCurrentThread];
        [server registerForMessageName:@"bulletins" target:self selector:@selector(scheduleBulletins:userInfo:)];
        
    }
    return self;
}

-(NSDictionary*)scheduleBulletins:(NSString*)name userInfo:(NSDictionary*)info{
    NSLog(@"libsnbulletins::attempting to schedule bulletins");
    [NSThread detachNewThreadSelector:@selector(scheduleBulletins:) toTarget:self withObject:info];
    return [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:@"status"];
}

-(void)scheduleBulletins:(NSDictionary*)info{
    NSLog(@"libsnbulletins::using current thread to schedule bulletins");
    ResetBulletins(self,info);
    [self dataProviderDidLoad];
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
    NSLog(@"libsnbulletins::Sucessfully updated bulletins");
}

@end


#ifdef THEOS
%group Bulletins
%hook BBLocalDataProviderStore
//#else
//@implementation Bulletins
#endif

-(void)loadAllDataProvidersAndPerformMigration:(bool)performMigration{
    %orig();
    NSLog(@"libsnbulletins::BulletinBoard is finally integrated with SN! Using SNDataProvider to work on notifications");
    SNDataProvider *provider = [[SNDataProvider alloc] init];
    [self addDataProvider:provider performMigration:performMigration];
    [provider release];
}

-(void)loadAllDataProviders{
    %orig();
    NSLog(@"libsnbulletins::BulletinBoard is finally integrated with SN! Using SNDataProvider to work on notifications");
    SNDataProvider *provider = [[SNDataProvider alloc] init];
    [self addDataProvider: provider];
    [provider release];
}

#ifdef THEOS
%end
%end
#endif

#ifdef THEOS
%ctor
#else
void constructor()
#endif
{
    
    %init(Bulletins);
}

