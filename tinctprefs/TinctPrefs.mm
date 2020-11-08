#import <Preferences/Preferences.h>
#import <Social/Social.h>
#import <MessageUI/MessageUI.h>
#import <sys/utsname.h>
#import "ColorPicker/HRColorPickerView.h"
#import "CircleViews.h"
#import <objc/runtime.h>

NSInteger system_nd(const char *command) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
	return system(command);
#pragma GCC diagnostic pop
}

extern "C" void BKSTerminateApplicationGroupForReasonAndReportWithDescription(NSInteger a, NSInteger b, NSInteger c, NSString* description);

#define TWEAK_VERSION @"1.4.1"
#define listPath @"/var/lib/dpkg/info/me.chewitt.tinct.list"
#define prefsPath @"/User/Library/Preferences/me.chewitt.tinctprefs.plist"

#define LOG(args ...) NSLog(@"🔴 %@ ", [NSString stringWithFormat:args])

static BOOL iPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;

static NSString *machineName() {
    struct utsname systemInfo;
    uname(&systemInfo);

    return [NSString stringWithCString:systemInfo.machine
            encoding:NSUTF8StringEncoding];
}

static BOOL supportsBlur(PSListController* lc) {
    NSSet* graphicsQuality = [NSSet setWithObjects:@"iPad",
                              @"iPad1,1",
                              @"iPhone1,1",
                              @"iPhone1,2",
                              @"iPhone2,1",
                              @"iPhone3,1",
                              @"iPhone3,2",
                              @"iPhone3,3",
                              @"iPod1,1",
                              @"iPod2,1",
                              @"iPod2,2",
                              @"iPod3,1",
                              @"iPod4,1",
                              @"iPad2,1",
                              @"iPad2,2",
                              @"iPad2,3",
                              @"iPad2,4",
                              @"iPad3,1",
                              @"iPad3,2",
                              @"iPad3,3",
                              nil];
    return ! [graphicsQuality containsObject:machineName()];
}

static UIColor *UIColorFromHexString(NSString* hexString) {
    if (! hexString) {
        return [UIColor clearColor];
    }

    unsigned rgbValue = 0;
    NSScanner* scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1];
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

static NSString *HexStringFromUIColor(UIColor* colour) {
    CGFloat r, g, b, a;
    [colour getRed:&r green:&g blue:&b alpha:&a];
    int rgb = (int)(r * 255.0f)<<16 | (int)(g * 255.0f)<<8 | (int)(b * 255.0f)<<0;
    return [NSString stringWithFormat:@"#%06x", rgb];
}

__attribute__((always_inline)) static BOOL bengo() {
    return [[NSFileManager defaultManager] fileExistsAtPath:listPath];
}

@interface CHTinctPrefsListController:PSListController
@end

@implementation CHTinctPrefsListController
-(id) readPreferenceValue:(PSSpecifier*)specifier {
    NSDictionary* dic = [NSDictionary dictionaryWithContentsOfFile:prefsPath];
    id val = nil;
    if (! dic[specifier.properties[@"key"]]) {
        val = specifier.properties[@"default"];
    }
    else {
        val = dic[specifier.properties[@"key"]];
    }

    if ([specifier.properties[@"negate"] boolValue]) {
        val = [NSNumber numberWithInt:(NSInteger)! [val boolValue]];
    }
    return val;
}

-(void) setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    [super setPreferenceValue:value specifier:specifier];
    NSMutableDictionary* defaults = [NSMutableDictionary dictionary];
    [defaults addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:prefsPath]];
    if ([specifier.properties[@"negate"] boolValue]) {
        [defaults setObject:[NSNumber numberWithInt:(NSInteger)! [value boolValue]] forKey:specifier.properties[@"key"]];
    }
    else {
        [defaults setObject:value forKey:specifier.properties[@"key"]];
    }
    [defaults writeToFile:prefsPath atomically:YES];
    CFStringRef toPost = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
    if (toPost) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), toPost, NULL, NULL, YES);
    }
}

@end

@interface TinctPrefsListController:CHTinctPrefsListController <MFMailComposeViewControllerDelegate, UIAlertViewDelegate>
-(void) showDisableAlert;
-(void) resetSettings;
@end

