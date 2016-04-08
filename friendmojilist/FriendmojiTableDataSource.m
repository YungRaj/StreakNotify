#import "FriendmojiTableDataSource.h"


@interface FriendmojiCell : UITableViewCell {
    
}

@end

@implementation FriendmojiCell


@end

@interface FriendmojiTableDataSource () {
    
}

@property (strong,nonatomic) NSDictionary *settings;
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
        self.settings = [NSMutableDictionary dictionaryWithContentsOfFile:@"var/mobile/Library/Preferences/com.YungRaj.friendmoji.plist"];
        
        /* if the daemon loaded right during a springboard launch, then it's impossible to not have the file saved to disk */
        NSDictionary *friendNamesAndEmojis = [NSDictionary dictionaryWithContentsOfFile:@"/var/root/Documents/streaknotifyd"];
        
        /* crash the app if it doesn't exist, which shouldn't happen if everything is working */
        if(!friendNamesAndEmojis){
            NSLog(@"Fatal - the dictionary that the daemon should save doesn't exist");
            exit(0);
        }
        self.names = [friendNamesAndEmojis allKeys];
        self.friendmojis = [friendNamesAndEmojis allValues];
    
        
        NSLog(@"names and friendmojis loaded successfully %@",friendNamesAndEmojis);
        /* if settings don't exist on file, create settings */
        if(!self.settings){
            NSMutableDictionary *settings  = [[NSMutableDictionary alloc] init];
            for(NSString *name in self.names){
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



-(UITableViewCell*)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"cellForRowAtIndexPath %ld",(long)indexPath.row);
    NSString *identifier = @"friendmojiCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
    if(!cell){
        cell = [[[FriendmojiCell alloc] initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:identifier] autorelease];
        
    }
    if([cell isKindOfClass:[FriendmojiCell class]]){
        
        FriendmojiCell *friendmojiCell = (FriendmojiCell*)cell;
        NSString *name = [self.names objectAtIndex:indexPath.row];
        NSString *friendmoji = [self.friendmojis objectAtIndex:indexPath.row];
        friendmojiCell.textLabel.text = [NSString stringWithFormat:@"%@ %@",name,friendmoji];
        NSLog(@"Cell for index %ld name %@ %@",(long)indexPath.row,name,friendmoji);
        if([self.settings[name] boolValue]){
            friendmojiCell.accessoryType = UITableViewCellAccessoryCheckmark;
        }else{
            friendmojiCell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    return cell;

}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView
numberOfRowsInSection:(NSInteger)section{
    return [self.names count];
}

-(void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"%@",self.settings);
    
    FriendmojiCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *name = [self.names objectAtIndex:indexPath.row];
    
    NSLog(@"Selected cell with name %@",name);
    
    [self.settings setValue:[NSNumber numberWithInteger:![self.settings[name] boolValue]]
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
