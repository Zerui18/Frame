include $(THEOS)/makefiles/common.mk

ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:11.0
SYSROOT = /Users/zeruichen/theos/sdks/iPhoneOS13.0.sdk
BUNDLE_NAME = framepreferences

# manually add library search paths from toolchain
# also use dead_strip linker option to prevent linking unnecessary code and causing error 
framepreferences_LDFLAGS += -L./ -lwebpdecoder
framepreferences_FRAMEWORKS = UIKit MobileCoreServices AVFoundation
framepreferences_FILES = src/WebP/WebPDataDecoder.m $(wildcard src/Digger/*.swift) $(wildcard src/WebP/*.swift) $(wildcard src/Nuke/*.swift) $(wildcard src/*m) $(wildcard src/*.swift)
framepreferences_INSTALL_PATH = /Library/PreferenceBundles
framepreferences_PRIVATE_FRAMEWORKS = Preferences
framepreferences_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/framepreferences.plist$(ECHO_END)