@implementation TinctPrefsListController

-(id) specifiers {
    if (_specifiers == nil) {
        UIBarButtonItem* likeButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageWithContentsOfFile:@"/Library/PreferenceBundles/TinctPrefs.bundle/heart.png"] style:UIBarButtonItemStylePlain target:self action:@selector(composeTweet)];
        ((UINavigationItem*)self.navigationItem).rightBarButtonItem = likeButton;

        NSArray* advancedSpecs = [self loadSpecifiersFromPlistName:@"TinctAdvancedPrefs" target:nil];
        BOOL NCEnabled = [[self readPreferenceValue:[advancedSpecs objectAtIndex:1]] boolValue];
        BOOL CCEnabled = [[self readPreferenceValue:[advancedSpecs objectAtIndex:2]] boolValue];
        BOOL HUDEnabled = [[self readPreferenceValue:[advancedSpecs objectAtIndex:3]] boolValue];
        BOOL KeyboardEnabled = [[self readPreferenceValue:[advancedSpecs objectAtIndex:4]] boolValue];

        _specifiers = [self loadSpecifiersFromPlistName:@"TinctPrefs" target:self];

        BOOL BlendEnabled = [[self readPreferenceValue:[self specifierForID:@"blendEnabled"]] boolValue];
        if (! supportsBlur(self)) {
            BlendEnabled = NO;
        }

        NSMutableArray* newSpecs = [NSMutableArray arrayWithArray:_specifiers];
        for (PSSpecifier* spec in _specifiers) {
            if ([spec.identifier isEqualToString:@"NCColour"] && ! NCEnabled) {
                [newSpecs removeObject:spec];
            }
            else if ([spec.identifier isEqualToString:@"CCColour"] && ! CCEnabled) {
                [newSpecs removeObject:spec];
            }
            else if ([spec.identifier isEqualToString:@"HUDColour"] && ! HUDEnabled) {
                [newSpecs removeObject:spec];
            }
            else if ([spec.identifier isEqualToString:@"KeyboardColour"] && ! KeyboardEnabled) {
                [newSpecs removeObject:spec];
            }
            else if (([spec.identifier isEqualToString:@"BarBGColour"] || [spec.identifier isEqualToString:@"BarFGColour"] || [spec.identifier isEqualToString:@"BarTColour"]) && BlendEnabled) {
                [newSpecs removeObject:spec];
            }
            else if (([spec.identifier isEqualToString:@"AppTintGroup"] || [spec.identifier isEqualToString:@"BlendedDarkTint"] || [spec.identifier isEqualToString:@"BlendedLightTint"]) && ! BlendEnabled) {
                [newSpecs removeObject:spec];
            }
            else if ([spec.identifier isEqualToString:@"blendEnabled"] && ! supportsBlur(self)) {
                [newSpecs removeObject:spec];
            }

            if ([spec.identifier isEqualToString:@"OtherColoursGroup"] && ! KeyboardEnabled && ! HUDEnabled && ! CCEnabled && ! NCEnabled) {
                [newSpecs removeObject:spec];
            }
        }

        PSSpecifier* copyright = [self specifierForID:@"copyright"];
        NSString* footer = [copyright propertyForKey:@"footerText"];
        if (! bengo()) {
            footer = [footer stringByReplacingOccurrencesOfString:@"$" withString:[NSString stringWithFormat:@"%@ ☠", TWEAK_VERSION]];
        }
        else {
            footer = [footer stringByReplacingOccurrencesOfString:@"$" withString:TWEAK_VERSION];
        }
        [copyright setProperty:footer forKey:@"footerText"];
        _specifiers = [NSArray arrayWithArray:newSpecs];

        PSSpecifier* supportGroup = [self specifierForID:@"supportGroup"];
        if (! bengo()) {
            [supportGroup setProperty:@"If you like Tinct, please consider supporting future development by purchasing." forKey:@"footerText"];
        }
    }
    return _specifiers;
}

-(void) viewWillAppear:(BOOL)b {
    [super viewWillAppear:b];
    [self reloadSpecifiers];
}

