#include "FriendmojiListController.h"
#include "FriendmojiTableDataSource.h"
#include <objc/runtime.h>

@interface FriendmojiListController ()

// @property (strong,nonatomic) UITableView *tableView;

@end

@implementation FriendmojiListController


-(id)initForContentSize:(CGSize)size
{
    if ([objc_getClass("PSViewController") instancesRespondToSelector:@selector(initForContentSize:)])
        self = [super initForContentSize:size];
    else
        self = [super init];
    if (self) {
        CGRect frame;
        frame.origin = CGPointZero;
        frame.size = size;
        
        
    }
    return self;
}



-(void)viewDidLoad{
    [super viewDidLoad];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.dataSource = [FriendmojiTableDataSource dataSource];
    [self.tableView setDataSource:self.dataSource];
    [self.tableView setDelegate:self.dataSource];
    [self.tableView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    self.tableView.frame = self.view.bounds;
    [self.tableView setScrollsToTop:YES];
    [self.view addSubview:self.tableView];
    
    [self.tableView reloadData];
}

-(CGSize)contentSize
{
    return [self.tableView frame].size;
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    if([self isMovingFromParentViewController]){
        NSLog(@"friendmojilist::Exiting friendmoji prefs, saving settings");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"friendmojiPreferencesWillExit"
                                                            object:nil];
    }
    
}

@end
