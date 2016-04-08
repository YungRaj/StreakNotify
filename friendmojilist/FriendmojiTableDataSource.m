#import "FriendmojiTableDataSource.h"


@interface FriendmojiCell : UITableViewCell {
    
}

@property (strong,nonatomic) NSString *name;
@property (strong,nonatomic) NSString *friendmoji;


@end

@implementation FriendmojiCell


@end

@interface FriendmojiTableDataSource () {
    
}

@property (strong,nonatomic) NSMutableDictionary *settings;
@property (strong,nonatomic) NSArray *names;
@property (strong,nonatomic) NSArray *friendmojis;

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
        _settings = [[NSDictionary dictionaryWithContentsOfFile:@"var/mobile/Library/Preferences/com.YungRaj.friendmoji.plist"] mutableCopy];
        
        /* if the daemon loaded right during a springboard launch, then it's impossible to not have the file saved to disk */
        NSDictionary *friendNamesAndEmojis = [NSDictionary dictionaryWithContentsOfFile:@"/var/root/Documents/streaknotifyd"];
        
        /* crash the app if it doesn't exist, which shouldn't happen if everything is working */
        if(!friendNamesAndEmojis){
            NSLog(@"Fatal error: the dictionary that the daemon should save doesn't exist");
            exit(0);
        }
        _names = [friendNamesAndEmojis allKeys];
        _friendmojis = [friendNamesAndEmojis allValues];
        
        
        /* if settings don't exist on file, create settings */
        if(!_settings){
            _settings = [[NSMutableDictionary alloc] init];
            for(NSString *name in _names){
                [_settings setObject:@NO forKey:name];
            }
        }

        
        /* add the data source as an observer to find out when the friendmojilistcontroller will exit so that we can save the dictionary to file */
        [[NSNotificationCenter defaultCenter]
                        addObserver:self
                           selector:@selector(friendmojiPreferencesWillExit:)
                               name:@"friendmojiPreferencesWillExit"
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
        
    }
    if([cell isKindOfClass:[FriendmojiCell class]]){
        FriendmojiCell *friendmojiCell = (FriendmojiCell*)cell;
        NSString *name = [self.names objectAtIndex:indexPath.row];
        NSString *friendmoji = [self.friendmojis objectAtIndex:indexPath.row];
        friendmojiCell.name = name;
        friendmojiCell.friendmoji = friendmoji;
        friendmojiCell.textLabel.text = [NSString stringWithFormat:@"%@%@",name,friendmoji];
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
    NSString *name = cell.name;
    
    [_settings setObject:@YES forKey:name];
    
    
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    return indexPath;
}

-(NSIndexPath*)tableView:(UITableView *)tableView
willDeselectRowAtIndexPath:(NSIndexPath *)indexPath{
    FriendmojiCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *name = cell.name;
    
    [_settings setObject:@NO forKey:name];
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    return indexPath;
}

-(void)friendmojiPreferencesWillExit:(NSNotification*)notification{
    NSDictionary *settings = self.settings;
    [settings writeToFile:@"/var/mobile/Library/Preferences/com.YungRaj.friendmoji.plist"
               atomically:YES];
    NSLog(@"Saved settings");
    
}


@end