-(void) composeTweet {
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {
        SLComposeViewController* tweetSheet = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
        NSString* device = @"iPhone";
        if (iPad) {
            device = @"iPad";
        }
        [tweetSheet setInitialText:[NSString stringWithFormat:@"I'm using Tinct (by @friggog) to customise my %@'s UI!", device]];
        UIViewController* rootViewController = (UIViewController*)[[[UIApplication sharedApplication] keyWindow] rootViewController];
        [rootViewController presentViewController:tweetSheet animated:YES completion:nil];
    }
    else {
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Error"
                              message:@"Unable to tweet at this time."
                              delegate:self
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
        [alert show];
    }
}

-(void) openEmailLink {
    NSString* currSysVer = [[UIDevice currentDevice] systemVersion];
    NSString* device = machineName();
    NSString* tweakVer = TWEAK_VERSION;
    if (! bengo()) {
        tweakVer = [tweakVer stringByAppendingString:@"."];
    }

    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController* picker = [[MFMailComposeViewController alloc] init];
        picker.mailComposeDelegate = self;

        [picker setSubject:[NSString stringWithFormat:@"Tinct %@ - %@ : %@", tweakVer, device, currSysVer]];

        NSArray* toRecipients = [NSArray arrayWithObject:@"contact@chewitt.me"];
        [picker setToRecipients:toRecipients];

        UIViewController* rootViewController = (UIViewController*)[[[UIApplication sharedApplication] keyWindow] rootViewController];
        [rootViewController presentViewController:picker animated:YES completion:NULL];
    }
    else {
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Error"
                              message:@"You seem to be unable to send emails."
                              delegate:self
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil
                              , nil];
        [alert show];
    }
}

-(void) mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    [controller dismissViewControllerAnimated:YES completion:NULL];
}

-(void) openTwitterLink {
    NSURL* appURL = [NSURL URLWithString:@"twitter:///user?screen_name=friggog"];
    if ([[UIApplication sharedApplication] canOpenURL:appURL]) {
        [[UIApplication sharedApplication] openURL:appURL];
    }
    else {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://twitter.com/friggog"]];
    }
}

-(void) setBlended:(id)value specifier:(id)specifier {
    [self setPreferenceValue:value specifier:specifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
    id prefs = [self loadSpecifiersFromPlistName:@"TinctPrefs" target:self];
    if ([value boolValue]) {
        [self removeSpecifier:[self specifierForID:@"BarBGColour"] animated:YES];
        [self removeSpecifier:[self specifierForID:@"BarFGColour"] animated:YES];
        [self removeSpecifier:[self specifierForID:@"BarTColour"] animated:YES];
        [self insertSpecifier:[prefs objectAtIndex:8] afterSpecifier:[self specifierForID:@"blendEnabled"] animated:YES];
        [self insertSpecifier:[prefs objectAtIndex:9] afterSpecifier:[self specifierForID:@"AppTintGroup"] animated:YES];
        [self insertSpecifier:[prefs objectAtIndex:10] afterSpecifier:[self specifierForID:@"BlendedDarkTint"] animated:YES];
    }
    else {
        [self removeSpecifier:[self specifierForID:@"AppTintGroup"] animated:YES];
        [self insertSpecifier:[prefs objectAtIndex:5] afterSpecifier:[self specifierForID:@"blendEnabled"] animated:YES];
        [self insertSpecifier:[prefs objectAtIndex:6] afterSpecifier:[self specifierForID:@"BarBGColour"] animated:YES];
        [self insertSpecifier:[prefs objectAtIndex:7] afterSpecifier:[self specifierForID:@"BarFGColour"] animated:YES];
    }
    [self performSelector:@selector(reloadSpecifiers) withObject:nil afterDelay:0.2];
}

-(void) setEnabledWithValue:(id)value andSpecifier:(id)specifier {
    [self setPreferenceValue:value specifier:specifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self showDisableAlert];
}

-(void) showDisableAlert {
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Respring Required"
                          message:@"To properly enable/disable Tinct you need to respring."
                          delegate:self
                          cancelButtonTitle:@"Later"
                          otherButtonTitles:@"Respring"
                          , nil];
    alert.tag = 123123;
    [alert show];
}

