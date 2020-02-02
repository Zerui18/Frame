include $(THEOS)/makefiles/common.mk

TOOL_NAME = framecli

ARCHS = arm64 arm64e
TARGET = iphone:clang:13.0:11.0
SYSROOT = /Users/zeruichen/theos/sdks/iPhoneOS13.0.sdk
BUNDLE_NAME = framepreferences

framecli_INSTALL_PATH = /usr/bin
framecli_FRAMEWORKS = Foundation

framecli_FILES = main.m
framecli_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tool.mk
