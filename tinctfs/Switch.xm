#import <Flipswitch/FSSwitchDataSource.h>
#import <Flipswitch/FSSwitchPanel.h>

#define PreferencesFilePath @"/var/mobile/Library/Preferences/me.chewitt.tinctprefs.plist"
#define PreferencesChangedNotification "me.chewitt.tinctprefs.settingschanged"

extern "C" void BKSTerminateApplicationGroupForReasonAndReportWithDescription(int a, int b, int c, NSString *description);

@interface tinctfsSwitch : NSObject <FSSwitchDataSource,UIAlertViewDelegate>
@end

@implementation tinctfsSwitch

static void TinctSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    [[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:[NSBundle bundleForClass:[tinctfsSwitch class]].bundleIdentifier];
}

+ (void)load
{
  CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
  CFNotificationCenterAddObserver(center, NULL, TinctSettingsChanged, CFSTR(PreferencesChangedNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);
  CFNotificationCenterAddObserver(center, NULL, TinctSettingsChanged, CFSTR(PreferencesChangedNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PreferencesFilePath];
	return (FSSwitchState)![[dict valueForKey:@"Enabled"] boolValue];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
  NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithContentsOfFile:PreferencesFilePath] ?: [[NSMutableDictionary alloc] init];
  NSNumber *value = [NSNumber numberWithBool:!newState];
  [dict setValue:value forKey:@"Enabled"];
  [dict writeToFile:PreferencesFilePath atomically:YES];
  CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(PreferencesChangedNotification), nil, nil, true);
  /*BKSTerminateApplicationGroupForReasonAndReportWithDescription(1, 5, 0,NULL);
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Respring Required"
                                                  message:@"To properly enable/disable Tinct you need to respring."
                                                 delegate:self
                                        cancelButtonTitle:@"Later"
                                        otherButtonTitles:@"Respring"
                        , nil];
  [alert show];*/
}
/*
-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
  if (buttonIndex == 1) {
    system("killall backboardd");
  }
}*/

@end
