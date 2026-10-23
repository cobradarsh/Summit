TARGET := iphone:clang:16.5:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SummitPrefs

SummitPrefs_FILES = SMTRootListController.m
SummitPrefs_FRAMEWORKS = UIKit
SummitPrefs_PRIVATE_FRAMEWORKS = Preferences FrontBoardServices SpringBoardServices
SummitPrefs_INSTALL_PATH = /Library/PreferenceBundles
SummitPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
