#import <BulletinBoard/BBDataProvider.h>
#import "Interfaces.h"


extern NSDictionary *prefs;
extern NSString *snapchatVersion;
extern NSMutableArray *customFriends;
extern UIImage *autoReplySnapstreakImage;
extern Snap* FindEarliestUnrepliedSnapForChat(BOOL receive, SCChat *chat);


__attribute__((visibility("hidden")))
@interface SNDataProvider : NSObject <BBDataProvider>

+(SNDataProvider*)sharedProvider;
-(void)dataProviderDidLoad;

@end


