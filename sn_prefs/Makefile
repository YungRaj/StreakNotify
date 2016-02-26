include theos/makefiles/common.mk

ARCHS = arm64 armv7 
BUNDLE_NAME = StreakNotify
SN_Prefs_FILES = StreakNotifyListController.mm
SN_Prefs_INSTALL_PATH = /Library/PreferenceBundles
SN_Prefs_FRAMEWORKS = UIKit
SN_Prefs_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/StreakNotify.plist$(ECHO_END)
