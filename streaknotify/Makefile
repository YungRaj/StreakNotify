include theos/makefiles/common.mk

ARCHS = armv7 arm64 

BUNDLE_NAME = StreakNotify
StreakNotify_FILES = StreakNotifyListController.mm
StreakNotify_INSTALL_PATH = /Library/PreferenceBundles
StreakNotify_FRAMEWORKS = UIKit
StreakNotify_PRIVATE_FRAMEWORKS = Preferences AppSupport 

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/StreakNotify.plist$(ECHO_END)
