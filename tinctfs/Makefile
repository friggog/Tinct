ARCHS = armv7s armv7 arm64
TARGET = iPhone:7.1

ADDITIONAL_CFLAGS = -fobjc-arc

include theos/makefiles/common.mk

BUNDLE_NAME = tinctfs
tinctfs_FILES = Switch.xm
tinctfs_FRAMEWORKS = UIKit
tinctfs_PRIVATE_FRAMEWORKS = BackBoardServices
tinctfs_LIBRARIES = flipswitch
tinctfs_INSTALL_PATH = /Library/Switches

include $(THEOS_MAKE_PATH)/bundle.mk
