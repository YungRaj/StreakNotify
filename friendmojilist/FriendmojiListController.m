#include "FriendmojiListController.h"
#include "FriendmojiTableDataSource.h"

@interface FriendmojiListController () {
    
}

@end

@implementation FriendmojiListController

-(id)initForContentSize:(CGSize)size
{
    if ([PSViewController instancesRespondToSelector:@selector(initForContentSize:)])
        self = [super initForContentSize:size];
    else
        self = [super init];
    if (self) {
        CGRect frame;
        frame.origin = CGPointZero;
        frame.size = size;
        self.tableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStylePlain];
        _dataSource = [FriendmojiTableDataSource dataSource];
        [self.tableView setDataSource:_dataSource];
        [self.tableView setDelegate:_dataSource];
        [self.tableView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    }
    return self;
}


@end