-(void) alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        if (alertView.tag == 123123) {
            BKSTerminateApplicationGroupForReasonAndReportWithDescription(1, 5, 0, NULL);
            system_nd("killall backboardd");
        }
        else if (alertView.tag == 54353) {
            [self resetSettings];
        }
    }
}

-(void) resetDefaults {
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Reset to Defaults"
                          message:@"Are you want to reset to default colours?"
                          delegate:self
                          cancelButtonTitle:@"No"
                          otherButtonTitles:@"Yes"
                          , nil];
    alert.tag = 54353;
    [alert show];
}

-(void) resetSettings {
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    [dict setValue:[NSNumber numberWithInt:0] forKey:@"Enabled"];
    [dict setValue:[NSNumber numberWithInt:0] forKey:@"blendEnabled"];
    [dict setValue:@"#FFFFFF" forKey:@"BarBGColour"];
    [dict setValue:@"#007AFF" forKey:@"BarFGColour"];
    [dict setValue:@"#000000" forKey:@"BarTColour"];
    [dict setValue:@"#000000" forKey:@"NCColour"];
    [dict setValue:@"#FFFFFF" forKey:@"CCColour"];
    [dict setValue:@"#FFFFFF" forKey:@"HUDColour"];
    [dict setValue:@"#EEEEEE" forKey:@"KeyboardColour"];
    [dict setValue:@"#FFFFFF" forKey:@"BlendedLightTint"];
    [dict setValue:@"#007AFF" forKey:@"BlendedDarkTint"];
    [dict writeToFile:@"/var/mobile/Library/Preferences/me.chewitt.tinctprefs.plist" atomically:YES];
    CFStringRef toPost = (__bridge CFStringRef)@"me.chewitt.tinctprefs.settingschanged";
    if (toPost) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), toPost, NULL, NULL, YES);
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadSpecifiers];
}

-(void) killAllApps {
    BKSTerminateApplicationGroupForReasonAndReportWithDescription(1, 5, 0, NULL);
}

@end

@interface TinctAdvancedController:CHTinctPrefsListController {}
@end

@implementation TinctAdvancedController
-(id) specifiers {
    if (_specifiers == nil) {
        UIBarButtonItem* likeButton = [[UIBarButtonItem alloc] initWithTitle:@"Respring" style:UIBarButtonItemStylePlain target:self action:@selector(respring)];
        ((UINavigationItem*)self.navigationItem).rightBarButtonItem = likeButton;
        _specifiers = [self loadSpecifiersFromPlistName:@"TinctAdvancedPrefs" target:self];// retain];
    }
    return _specifiers;
}

-(void) respring {
    system_nd("killall backboardd");
}

@end

@interface TinctHelpController:CHTinctPrefsListController
@end

@implementation TinctHelpController
-(id) specifiers {
    if (_specifiers == nil) {
        _specifiers = [self loadSpecifiersFromPlistName:@"TinctHelpPrefs" target:self];
    }
    return _specifiers;
}

@end

@interface TinctInfoController:CHTinctPrefsListController {}
@end

@implementation TinctInfoController
-(id) specifiers {
    if (_specifiers == nil) {
        _specifiers = [self loadSpecifiersFromPlistName:@"TinctInfoPrefs" target:self];// retain];
    }
    return _specifiers;
}

@end

@interface TinctColourPickerController:CHTinctPrefsListController {
    HRColorPickerView* colorPickerView;
}
@end

@implementation TinctColourPickerController

-(id) specifiers {
    if (_specifiers == nil) {
        if (! colorPickerView) {
            [self performSelector:@selector(createPickerView) withObject:nil afterDelay:0.01];
        }
        PSSpecifier* spec = [PSSpecifier preferenceSpecifierNamed:@" "
                             target:self
                             set:nil
                             get:nil
                             detail:nil
                             cell:[PSTableCell cellTypeFromString:@"PSGroupCell"]
                             edit:0];
        _specifiers = [NSArray arrayWithObjects:spec, nil];
    }
    return _specifiers;
}

