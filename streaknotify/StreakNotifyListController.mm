#import "StreakNotifyListController.h"



@interface StreakNotifyListController () {
    NSArray *_displayNames;
}

@end

@implementation StreakNotifyListController

-(id)specifiers {
    if(!_specifiers) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"StreakNotify" target:self] retain];
        [(SpringBoard*)[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.toyopagroup.picaboo" suspended:YES];
        
        /* become a client of the daemon's server so that it will trigger retrieval of the display names from the app */
        /* assuming that the daemon started correctly after a respring or reboot, we can assume that the server exists so go ahead and become a client */
        NSLog(@"Preferences bundle requesting display names");
        
        CPDistributedNotificationCenter* notificationCenter;
        notificationCenter = [CPDistributedNotificationCenter centerNamed:@"preferencesToDaemon"];
        [notificationCenter startDeliveringNotificationsToMainThread];
        
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self
               selector:@selector(displayNamesFromDaemon:)
                   name:@"displayNamesFromDaemon"
                 object:nil];
	}
	return _specifiers;
}

-(void)displayNamesFromDaemon:(NSNotification*)notification{
    
    /* notification is sent from daemon after requesting the displayNames from the application/tweak */
    /* finally sets the displayName property so that the PSLinkList can be populated and the user can finally choose which friends he/she wants to enable for custom notifications for certain friends */
    NSLog(@"Got notification from daemon, finally have display names in Preferences bundle");
    
    if([[notification name] isEqual:@"displayNamesFromDaemon"]){
        NSDictionary *userInfo = [notification userInfo];
        if([[userInfo objectForKey:@"displayNames"] isKindOfClass:[NSArray class]]){
            _displayNames = (NSArray*)[userInfo objectForKey:@"displayNames"];
            UIAlertController *controller =
            [UIAlertController alertControllerWithTitle:@"StreakNotify"
                                                message:[NSString stringWithFormat:@"%@",_displayNames]
                                         preferredStyle:UIAlertControllerStyleAlert];
            [self presentViewController:controller animated:YES completion:nil];
        }
    }
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

@end

