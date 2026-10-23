TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

# Requires the roothide fork of Theos (github.com/roothide/theos).
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Summit

Summit_FILES = Tweak.x SMTStore.m SMTStackOverlay.m SMTAppPicker.m
Summit_FRAMEWORKS = UIKit
Summit_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += summitprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
