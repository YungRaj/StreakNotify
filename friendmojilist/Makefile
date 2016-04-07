include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = friendmojilist
friendmojilist_FILES = FriendmojiListController.m FriendmojiTableDataSource.m
friendmojilist_INSTALL_PATH = /Library/PreferenceBundles
friendmojilist_FRAMEWORKS = UIKit
friendmojilist_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
