include $(THEOS)/makefiles/common.mk

TOOL_NAME = streaknotifyd
streaknotifyd_FILES = main.mm
streaknotifyd_PRIVATE_FRAMEWORKS = AppSupport SpringBoardServices
streaknotifyd_LIBRARIES = rocketbootstrap
streaknotifyd_CODESIGN_FLAGS = -Sentitlements.xml

include $(THEOS_MAKE_PATH)/tool.mk
