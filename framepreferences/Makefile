include $(THEOS)/makefiles/common.mk

TARGET = iphone:clang:13.0:13.0
ARCHS = arm64 arm64e
SYSROOT = /Users/zeruichen/theos/sdks/iPhoneOS13.0.sdk
BUNDLE_NAME = framepreferences

# manually add library search paths from toolchain
# also use dead_strip linker option to prevent linking unnecessary code and causing error 
framepreferences_LDFLAGS += -L/usr/lib/swift -dead_strip
framepreferences_FRAMEWORKS = UIKit MobileCoreServices AVFoundation
framepreferences_FILES = $(wildcard src/*m) $(wildcard Nuke/*.swift) $(wildcard src/*.swift)
framepreferences_INSTALL_PATH = /Library/PreferenceBundles
framepreferences_PRIVATE_FRAMEWORKS = Preferences
framepreferences_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/framepreferences.plist$(ECHO_END)
