include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = FriendmojiList
FriendmojiList_FILES = FriendmojiTableDataSource.m FriendmojiListController.m 
FriendmojiList_INSTALL_PATH = /System/Library/PreferenceBundles
FriendmojiList_FRAMEWORKS = UIKit
FriendmojiList_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
