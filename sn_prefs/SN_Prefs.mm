#import <Preferences/Preferences.h>

@interface SN_PrefsListController: PSListController {
}
@end

@implementation SN_PrefsListController
- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"SN_Prefs" target:self] retain];
	}
	return _specifiers;
}
@end

// vim:ft=objc
