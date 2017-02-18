include $(THEOS)/makefiles/common.mk

TWEAK_NAME = libsnbulletins
libsnbulletins_FILES = Tweak.xm
libsnbulletins_LIBRARIES = rocketbootstrap
libsnbulletins_PRIVATE_FRAMEWORKS = UIKit BulletinBoard AppSupport
libsnbulletins_CFLAGS = -DTHEOS -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
