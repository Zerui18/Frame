ARCHS = arm64
TARGET = iphone:clang:13.0:13.0
INSTALL_TARGET_PROCESSES = SpringBoard
SYSROOT = /Users/zeruichen/theos/sdks/iPhoneOS13.0.sdk
frame_FRAMEWORKS = UIKit AVFoundation

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = frame

frame_FILES = Tweak.xm
frame_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += framepreferences
include $(THEOS_MAKE_PATH)/aggregate.mk
