TARGET = iphone:clang:13.0:12.2
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard
SYSROOT = /Users/zeruichen/theos/sdks/iPhoneOS13.0.sdk
frame_FRAMEWORKS = UIKit AVFoundation

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = frame

frame_FILES = $(wildcard ./src/*m)
frame_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += framepreferences
SUBPROJECTS += framecli
include $(THEOS_MAKE_PATH)/aggregate.mk
