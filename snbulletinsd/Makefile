include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

TWEAK_NAME = libsnbulletins
libsnbulletins_FILES = Tweak.xm
libsnbulletins_LIBRARIES = rocketbootstrap
libsnbulletins_PRIVATE_FRAMEWORKS = UIKit BulletinBoard AppSupport
libsnbulletins_CODESIGN_FLAGS = -Sentitlements.xml
libsnbulletins_CFLAGS = -DTHEOS -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tool.mk
