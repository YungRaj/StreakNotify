#import "StreakNotifyListController.h"


@interface StreakNotifyListController () {
    
}

@property (strong,nonatomic) NSArray *names;

@end



@implementation StreakNotifyListController

-(id)specifiers {
    if(!_specifiers) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"StreakNotify" target:self] retain];
        
        /* become a client of the daemon's server so that it will trigger retrieval of the display names from the app */
        /* assuming that the daemon started correctly after a respring or reboot, we can assume that the server exists so go ahead and become a client */
        _names = [NSArray arrayWithContentsOfFile:@"/var/root/Documents/streaknotifyd"];
	}
	return _specifiers;
}

-(NSArray*)titles{
    NSLog(@"Retrieving titles from file, daemon should have them saved");
    return self.names;
}

-(NSArray*)values{
    NSLog(@"Retrieving values from file, daemon should have saved");
    return self.names;
}

-(void)respring{
    /* use the springboard's relaunchSpringBoardNow function to respring */
    [[UIApplication sharedApplication] performSelector:@selector(suspend)];
    usleep(51500);
    
    [(SpringBoard*)[UIApplication sharedApplication] _relaunchSpringBoardNow];

}

// follow my twitter
-(void)twitter {
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter:"]]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"twitter://user?screen_name=" stringByAppendingString:@"ilhanraja"]]];
    } else {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"https://mobile.twitter.com/" stringByAppendingString:@"ilhanraja"]]];
    }
}

// check out my project on github
-(void)github {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/ilhanraja/StreakNotify"]];
}

-(void)dealloc{
    [super dealloc];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"daemon-preferences"
                                                  object:nil];
}

@end

