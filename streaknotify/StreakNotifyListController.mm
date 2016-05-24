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

-(void)chooseAutoReplySnapStreakImage{
    UIImagePickerController *pickerLibrary = [[UIImagePickerController alloc] init];
    pickerLibrary.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    pickerLibrary.delegate = self;
    [self presentModalViewController:pickerLibrary animated:YES];
}

-(void)imagePickerController:(UIImagePickerController*)picker
       didFinishPickingImage:(UIImage*)image
                 editingInfo:(NSDictionary*)editingInfo
{
    NSData *autoReplySnapStreak = UIImageJPEGRepresentation(image,0.7);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentsDirectory]){
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:documentsDirectory withIntermediateDirectories:NO attributes:nil error:&error];
    }
    
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"autoreply_sn.jpeg"];
    
    
    [autoReplySnapStreak writeToFile:filePath atomically:YES];
    
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




