include $(THEOS)/makefiles/common.mk

ARCHS = arm64 arm64e
TARGET = iphone:clang:13.0:11.0
SYSROOT = /Users/zeruichen/theos/sdks/iPhoneOS13.0.sdk
BUNDLE_NAME = framepreferences

framepreferences_FILES = ZX2RootListController.m
framepreferences_INSTALL_PATH = /Library/PreferenceBundles
framepreferences_FRAMEWORKS = UIKit MobileCoreServices AVFoundation
framepreferences_PRIVATE_FRAMEWORKS = Preferences
framepreferences_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/framepreferences.plist$(ECHO_END)
