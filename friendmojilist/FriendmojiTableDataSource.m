#import "FriendmojiTableDataSource.h"


@interface FriendmojiCell : UITableViewCell {
    
}

@end

@implementation FriendmojiCell


@end

@interface FriendmojiTableDataSource () {
    
}

@property (strong,nonatomic) NSDictionary *settings;
@property (strong,nonatomic) NSArray *friendsWithStreaksNames;
@property (strong,nonatomic) NSArray *friendmojisWithStreaks;
@property (strong,nonatomic) NSArray *friendsWithoutStreaksNames;
@property (strong,nonatomic) NSArray *friendmojisWithoutStreaks;

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
        self.settings = [NSMutableDictionary dictionaryWithContentsOfFile:@"var/mobile/Library/Preferences/com.YungRaj.friendmoji.plist"];
        
    
        
        /* if the daemon loaded right during a springboard launch, then it's impossible to not have the file saved to disk */
        
        NSDictionary *friendNamesAndEmojis = [NSDictionary dictionaryWithContentsOfFile:@"/var/root/Documents/streaknotifyd"];
        
        /* crash the app if it doesn't exist, which shouldn't happen if everything is working */
        if(!friendNamesAndEmojis){
            NSLog(@"Fatal - the dictionary that the daemon should save doesn't exist");
            exit(0);
        }
        NSDictionary *friendsWithStreaks = friendNamesAndEmojis[@"friendsWithStreaks"];
        NSDictionary *friendsWithoutStreaks = friendNamesAndEmojis[@"friendsWithoutStreaks"];
        
        NSArray *friendsWithStreaksNames = [friendsWithStreaks allKeys];
        NSMutableArray *friendmojisWithStreaks = [[NSMutableArray alloc] init];
        
        NSArray *friendsWithoutStreaksNames = [friendsWithoutStreaks allKeys];
        NSMutableArray *friendmojisWithoutStreaks = [[NSMutableArray alloc] init];
        
        
        friendsWithStreaksNames = [friendsWithStreaksNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        friendsWithoutStreaksNames = [friendsWithoutStreaksNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        
        for(NSString *name in friendsWithStreaksNames){
            NSString *friendmoji = [friendsWithStreaks objectForKey:name];
            [friendmojisWithStreaks addObject:friendmoji];
        }
        
        for(NSString *name in friendsWithoutStreaksNames){
            NSString *friendmoji = [friendsWithoutStreaks objectForKey:name];
            [friendmojisWithoutStreaks addObject:friendmoji];
        }
        
        NSLog(@"Friends with streaks %@ %@",friendsWithStreaksNames,friendmojisWithStreaks);
        NSLog(@"Friends without streaks %@ %@",friendsWithoutStreaksNames,friendmojisWithoutStreaks);
        
        self.friendsWithStreaksNames = friendsWithStreaksNames;
        self.friendmojisWithStreaks = friendmojisWithStreaks;
        
        self.friendsWithoutStreaksNames = friendsWithoutStreaksNames;
        self.friendmojisWithoutStreaks = friendmojisWithoutStreaks;
        
        NSLog(@"names and friendmojis loaded successfully %@",friendNamesAndEmojis);
        /* if settings don't exist on file, create settings */
        if(!self.settings){
            NSMutableDictionary *settings  = [[NSMutableDictionary alloc] init];
            for(NSString *name in self.friendsWithStreaksNames){
                [settings setObject:@NO forKey:name];
            }
            
            for(NSString *name in self.friendsWithoutStreaksNames){
                [settings setObject:@NO forKey:name];
            }
            
            self.settings = settings;
            
            
            NSLog(@"%@",self.settings);
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

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 2;
}

-(NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *sectionName;
    switch (section)
    {
        case 0:
            sectionName = @"Friends with Streaks";
            break;
        case 1:
            sectionName = @"Other Friends";
            break;
            // ...
        default:
            sectionName = @"";
            break;
    }
    return sectionName;
}

-(NSInteger)tableView:(UITableView *)tableView
numberOfRowsInSection:(NSInteger)section{
    
    switch (section)
    {
        case 0:
            return [self.friendsWithStreaksNames count];
        case 1:
            return [self.friendsWithoutStreaksNames count];
    }
    return 0;
}


-(UITableViewCell*)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    NSString *identifier = @"friendmojiCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
    if(!cell){
        cell = [[[FriendmojiCell alloc] initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:identifier] autorelease];
        
    }
    if(indexPath.section == 0){
        if([cell isKindOfClass:[FriendmojiCell class]]){
            
            FriendmojiCell *friendmojiCell = (FriendmojiCell*)cell;
            NSString *name = [self.friendsWithStreaksNames objectAtIndex:indexPath.row];
            NSString *friendmoji = [self.friendmojisWithStreaks objectAtIndex:indexPath.row];
            friendmojiCell.textLabel.text = [NSString stringWithFormat:@"%@ %@",name,friendmoji];
            NSLog(@"Cell for index %ld name %@ %@",(long)indexPath.row,name,friendmoji);
            if([self.settings[name] boolValue]){
                friendmojiCell.accessoryType = UITableViewCellAccessoryCheckmark;
            }else{
                friendmojiCell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    } else if(indexPath.section == 1){
        if([cell isKindOfClass:[FriendmojiCell class]]){
            
            FriendmojiCell *friendmojiCell = (FriendmojiCell*)cell;
            NSString *name = [self.friendsWithoutStreaksNames objectAtIndex:indexPath.row];
            NSString *friendmoji = [self.friendmojisWithoutStreaks objectAtIndex:indexPath.row];
            friendmojiCell.textLabel.text = [NSString stringWithFormat:@"%@ %@",name,friendmoji];
            NSLog(@"Cell for index %ld name %@ %@",(long)indexPath.row,name,friendmoji);
            if([self.settings[name] boolValue]){
                friendmojiCell.accessoryType = UITableViewCellAccessoryCheckmark;
            }else{
                friendmojiCell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    }
    return cell;

}

-(void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    FriendmojiCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *name = [NSString string];
    
    if(indexPath.section == 0){
        name = [self.friendsWithStreaksNames objectAtIndex:indexPath.row];
    } else if(indexPath.section == 1){
        name = [self.friendsWithoutStreaksNames objectAtIndex:indexPath.row];
    }
    
    [self.settings setValue:[NSNumber numberWithBool:![self.settings[name] boolValue]]
                     forKey:name];
    
    
    if(cell.accessoryType==UITableViewCellAccessoryCheckmark){
        cell.accessoryType = UITableViewCellAccessoryNone;
    }else if(cell.accessoryType==UITableViewCellAccessoryNone){
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


-(void)friendmojiPreferencesWillExit:(NSNotification*)notification{
    NSDictionary *settings = self.settings;
    [settings writeToFile:@"/var/mobile/Library/Preferences/com.YungRaj.friendmoji.plist"
               atomically:YES];
    NSLog(@"Saved settings");
    
}


@end
