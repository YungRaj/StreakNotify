#import <Preferences/Preferences.h>

@interface StreakNotifyListController: PSListController {
    
}
@end

@implementation StreakNotifyListController

- (id)specifiers {
	if(!_specifiers) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"StreakNotify" target:self] retain];
	}
	return _specifiers;
}

-(void)respring {
    [[UIApplication sharedApplication] suspend];
    usleep(51500);
    
    [(SpringBoard*)[UIApplication sharedApplication] _relaunchSpringBoardNow];

}

- (void)twitter {
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter:"]]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"twitter://user?screen_name=" stringByAppendingString:@"ilhanraja"]]];
    } else {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"https://mobile.twitter.com/" stringByAppendingString:@"ilhanraja"]]];
    }
}

- (void)github {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/ilhanraja"]];
}

@end

// vim:ft=objc
