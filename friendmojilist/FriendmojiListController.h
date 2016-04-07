#import <Preferences/PSListController.h>

@class FriendmojiTableDataSource;

@interface FriendmojiListController : PSListController

@property (strong,nonatomic) FriendmojiTableDataSource *dataSource;

@end
