include theos/makefiles/common.mk

ARCHS = arm64 armv7

TWEAK_NAME = StreakNotify
StreakNotify_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 none"
SUBPROJECTS += sn_prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
