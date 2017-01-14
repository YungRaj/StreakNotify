#include "FriendmojiListController.h"
#include "FriendmojiTableDataSource.h"
#include <objc/runtime.h>

@interface FriendmojiListController ()

@property (strong,nonatomic) UITableView *tableView;

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
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(loadFriendmojiListFailed:)
                                                     name:@"loadFriendmojiListFailed"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self
                                                selector:@selector(applicationDidResignActive:)
                                                    name:UIApplicationWillResignActiveNotification
                                                  object:nil];
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

-(void)loadFriendmojiListFailed:(NSNotification*)notification{
    if([UIAlertController class]){
        UIAlertController *controller =
        [UIAlertController alertControllerWithTitle:@"StreakNotify"
                                            message:@"Friendmojis were not saved to disk at /var/root/Documents? Or syscall failed"
                                     preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancel =
        [UIAlertAction actionWithTitle:@"Cancel"
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction* action){
                                   [self.navigationController popToRootViewControllerAnimated:YES];
                               }];
        UIAlertAction *ok =
        [UIAlertAction actionWithTitle:@"Ok"
                                 style:UIAlertActionStyleCancel
                               handler:^(UIAlertAction* action){
                                   
                               }];
        [controller addAction:cancel];
        [controller addAction:ok];
        [self presentViewController:controller animated:NO completion:nil];
    }
}

-(void)applicationWillResignActive:(NSNotification*)notification{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"friendmojiPreferencesWillExit"
                                                        object:nil];
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
