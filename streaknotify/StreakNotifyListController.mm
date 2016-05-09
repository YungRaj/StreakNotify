#import "StreakNotifyListController.h"


@interface StreakNotifyListController () {
    
}

@end



@implementation StreakNotifyListController

-(id)specifiers {
    if(!_specifiers) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"StreakNotify" target:self] retain];
        
       
	}
	return _specifiers;
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




