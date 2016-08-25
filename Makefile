include theos/makefiles/common.mk

ARCHS = armv7 arm64
export SDKVERSION = 9.3


TWEAK_NAME = StreakNotify
StreakNotify_FILES = Tweak.xm
StreakNotify_PRIVATE_FRAMEWORKS = AppSupport
StreakNotify_LIBRARIES = rocketbootstrap
StreakNotify_CFLAGS = -DTHEOS -Wno-deprecated-declarations


include $(THEOS_MAKE_PATH)/tweak.mk


after-install::
	install.exec "killall -9 backboardd"
SUBPROJECTS += streaknotify
SUBPROJECTS += streaknotifyd
SUBPROJECTS += friendmojilist
include $(THEOS_MAKE_PATH)/aggregate.mk