-(void) createPickerView {
    colorPickerView = [[HRColorPickerView alloc] init];
    CGRect frame = ((UIView*)self.table).frame;
    frame = CGRectMake(0, 0, frame.size.width, frame.size.height-66);
    if (iPad) {
        frame = CGRectMake(frame.size.width/2-200, 25, 400, 600);
    }
    colorPickerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    colorPickerView.frame = frame;
    colorPickerView.backgroundColor = [UIColor clearColor];
    UIColor* col = UIColorFromHexString([self.specifier propertyForKey:@"default"]);
    if ([self readPreferenceValue:self.specifier]) {
        col = UIColorFromHexString([self readPreferenceValue:self.specifier]);
    }
    colorPickerView.color = col;
    colorPickerView.alphaValue = 1.0;
    [colorPickerView addTarget:self action:@selector(action:) forControlEvents:UIControlEventValueChanged];
    [self.table addSubview:colorPickerView];
}

-(void) action:(HRColorPickerView*)obj {
    [self setPreferenceValue:HexStringFromUIColor(obj.color) specifier:self.specifier];
    [(PSListController*)_parentController reloadSpecifier:self.specifier];
}

@end

@interface TinctPresetsController:CHTinctPrefsListController <UIAlertViewDelegate, UITextFieldDelegate, UIActionSheetDelegate> {
    NSDictionary* themeDic;
    NSString* newThemeName;
}
@end

@implementation TinctPresetsController
-(id) specifiers {
    if (_specifiers == nil) {
        _specifiers = [self loadSpecifiersFromPlistName:@"TinctPresetsPrefs" target:self];
        [self updatePresetList];
    }
    return _specifiers;
}

-(void) updatePresetList {
    NSString* documentsDirectory = @"/var/mobile/Library/Tinct/Themes";
    NSFileManager* fM = [NSFileManager defaultManager];
    NSArray* fileList = [fM contentsOfDirectoryAtPath:documentsDirectory error:nil];
    NSMutableArray* themeFiles = [NSMutableArray array];
    NSMutableArray* themeNames = [NSMutableArray array];
    for (NSString* file in fileList) {
        NSString* path = [documentsDirectory stringByAppendingPathComponent:file];
        BOOL isDir = NO;
        BOOL fileExists = [fM fileExistsAtPath:path isDirectory:(&isDir)];
        if (! isDir && fileExists) {
            [themeFiles addObject:file];
            [themeNames addObject:[file stringByReplacingOccurrencesOfString:@"_" withString:@" "]];
        }
    }
    themeDic = [NSDictionary dictionaryWithObjects:themeFiles forKeys:themeNames];
}

-(void) deletePreset {
    [self presentThemeActionSheetWithTitle:@"Delete Preset" andTag:3762384];
}

-(void) loadPreset {
    [self presentThemeActionSheetWithTitle:@"Load Preset" andTag:76782163];
}

-(void) savePreset {
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Preset Name"
                          message:@"Enter name for preset being saved."
                          delegate:self
                          cancelButtonTitle:@"Cancel"
                          otherButtonTitles:@"Enter"
                          , nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
    [[alert textFieldAtIndex:0] setDelegate:self];
    [[alert textFieldAtIndex:0] resignFirstResponder];
    [alert textFieldAtIndex:0].autocapitalizationType = UITextAutocapitalizationTypeSentences;
    [[alert textFieldAtIndex:0] becomeFirstResponder];
    alert.tag = 837264;
}

-(void) presentThemeActionSheetWithTitle:(NSString*)title andTag:(long)tag {
    UIActionSheet* actionSheet = [[UIActionSheet alloc] initWithTitle:title
                                  delegate:self
                                  cancelButtonTitle:nil
                                  destructiveButtonTitle:nil
                                  otherButtonTitles:nil];

    actionSheet.tag = tag;

    for (NSString* t in [themeDic allKeys]) {
        [actionSheet addButtonWithTitle:t];
    }

    [actionSheet addButtonWithTitle:@"Cancel"];
    actionSheet.cancelButtonIndex = actionSheet.numberOfButtons - 1;

    [actionSheet showInView:[UIApplication sharedApplication].keyWindow];
}

