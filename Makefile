# sim / iphone
SIM = 0
Device = 0

ifeq ($(SIM), 1)
	DEBUG = 1
	TARGET = simulator:clang:latest:12.2.0
	ARCHS = x86_64
	SYSROOT = /Users/zeruichen/theos/sdks/iPhoneSimulator11.2.sdk
else
	TARGET = iphone:clang:latest:13.0
	ARCHS = arm64 arm64e
	SYSROOT = /Users/zeruichen/theos/sdks/iPhoneOS13.7.sdk
endif

# iPhone
ifeq ($(Device), 0)
	THEOS_DEVICE_IP = localhost
	THEOS_DEVICE_PORT = 2222
endif
# iPad
ifeq ($(Device), 1)
	THEOS_DEVICE_IP = 192.168.0.206
	THEOS_DEVICE_PORT = 22
endif

PACKAGE_VERSION = 3.0.1
THEOS_PACKAGE_SCHEME = rootless

INSTALL_TARGET_PROCESSES = SpringBoard
frame_FRAMEWORKS = Foundation UIKit AVFoundation

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = frame

frame_FILES = $(wildcard ./src/*m)
frame_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

# ifeq ($(SIM), 0)
# 	SUBPROJECTS += framecli
# 	include $(THEOS_MAKE_PATH)/aggregate.mk
# endif
