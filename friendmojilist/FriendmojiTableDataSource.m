#import "FriendmojiTableDataSource.h"


@interface FriendmojiCell : UITableViewCell {
    
}


@end

@implementation FriendmojiCell


@end

@interface FriendmojiTableDataSource () {
    
}

@property (strong,nonatomic) NSMutableDictionary *settings;
@property (strong,nonatomic) NSArray *names;

@end


@implementation FriendmojiTableDataSource

+(id)dataSource
{
    return [[[self alloc] init] autorelease];
}

-(id)init
{
    self = [super init];
    if (self) {
        _settings = [NSDictionary dictionaryWithContentsOfFile:@"var/mobile/Library/Preferences/com.YungRaj.friendmoji.plist"];
        _names = [NSArray arrayWithContentsOfFile:@"/var/root/Documents/streaknotifyd"];
        
        if(!_settings){
            _settings = [[NSDictionary alloc] init];
            for(NSString *friendmoji in _names){
                [_settings setValue:@NO forKey:friendmoji];
            }
        }
        
        /* add the data source as an observer to find out when the friendmojilistcontroller will exit so that we can save the dictionary to file */
        [[NSNotificationCenter defaultCenter]
                        addObserver:self
                           selector:@selector(friendmojiSettingsWillExit:)
                               name:@"friendmojiSettingsWillExit"
                            object:nil];
    }
    return self;
}



-(UITableViewCell*)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    NSString *identifier = [NSString stringWithFormat:@"friendmojicell%ld",(long)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
    if(!cell){
        cell = [[FriendmojiCell alloc] initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:identifier];
        cell.textLabel.text = [self.names objectAtIndex:indexPath.row];
    }
    
    return cell;

}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView
numberOfRowsInSection:(NSInteger)section{
    return [_names count];
}

-(NSIndexPath*)tableView:(UITableView *)tableView
willSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    FriendmojiCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *friendmoji = cell.textLabel.text;
    [_settings setValue:@YES forKey:friendmoji];
    
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    return indexPath;
}

-(NSIndexPath*)tableView:(UITableView *)tableView
willDeselectRowAtIndexPath:(NSIndexPath *)indexPath{
    FriendmojiCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *friendmoji = cell.textLabel.text;
    [_settings setValue:@NO forKey:friendmoji];
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    return indexPath;
}

-(void)friendmojiSettingsWillExit:(NSNotification*)notification{
    NSDictionary *settings = [notification userInfo];
    [settings writeToFile:@"/var/mobile/Library/Preferences/com.YungRaj.friendmoji.plist"
               atomically:YES];
    
}


@end
