# sim / iphone
SIM = 0

ifeq ($(SIM), 1)
	DEBUG = 1
	TARGET = simulator:clang:13.0:12.2.0
	ARCHS = x86_64
	SYSROOT = /Users/zeruichen/theos/sdks/iPhoneSimulator11.2.sdk
else
	TARGET = iphone:clang:13.0:12.2.0
	ARCHS = arm64 arm64e
	SYSROOT = /Users/zeruichen/theos/sdks/iPhoneOS13.0.sdk
endif

PACKAGE_VERSION = 2.3.0

INSTALL_TARGET_PROCESSES = SpringBoard
frame_FRAMEWORKS = Foundation UIKit AVFoundation

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = frame

frame_FILES = $(wildcard ./src/*m)
frame_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

ifeq ($(SIM), 0)
	SUBPROJECTS += framepreferences
	SUBPROJECTS += framecli
	include $(THEOS_MAKE_PATH)/aggregate.mk
endif