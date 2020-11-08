ARCHS = armv7 arm64
TARGET = iphone:clang:latest:7.0
ADDITIONAL_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = TinctPrefs
TinctPrefs_FILES = TinctPrefs.mm ColorPicker/HRBrightnessCursor.m ColorPicker/HRBrightnessSlider.m ColorPicker/HRAlphaSlider.m ColorPicker/HRBrightnessSlider.m ColorPicker/HRAlphaCursor.m ColorPicker/HRColorCursor.m ColorPicker/HRColorInfoView.m ColorPicker/HRColorMapView.m ColorPicker/HRColorPickerView.m ColorPicker/HRHSVColorUtil.m ColorPicker/UIImage+CoreGraphics.m CircleViews.mm
TinctPrefs_INSTALL_PATH = /Library/PreferenceBundles
TinctPrefs_FRAMEWORKS = UIKit Social MessageUI CoreGraphics QuartzCore
TinctPrefs_PRIVATE_FRAMEWORKS = Preferences BackBoardServices

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/TinctPrefs.plist$(ECHO_END)
