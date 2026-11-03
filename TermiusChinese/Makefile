THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TermiusChinese
TermiusChinese_FILES = Tweak.m
TermiusChinese_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
