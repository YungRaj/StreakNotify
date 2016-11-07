include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

TWEAK_NAME = snbulletinsd
snbulletinsd_FILES = Tweak.xm
snbulletinsd_LIBRARIES = rocketbootstrap
snbulletinsd_PRIVATE_FRAMEWORKS = UIKit BulletinBoard AppSupport
snbulletinsd_CODESIGN_FLAGS = -Sentitlements.xml
snbulletinsd_CFLAGS = -DTHEOS -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tool.mk