-(void) actionSheet:(UIActionSheet*)popup clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex < popup.numberOfButtons - 1) {
        NSString* themeForAction = [themeDic valueForKey:[[themeDic allKeys] objectAtIndex:buttonIndex]];

        if (popup.tag == 76782163) { /// LOAD
            [NSUserDefaults resetStandardUserDefaults];
            NSString* com = [NSString stringWithFormat:@"cp -f /var/mobile/Library/Tinct/Themes/%@ %@", themeForAction,prefsPath];
            system_nd([com UTF8String]);
            [[NSUserDefaults standardUserDefaults] synchronize];
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.chewitt.tinctprefs.settingschanged"), nil, nil, true);
            [self performSelector:@selector(forcedReload) withObject:nil afterDelay:0.3];
        }
        else if (popup.tag == 3762384) { /// DELETE
            NSString* com = [NSString stringWithFormat:@"rm -rf /var/mobile/Library/Tinct/Themes/%@", themeForAction];
            system_nd([com UTF8String]);
            [self updatePresetList];
        }
    }
}

-(void) forcedReload {
    [self reload];
    [self.navigationController.navigationBar layoutSubviews];
}

-(void) alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        if (alertView.tag == 837264) {
            newThemeName = [alertView textFieldAtIndex:0].text;
            newThemeName = [newThemeName stringByReplacingOccurrencesOfString:@" " withString:@"_"];
            NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"[^a-zA-Z0-9_-]+" options:0 error:nil];
            newThemeName = [regex stringByReplacingMatchesInString:newThemeName options:0 range:NSMakeRange(0, newThemeName.length) withTemplate:@""];

            if ([[themeDic allValues] containsObject:newThemeName]) {
                UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                      message:@"A preset with this name already exists, do you want to overwrite it?"
                                      delegate:self
                                      cancelButtonTitle:@"No"
                                      otherButtonTitles:@"Yes", nil];
                alert.tag = 345345;
                [alert show];
            }
            else {
                NSString* com = [NSString stringWithFormat:@"cp -f %@ /var/mobile/Library/Tinct/Themes/%@", prefsPath, newThemeName];
                system_nd([com UTF8String]);
                [self updatePresetList];
            }
        }
        else if (alertView.tag == 345345) {
            NSString* com = [NSString stringWithFormat:@"cp -f %@ /var/mobile/Library/Tinct/Themes/%@", prefsPath, newThemeName];
            system_nd([com UTF8String]);
            [self updatePresetList];
        }
    }
}

@end

@interface TinctLinkToColourPickerCell:PSTableCell {
    CircleColourView* circle;
}
@end

@implementation TinctLinkToColourPickerCell
-(id) initWithStyle:(NSInteger)arg1 reuseIdentifier:(id)arg2 specifier:(id)arg3 {
    self = [super initWithStyle:arg1 reuseIdentifier:arg2 specifier:arg3];
    if (self) {
        circle = [[CircleColourView alloc] initWithFrame:CGRectMake(self.frame.size.width-30, 7, 30, 30) andColour:[UIColor clearColor]];
        [self.contentView addSubview:circle];
        [self valueLabel].hidden = YES;
    }
    return self;
}

-(void) setValue:(id)value {
    [super setValue:value];
    UIColor* col = UIColorFromHexString(value);
    circle.backgroundColor = col;
}

@end

@interface TinctBannerCell:PSTableCell {}
@end

@implementation TinctBannerCell

-(id) initWithStyle:(NSInteger)arg1 reuseIdentifier:(id)arg2 specifier:(id)arg3 {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:arg2 specifier:arg3];
    if (self) {
        CGRect frame = [self frame];
        frame.size.height = 100;

        NSString* bundleName = @"TinctPrefs";

        UIView* containerView = [[UIView alloc] initWithFrame:frame];
        containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        containerView.clipsToBounds = YES;

        UIImageView* titleImage = [[UIImageView alloc] initWithFrame:frame];
        if (iPad) {
            titleImage.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"/Library/PreferenceBundles/%@.bundle/banner_ipad.png", bundleName]];
            containerView.layer.cornerRadius = 5;
        }
        else {
            titleImage.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"/Library/PreferenceBundles/%@.bundle/banner_iphone.png", bundleName]];
        }

        titleImage.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        titleImage.contentMode = UIViewContentModeScaleAspectFill;

        [containerView addSubview:titleImage];
        [self.contentView addSubview:containerView];
    }
    return self;
}

@end
