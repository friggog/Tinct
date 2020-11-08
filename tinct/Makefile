ARCHS = armv7 arm64
TARGET = iphone:clang:latest:7.0

GO_EASY_ON_ME = 1
ADDITIONAL_CFLAGS = -fobjc-arc
DEBUG = 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = tinct
tinct_FILES = Tweak.xm
tinct_FRAMEWORKS = UIKit CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
