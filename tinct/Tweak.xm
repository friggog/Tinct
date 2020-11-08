#import "Headers.h"

#define PreferencesChangedNotification "me.chewitt.tinctprefs.settingschanged"
#define PreferencesFilePath @"/var/mobile/Library/Preferences/me.chewitt.tinctprefs.plist"
#define ExcludedListFilePath @"/var/mobile/Library/Preferences/me.chewitt.tinctprefs.excluded.plist"
#define asRedColor [UIColor colorWithRed:253.0/255.0 green:71.0/255.0 blue:43.0/255.0 alpha:1]

#define LOG(args ...) NSLog(@"🔴 %@ ", [NSString stringWithFormat:args])

#define isCurrentApp(string) [[[NSBundle mainBundle] bundleIdentifier] isEqual:string]
#define IS_IOS_7_1 ([[[UIDevice currentDevice] systemVersion] compare:@"7.1" options:NSNumericSearch] != NSOrderedAscending)
#define IS_IOS_8 ([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending)
#define DEVICE_IS_IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)

static NSDictionary* preferences;
static NSDictionary* excludedApps;
static NSMutableArray* excludedAppsArray;
static UIColor* darkColour;
static UIColor* lightColour;
static UIColor* barBGColour;
static UIColor* barFGColour;
static UIColor* barTColour;
static UIColor* tabBarSecondaryColour;
static UIColor* ncColour;
static UIColor* ccColour;
static UIColor* hudColour;
static UIColor* keyboardColour;
static BOOL enabled;
static BOOL ncEnabled;
static BOOL ccEnabled;
static BOOL hudEnabled;
static BOOL asEnabled;
static BOOL kEnabled;
static BOOL statusEnabled;
static BOOL spotEnabled;
static BOOL blendEnabled;
static BOOL chromaForExcluded;
static BOOL usesAppleBlackBars;
static BOOL translucencyEnabled;

static BOOL supportsBlur(_UIBackdropView* bv) {
    if ([bv respondsToSelector:@selector(backdropEffectView)]) {
        return bv.backdropEffectView != nil;
    }
    else {
        return NO;
    }
}

static UIColor *UIColorFromHexString(NSString* hexString) {
    if (! hexString) {
        return [UIColor clearColor];
    }
    unsigned rgbValue = 0;
    NSScanner* scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

static CGFloat darknessForUIColor(UIColor* col) {
    const CGFloat* componentColors = CGColorGetComponents(col.CGColor);
    return (componentColors[0] * 0.299) + (componentColors[1] * 0.587) + (componentColors[2] * 0.114);
}

static UIColor *brightnessAlteredColour(UIColor* color, CGFloat amount) {
    CGFloat hue, saturation, brightness, alpha;
    if ([color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
        brightness += (amount-1.0);
        brightness = MAX(MIN(brightness, 1.0), 0.0);
        return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
    }

    CGFloat white;
    if ([color getWhite:&white alpha:&alpha]) {
        white += (amount-1.0);
        white = MAX(MIN(white, 1.0), 0.0);
        return [UIColor colorWithWhite:white alpha:alpha];
    }
    return nil;
}

static UIColor *darkenedColourFromColour(UIColor* col) {
    return brightnessAlteredColour(col, 0.9);
}

static UIColor *lightenedColourFromColour(UIColor* col) {
    return brightnessAlteredColour(col, 1.1);
}

static BOOL areSimilarColours(UIColor* col1, UIColor* col2) {
    if (col1 != nil && col2 != nil) {
        CGFloat tolerance = 0.2;
        CGFloat r1, g1, b1, a1, r2, g2, b2, a2;
        [col1 getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
        [col2 getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
        return
            fabs(r1 - r2) <= tolerance &&
            fabs(g1 - g2) <= tolerance &&
            fabs(b1 - b2) <= tolerance &&
            fabs(a1 - a2) <= tolerance;
    }
    return NO;
}

static void updatePrefs() {
    preferences = [[NSDictionary alloc] initWithContentsOfFile:PreferencesFilePath];

    if ([preferences valueForKey:@"BarBGColour"]) {
        barBGColour = UIColorFromHexString([preferences valueForKey:@"BarBGColour"]);
    }
    if ([preferences valueForKey:@"BarFGColour"]) {
        barFGColour = UIColorFromHexString([preferences valueForKey:@"BarFGColour"]);
    }
    if ([preferences valueForKey:@"BarTColour"]) {
        barTColour = UIColorFromHexString([preferences valueForKey:@"BarTColour"]);
    }

    if ([preferences valueForKey:@"CCColour"]) {
        ccColour = UIColorFromHexString([preferences valueForKey:@"CCColour"]);
    }
    if ([preferences valueForKey:@"NCColour"]) {
        ncColour = UIColorFromHexString([preferences valueForKey:@"NCColour"]);
    }
    if ([preferences valueForKey:@"HUDColour"]) {
        hudColour = UIColorFromHexString([preferences valueForKey:@"HUDColour"]);
    }
    if ([preferences valueForKey:@"KeyboardColour"]) {
        keyboardColour = UIColorFromHexString([preferences valueForKey:@"KeyboardColour"]);
    }

    if (! barBGColour) {
        barBGColour = [UIColor whiteColor];
    }
    if (! barFGColour) {
        barFGColour = [UIColor systemBlueColor];
    }
    if (! barTColour) {
        barTColour = [UIColor blackColor];
    }
    if (! ccColour) {
        ccColour = [UIColor whiteColor];
    }
    if (! ncColour) {
        ncColour = [UIColor blackColor];
    }
    if (! hudColour) {
        hudColour = [UIColor whiteColor];
    }
    if (! keyboardColour) {
        keyboardColour = UIColorFromHexString(@"#EEEEEE");
    }

    if (darknessForUIColor(barFGColour) < 0.7) {
        darkColour =  barFGColour;
    }
    else if (darknessForUIColor(barBGColour) < 0.7) {
        darkColour = barBGColour;
    }
    else {
        darkColour = barTColour;
    }

    if (darknessForUIColor(barFGColour) > 0.4) {
        lightColour =  barFGColour;
    }
    else if (darknessForUIColor(barBGColour) > 0.4) {
        lightColour = barBGColour;
    }
    else {
        lightColour = barTColour;
    }

    tabBarSecondaryColour = barTColour;
    if (areSimilarColours(barFGColour, barTColour)) {
        tabBarSecondaryColour = [tabBarSecondaryColour colorWithAlphaComponent:0.5];
    }

    if ([preferences valueForKey:@"translucencyEnabled"]) {
        translucencyEnabled = ! [[preferences valueForKey:@"translucencyEnabled"] boolValue];
    }
    else {
        translucencyEnabled = YES;
    }

    if ([preferences valueForKey:@"ncEnabled"]) {
        ncEnabled = ! [[preferences valueForKey:@"ncEnabled"] boolValue];
    }
    else {
        ncEnabled = YES;
    }

    if ([preferences valueForKey:@"ccEnabled"]) {
        ccEnabled = ! [[preferences valueForKey:@"ccEnabled"] boolValue];
    }
    else {
        ccEnabled = YES;
    }

    if ([preferences valueForKey:@"asEnabled"]) {
        asEnabled = ! [[preferences valueForKey:@"asEnabled"] boolValue];
    }
    else {
        asEnabled = YES;
    }

    if ([preferences valueForKey:@"HUDEnabled"]) {
        hudEnabled = ! [[preferences valueForKey:@"HUDEnabled"] boolValue];
    }
    else {
        hudEnabled = YES;
    }

    if ([preferences valueForKey:@"kEnabled"]) {
        kEnabled = ! [[preferences valueForKey:@"kEnabled"] boolValue];
    }
    else {
        kEnabled = YES;
    }

    if ([preferences valueForKey:@"statusEnabled"]) {
        statusEnabled = ! [[preferences valueForKey:@"statusEnabled"] boolValue];
    }
    else {
        statusEnabled = YES;
    }

    if ([preferences valueForKey:@"spotEnabled"]) {
        spotEnabled = ! [[preferences valueForKey:@"spotEnabled"] boolValue];
    }
    else {
        spotEnabled = YES;
    }

    if ([preferences valueForKey:@"blendEnabled"]) {
        blendEnabled = [[preferences valueForKey:@"blendEnabled"] boolValue];
    }
    else {
        blendEnabled = NO;
    }

    if ([preferences valueForKey:@"Enabled"]) {
        enabled = ! [[preferences valueForKey:@"Enabled"] boolValue];
    }
    else {
        enabled = YES;
    }

    if ([preferences valueForKey:@"chromaForExcluded"]) {
        chromaForExcluded = [[preferences valueForKey:@"chromaForExcluded"] boolValue];
    }
    else {
        chromaForExcluded = NO;
    }

    if ([preferences valueForKey:@"useAppleBlackBars"]) {
        usesAppleBlackBars = [[preferences valueForKey:@"useAppleBlackBars"] boolValue];
    }
    else {
        usesAppleBlackBars = NO;
    }

    if (blendEnabled) {
        barFGColour = [UIColor colorWithWhite:0.7 alpha:1];
        barTColour = [UIColor colorWithWhite:0.7 alpha:1];
        tabBarSecondaryColour = [UIColor colorWithWhite:0.4 alpha:1];
        barBGColour = [UIColor colorWithWhite:0 alpha:0.8];

        if ([preferences valueForKey:@"BlendedDarkTint"]) {
            darkColour = UIColorFromHexString([preferences valueForKey:@"BlendedDarkTint"]);
        }
        else {
            darkColour = UIColorFromHexString(@"#007AFF");
        }

        if ([preferences valueForKey:@"BlendedLightTint"]) {
            lightColour = UIColorFromHexString([preferences valueForKey:@"BlendedLightTint"]);
        }
        else {
            lightColour = UIColorFromHexString(@"#FFFFFF");
        }
    }

    excludedApps = [[NSDictionary alloc] initWithContentsOfFile:ExcludedListFilePath];
    excludedAppsArray = [NSMutableArray array];

    for (id key in excludedApps) {
        if ([[excludedApps valueForKey:key] boolValue] == YES) {
            [excludedAppsArray addObject:key];
        }
    }
}

static void PreferencesChangedCallback(CFNotificationCenterRef center, void* observer, CFStringRef name, const void* object, CFDictionaryRef userInfo) {
    updatePrefs();
}

static UIImage *imageWithBurnTint(UIImage* img, UIColor* color) {
    // lets tint the icon - assumes your icons are black
    UIGraphicsBeginImageContextWithOptions(img.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextTranslateCTM(context, 0, img.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

    CGRect rect = CGRectMake(0, 0, img.size.width, img.size.height);

    // draw alpha-mask
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextDrawImage(context, rect, img.CGImage);

    // draw tint color, preserving alpha values of original image
    CGContextSetBlendMode(context, kCGBlendModeSourceIn);
    [color setFill];
    CGContextFillRect(context, rect);

    UIImage* coloredImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return coloredImage;
}

static BOOL isBlackColour(UIColor* test) {
    if (usesAppleBlackBars) {
        if ([test isEqual:[UIColor blackColor]]) {
            return YES;
        }
        else if ([test isEqual:[UIColor colorWithRed:0 green:0 blue:0 alpha:1]]) {
            return YES;
        }
        else if ([test isEqual:UIColorFromHexString(@"#000000")]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark BLEND

%group BLEND

%hook UIStatusBar

-(void)layoutSubviews {
    %orig;
    if (self.tag != 127123998 && ! isCurrentApp(@"com.apple.springboard") && ! isCurrentApp(@"com.apple.mobilenotes") && ! isCurrentApp(@"com.apple.mobilenotes") && ! isCurrentApp(@"com.apple.Maps")) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
    else {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeNormal];
    }
}

%end

%hook UINavBarPrompt

-(void)layoutSubviews {
    %orig;
    [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
}

%end

%hook UITabBarButton

-(void)setFrame:(CGRect)frame {
    %orig;
    [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
}

%end

%hook UIToolbarButton

-(void)layoutSubviews {
    %orig;
    [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
}

%end

%hook UINavigationButton

-(void)layoutSubviews {
    %orig;
    if (((UIView*)self).superview.tag != 1238973798 && ! [self.superview.superview isKindOfClass:%c(SBSearchHeader)] && ! [self.superview isKindOfClass:%c(SBSearchHeader)]) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
    else {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeNormal];
    }
}

%end

%hook UISegmentedControl

-(void)layoutSubviews {
    %orig;
    if (! isCurrentApp(@"com.apple.mobileme.fmip1") && ! isCurrentApp(@"com.apple.springboard") ) {
        BOOL shouldBeDark = [self.superview.superview.superview isKindOfClass:%c(UISearchBar)] || [self isKindOfClass:%c(SKUIProductPageSegmentedControl)] || [self.superview.superview isKindOfClass:%c(VideosDetailHeaderView)] || [self isKindOfClass:%c(BKSegmentedControl)] || [self.superview.superview isKindOfClass:%c(IMToolbar)] || [self.superview.superview isKindOfClass:%c(SKUISegmentedTableHeaderView)] || [self.superview isKindOfClass:%c(SKUISegmentedTableHeaderView)] || [self.superview isKindOfClass:%c(UITableViewCellContentView)] || [self.superview.superview isKindOfClass:%c(SUSegmentedControlBar)] || [self.superview isKindOfClass:%c(GKSegmentedSectionHeaderView)];
        if (! shouldBeDark) {
            [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        }
        else {
            [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeNormal];
        }
    }
}

-(void) didMoveToSuperview {
    %orig;
    if (! isCurrentApp(@"com.apple.mobileme.fmip1") && ! isCurrentApp(@"com.apple.springboard") ) {
        BOOL shouldBeDark = [self.superview.superview.superview isKindOfClass:%c(UISearchBar)] || [self isKindOfClass:%c(SKUIProductPageSegmentedControl)] || [self.superview.superview isKindOfClass:%c(VideosDetailHeaderView)] || [self isKindOfClass:%c(BKSegmentedControl)] || [self.superview.superview isKindOfClass:%c(IMToolbar)] || [self.superview.superview isKindOfClass:%c(SKUISegmentedTableHeaderView)] || [self.superview isKindOfClass:%c(SKUISegmentedTableHeaderView)] || [self.superview isKindOfClass:%c(UITableViewCellContentView)] || [self.superview.superview isKindOfClass:%c(SUSegmentedControlBar)] || [self.superview isKindOfClass:%c(GKSegmentedSectionHeaderView)];
        if (! shouldBeDark) {
            [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        }
        else {
            [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeNormal];
        }
    }
}

%end

%hook UINavigationItemButtonView

-(void)layoutSubviews {
    %orig;
    if (((UIView*)self).superview.tag != 1238973798) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
    else {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeNormal];
    }
}

%end

%hook UINavigationItemView

-(void)layoutSubviews {
    %orig;
    if (((UIView*)self).superview.tag != 1238973798) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
    else {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeNormal];
    }
}

%end

%hook _UINavigationBarBackIndicatorView

-(void)layoutSubviews {
    %orig;
    if (((UIView*)self).tag != 1238973798) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
    else {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeNormal];
    }
}

%end

%end//BLEND

#pragma mark CHROMA

%group CHROMA

%hook UIColor
+(id)systemBlueColor {
    return darkColour;
}
+(id) systemRedColor {
    if ((isCurrentApp(@"com.apple.mobilecal") || isCurrentApp(@"com.apple.mobiletimer"))) {
        return darkColour;
    }
    else {
        return %orig;
    }
}/*
    +(id)systemGreenColor{
    if(enabled)
      return darkColour;
    else
      return %orig;
    }*/

+(id) systemOrangeColor {
    if (! isCurrentApp(@"com.apple.mobilemail")) {
        return darkColour;
    }
    else {
        return %orig;
    }
}

+(id) systemYellowColor {
    return lightColour;
}

+(id) systemTealColor {
    return darkColour;
}

+(id) systemPinkColor {
    return darkColour;
}

+(id) _systemInteractionTintColor {
    return darkColour;
}

+(id) _systemSelectedColor {
    return darkColour;
}

+(id) systemDarkRedColor {
    return darkColour;
}

+(id) systemDarkGreenColor {
    return darkColour;
}

+(id) systemDarkBlueColor {
    return darkColour;
}

+(id) systemDarkOrangeColor {
    return darkColour;
}

+(id) systemDarkTealColor {
    return darkColour;
}

+(id) systemDarkPinkColor {
    return darkColour;
}

+(id) systemDarkYellowColor {
    return darkColour;
}

/*
   +(id)externalSystemTealColor {
   return darkColour;
   }
   +(id)externalSystemRedColor{
   return darkColour;
   }
   +(id)externalSystemGreenColor{
   return darkColour;
   }
 */
+(id) tableCellBlueTextColor {
    return darkColour;
}

%end

%hook UIApplication

-(void)setKeyWindow:(UIWindow*)o {
    if (! isCurrentApp(@"com.apple.weather")) {
        if (isCurrentApp(@"com.apple.camera") || isCurrentApp(@"com.apple.facetime") || isCurrentApp(@"com.apple.Passbook") || isCurrentApp(@"com.apple.compass")) {         //[o.tintColor isEqual:[UIColor systemTealColor]] || [o.tintColor isEqual:[UIColor systemYellowColor]])
            [o setTintColor:lightColour];
        }
        else {
            [o setTintColor:darkColour];
        }
    }
    %orig(o);
}

%end

%hook UISwitch

-(void)layoutSubviews {
    %orig;
    [self setOnTintColor:darkColour];
}

-(void) setOnTintColor:(id)col {
    %orig(darkColour);
}

%end

%hook UITextInputTraits

-(void)_setColorsToMatchTintColor:(id)arg1 {
    %orig(darkColour);
}

-(id) insertionPointColor {
    return darkColour;
}

-(id) selectionBarColor {
    return darkColour;
}

-(id) selectionHighlightColor {
    return [darkColour colorWithAlphaComponent:0.2];
}

%end

%end//CHROMA

#pragma mark UIKIT

%group UIKIT

%hook UIStatusBar

-(long long)styleForRequestedStyle:(long long)arg1 {
    if (! statusEnabled && self.tag != 127123998 && ! isCurrentApp(@"com.apple.springboard") && ! isCurrentApp(@"com.apple.mobilenotes") && ! isCurrentApp(@"com.apple.Maps")) {
        if (darknessForUIColor(barBGColour) < 0.5) {
            return UIStatusBarStyleLightContent;
        }
        else {
            return UIStatusBarStyleDefault;
        }
    }
    else {
        return %orig;
    }
}

-(void) setForegroundColor:(id)col {
    if (self.tag != 127123998 && ! isCurrentApp(@"com.apple.springboard") && ! isCurrentApp(@"com.apple.mobilenotes") && ! isCurrentApp(@"com.apple.Maps") && statusEnabled) {
        %orig(barTColour);
    }
    else {
        %orig;
    }
}

-(id) foregroundColor {
    if (self.tag != 127123998 && ! isCurrentApp(@"com.apple.springboard") && ! isCurrentApp(@"com.apple.mobilenotes") && ! isCurrentApp(@"com.apple.Maps") && statusEnabled) {
        return barTColour;
    }
    else {
        return %orig;
    }
}

%end

%hook UINavigationBar

-(void)layoutSubviews {
    %orig;
    if (self.tag != 1238973798 && ! [self isKindOfClass:%c(TFNSupplementaryNavigationBar)]) {
        [self setBarStyle:0];
        [self setTintColor:nil];
        [self setBarTintColor:nil];
        [self setTranslucent:translucencyEnabled];
        [self setTitleTextAttributes:nil];
    }
}

-(void) setBarStyle:(int)s {
    if (blendEnabled || isBlackColour(barBGColour)) {
        %orig(1);
    }
    else {
        %orig(0);
    }
}

-(void) setBarTintColor:(id)c {
    if (blendEnabled || isBlackColour(barBGColour)) {
        %orig(nil);
    }
    else if (! [self isKindOfClass:%c(TFNSupplementaryNavigationBar)]) {
        %orig(barBGColour);
    }
    else {
        %orig;
    }
}

-(void) setTintColor:(id)c {
    if (self.tag != 1238973798) {
        if (isCurrentApp(@"com.apple.mobilenotes")) {
            %orig(darkColour);
        }
        else if (isCurrentApp(@"com.apple.facetime")) {
            %orig(lightColour);
        }
        else {
            %orig(barFGColour);
        }
    }
    else {
        %orig;
    }
}

-(void) setTranslucent:(BOOL)t {
    %orig([self isKindOfClass:objc_getClass("TFNNavigationBar")]?NO:translucencyEnabled);
}

-(void) setTitleTextAttributes:(id)arg1 {
    %orig([NSDictionary dictionaryWithObjectsAndKeys:barTColour, NSForegroundColorAttributeName, nil]);
}

%end

%hook UIToolbar

-(void)layoutSubviews {
    %orig;
    if (! [self isKindOfClass:%c(IMToolbar)] && ! ([self isKindOfClass:%c(BrowserToolbar)] && DEVICE_IS_IPAD)) {
        [self setBarStyle:0];
        [self setTintColor:nil];
        [self setBarTintColor:nil];
        [self setTranslucent:translucencyEnabled];
    }
}

-(void) setBarStyle:(int)s {
    if ((blendEnabled || isBlackColour(barBGColour)) && ! [self isKindOfClass:%c(IMToolbar)]) {
        %orig(1);
    }
    else {
        %orig(0);
    }
}

-(void) setBarTintColor:(id)c {
    if (blendEnabled || isBlackColour(barBGColour)) {
        %orig(nil);
    }
    else if (! [self isKindOfClass:%c(IMToolbar)]) {
        %orig(barBGColour);
    }
    else {
        %orig;
    }
}

-(void) setTintColor:(id)c {
    if (! [self isKindOfClass:%c(IMToolbar)]) {
        if (isCurrentApp(@"com.apple.mobilenotes")) {
            %orig(darkColour);
        }
        else if (isCurrentApp(@"com.apple.facetime")) {
            %orig(lightColour);
        }
        else {
            %orig(barFGColour);
        }
    }
    else {
        %orig;
    }
}

-(void) setTranslucent:(BOOL)t {
    %orig(translucencyEnabled);
}

%end

%hook UIToolbarTextButton

-(id)initWithTitle:(id)arg1 pressedTitle:(id)arg2 withFont:(id)arg3 withBarStyle:(long long)arg4 withStyle:(long long)arg5 withTitleWidth:(float)arg6 possibleTitles:(id)arg7 withToolbarTintColor:(id)arg8 {
    return %orig(arg1, arg2, arg3, arg4, arg5, arg6, arg7, barFGColour);
}

%end

%hook UITabBar

-(void)layoutSubviews {
    %orig;
    [self setBarStyle:0];
    [self setTintColor:nil];
    [self setBarTintColor:nil];
    [self setTranslucent:translucencyEnabled];
}

-(void) setBarStyle:(int)s {
    if (blendEnabled  || isBlackColour(barBGColour)) {
        %orig(1);
    }
    else {
        %orig(0);
    }
}

-(void) setBarTintColor:(id)c {
    if (blendEnabled || isBlackColour(barBGColour)) {
        %orig(nil);
    }
    else {
        %orig(barBGColour);
    }
}

-(void) setTintColor:(id)c {
    if (isCurrentApp(@"com.apple.mobilenotes")) {
        %orig(darkColour);
    }
    else if (isCurrentApp(@"com.apple.facetime")) {
        %orig(lightColour);
    }
    else {
        %orig(barFGColour);
    }
}

-(void) setTranslucent:(BOOL)t {
    %orig(translucencyEnabled);
}

%end

%hook UITabBarButton

-(void)setFrame:(CGRect)frame {
    %orig;
    [self _setUnselectedTintColor:tabBarSecondaryColour];
}

-(void) _setUnselectedTintColor:(id)arg1 forceLabelToConform:(BOOL)arg2 {
    %orig(tabBarSecondaryColour, arg2);
}

-(void) _setUnselectedTintColor:(id)arg1 {
    %orig(tabBarSecondaryColour);
}

-(id) initWithImage:(id)image selectedImage:(id)image2 label:(id)label withInsets:(UIEdgeInsets)insets {
    UIImage* i = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImage* i2 = [image2 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    return %orig(i, i2, label, insets);
}

%end

%hook UISearchBar

-(void)layoutSubviews {
    %orig;
    if (! isCurrentApp(@"com.apple.mobileme.fmip1") && ! isCurrentApp(@"com.apple.mobileme.fmf1")) {
        if (([self.superview isKindOfClass:%c(UINavigationBar)] || [self.superview isKindOfClass:%c(UIToolbar)] || [self.superview isKindOfClass:%c(ASPurchasedHeaderView)])  && ! isCurrentApp(@"com.apple.iBooks")) {
            UISearchBarTextField* tf = [self searchField];
            tf.textColor = barTColour;
            self.tintColor = barFGColour;
        }
        else if ([self.superview.superview isKindOfClass:%c(UISearchDisplayControllerContainerView)] && isCurrentApp(@"com.apple.Music")) {
            UISearchBarTextField* tf = [self searchField];
            MSHookIvar<UIView*>(tf, "_effectBackgroundBottom").hidden = YES;
            [self setDrawsBackground:NO];
            tf.tintColor = darkColour;
            self.tintColor = darkColour;
        }
    }
}

%end

%hook UISearchBarTextField

-(void)layoutSubviews {
    %orig;
    if (([self.superview isKindOfClass:%c(UINavigationBar)] || [self.superview isKindOfClass:%c(UIToolbar)])) {
        self.textColor = barTColour;
        UIColor* col = [(darknessForUIColor(barBGColour) < 0.3 ? [UIColor whiteColor]:[UIColor blackColor]) colorWithAlphaComponent:0.1];
        [self setBackgroundColor:col];
        MSHookIvar<UIButton*>(self, "_clearButton").tintColor = barFGColour;
        for (id s in MSHookIvar<UIButton*>(self, "_clearButton").subviews) {
            if ([s isKindOfClass:%c(UILabel)]) {
                UILabel* l = s;
                l.textColor = [barTColour colorWithAlphaComponent:0.5];
            }
        }
    }
}

%end

%hook UIPageControl

- (void)setCurrentPageIndicatorTintColor:(id)arg1 {
    if (! isCurrentApp(@"com.apple.springboard")) {
        %orig(darkColour);
    }
    else {
        %orig;
    }
}

%end

%hook UISegmentedControl

- (void)layoutSubviews {
    %orig;
    self.tintColor = [self correctTintColorForThis];
    [self setTitleTextAttributes:@{ NSForegroundColorAttributeName:[self correctTintColorForThis] } forState:UIControlStateNormal];
}

-(void) didMoveToSuperview {
    %orig;
    self.tintColor = [self correctTintColorForThis];
    [self setTitleTextAttributes:@{ NSForegroundColorAttributeName:[self correctTintColorForThis] } forState:UIControlStateNormal];
}

%new

-(UIColor*)correctTintColorForThis {
    if (! isCurrentApp(@"com.apple.mobileme.fmip1") && ! isCurrentApp(@"com.apple.springboard") ) {
        BOOL shouldBeDark = [self.superview.superview.superview isKindOfClass:%c(UISearchBar)] || [self isKindOfClass:%c(SKUIProductPageSegmentedControl)] || [self.superview.superview isKindOfClass:%c(VideosDetailHeaderView)] || [self isKindOfClass:%c(BKSegmentedControl)] || [self.superview.superview isKindOfClass:%c(IMToolbar)] || [self.superview.superview isKindOfClass:%c(SKUISegmentedTableHeaderView)] || [self.superview isKindOfClass:%c(SKUISegmentedTableHeaderView)] || [self.superview isKindOfClass:%c(UITableViewCellContentView)] || [self.superview.superview isKindOfClass:%c(SUSegmentedControlBar)] || [self.superview isKindOfClass:%c(GKSegmentedSectionHeaderView)];
        if (shouldBeDark) {
            return darkColour;
        }
        else if (isCurrentApp(@"com.apple.facetime") && ! [[preferences objectForKey:@"appTint"] boolValue]) {
            return lightColour;
        }
        else {
            return barFGColour;
        }
    }
    else {
        return self.tintColor;
    }
}

%end

%hook UIActionSheet

- (void)layout {
    %orig;
    if (asEnabled && UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        UIView* bg;
        if (IS_IOS_7_1) {
            bg = MSHookIvar<id>(self, "_backgroundView");
        }
        else {
            bg = MSHookIvar<id>(self, "_backdropView");
        }

        if (! bg) {
            return;
        }

        if ([bg isKindOfClass:%c(_UIBackdropView)]) {
            _UIBackdropView* v = (_UIBackdropView*)bg;
            _UIBackdropViewSettings* s;
            if (blendEnabled || isBlackColour(barBGColour)) {
                s = [_UIBackdropViewSettings settingsForStyle:1];
                s.filterMaskImage = v.inputSettings.filterMaskImage;
                s.grayscaleTintMaskImage = v.inputSettings.grayscaleTintMaskImage;
                s.colorTintMaskImage = v.inputSettings.colorTintMaskImage;
            }
            else {
                s = v.inputSettings;
                [s setColorTint:[barBGColour colorWithAlphaComponent:1]];
                [s setColorTintAlpha:0.8];
            }
            [v transitionToSettings:s];
        }
        else if ([bg isKindOfClass:%c(UIImageView)]) {
            UIImageView* v = (UIImageView*)bg;
            v.tintColor = barBGColour;
        }

        MSHookIvar<UILabel*>(self, "_titleLabel").textColor = barTColour;
        MSHookIvar<UILabel*>(self, "_subtitleLabel").textColor = barTColour;
        MSHookIvar<UILabel*>(self, "_taglineTextLabel").textColor = barTColour;
        MSHookIvar<UILabel*>(self, "_bodyTextLabel").textColor = barTColour;

        if (blendEnabled) {
            [MSHookIvar<UILabel*>(self, "_titleLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
            [MSHookIvar<UILabel*>(self, "_subtitleLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
            [MSHookIvar<UILabel*>(self, "_taglineTextLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
            [MSHookIvar<UILabel*>(self, "_bodyTextLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        }
    }
}

-(id) tableView:(id)arg1 cellForRowAtIndexPath:(id)arg2 {
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        UITableViewCell* o = %orig;
        for (id v in MSHookIvar<UIView*>(o, "_wrapperView").subviews) {
            if ([v isKindOfClass:%c(UILabel)]) {
                UILabel* l = v;
                if (asEnabled && ! [l.textColor isEqual:asRedColor]) {
                    l.textColor = barFGColour;
                    if (blendEnabled) {
                        [l _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
                    }
                }
                else if (! [l.textColor isEqual:asRedColor]) {
                    l.textColor = darkColour;
                }
            }
        }
        return o;
    }
    else {
        return %orig;
    }
}

%end

%hook UIAlertButton

-(void)layoutSubviews {
    %orig;
    if (blendEnabled && asEnabled) {
        [((UIButton*)self).titleLabel _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

-(void) setTintColor:(id)c {
    if (asEnabled && ! [c isEqual:asRedColor]) {
        %orig(barFGColour);
    }
    else if (! [c isEqual:asRedColor]) {
        %orig(darkColour);
    }
    else {
        %orig;
    }
}

-(void) setTitleColor:(UIColor*)color forState:(UIControlState)state {
    if (asEnabled && ! [color isEqual:asRedColor]) {
        %orig(barFGColour, state);
    }
    else if (! [color isEqual:asRedColor]) {
        %orig(darkColour, state);
    }
    else {
        %orig;
    }
}

%end

%end //UIKIT

#pragma mark KEYBOARD

%group KEYBOARD

%hook UIKBInputBackdropView

-(void)layoutSubviews {
    %orig;
    if (kEnabled) {
        [self.inputBackdropFullView updateColours];
        [self.inputBackdropLeftView updateColours];
        [self.inputBackdropRightView updateColours];
    }
}

%end

%hook UIKBBackdropView

-(void)applySettings:(id)arg1 {
    if (kEnabled && ! isBlackColour(keyboardColour)) {
        if (! [self.superview isKindOfClass:%c(UIKBInputBackdropView)]) {
            _UIBackdropViewSettings* s = arg1;
            [s setColorTint:keyboardColour];
            %orig(s);
        }
        else {
            _UIBackdropViewSettings* s = [_UIBackdropViewSettings settingsForStyle:2040];
            [s setUsesColorTintView:YES];
            [s setColorTint:keyboardColour];
            [s setColorTintAlpha:0.9];
            %orig(s);
            self.backgroundColor = [UIColor colorWithWhite:0.97 alpha:0.47];
        }
    }
    else {
        %orig;
    }
}

%new

-(void)updateColours {
    [self applySettings:self.inputSettings];
}

%end

%hook UIKBRenderConfig

-(long long)backdropStyle {
    if (kEnabled && ! isBlackColour(keyboardColour)) {
        return 2040;
    }
    else {
        return %orig;
    }
}

-(BOOL) whiteText {
    if (kEnabled) {
        if (darknessForUIColor(keyboardColour) < 0.6) {
            return YES;
        }
        else {
            return NO;
        }
    }
    else {
        return %orig;
    }
}

-(BOOL) lightKeyboard {
    if (kEnabled) {
        //if(darknessForUIColor(keyboardColour) < 0.7)
        return NO;
        //  else
        //  return YES;
    }
    else {
        return %orig;
    }
}

%end

%hook UIWebFormAccessory

-(void)layoutSubviews {
    if (kEnabled) {
        UIColor* col = [UIColor blackColor];
        if (darknessForUIColor(keyboardColour) < 0.6) {
            col = [UIColor whiteColor];
        }

        [MSHookIvar<UIBarButtonItem*>(self, "_doneButton") setTitleTextAttributes:@{ NSForegroundColorAttributeName:col } forState:UIControlStateNormal];
        [MSHookIvar<UIBarButtonItem*>(self, "_autofill") setTitleTextAttributes:@{ NSForegroundColorAttributeName:col } forState:UIControlStateNormal];
        [MSHookIvar<UIBarButtonItem*>(self, "_clearButton") setTitleTextAttributes:@{ NSForegroundColorAttributeName:col } forState:UIControlStateNormal];
        [MSHookIvar<UIBarButtonItem*>(self, "_nextItem") setTintColor:col];
        [MSHookIvar<UIBarButtonItem*>(self, "_previousItem") setTintColor:col];

        MSHookIvar<UIView*>(MSHookIvar<UIView*>(self, "_leftToolbar"), "_backgroundView").hidden = YES;
        MSHookIvar<UIView*>(MSHookIvar<UIView*>(self, "_rightToolbar"), "_backgroundView").hidden = YES;
    }
}

%end

%hook DevicePINKeypad

-(void)layoutSubviews {
    %orig;
    if (kEnabled) {
        ((UIView*)self).backgroundColor = keyboardColour;
    }
}

%end

%end //KEYBOARD

#pragma mark GAMECENTER

%group GAMECENTER

%hook GKColorPalette
- (id)emphasizedTextColor {
    return darkColour;
}
-(id) emphasizedTextOnDarkBackgroundColor {
    return darkColour;
}

-(id) systemInteractionColor {
    return darkColour;
}

%end

%hook GKUITheme
- (id)tabbarIconChallengesSelected:(BOOL)arg1 {
    UIImage* img = %orig;
    img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    return img;
}
-(id) tabbarIconFriendsSelected:(BOOL)arg1 {
    UIImage* img = %orig;
    img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    return img;
}

-(id) tabbarIconGamesSelected:(BOOL)arg1 {
    UIImage* img = %orig;
    img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    return img;
}

-(id) tabbarIconMeSelected:(BOOL)arg1 {
    UIImage* img = %orig;
    img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    return img;
}

-(id) tabbarIconTurnsSelected:(BOOL)arg1 {
    UIImage* img = %orig;
    img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    return img;
}

%end

%end

#pragma mark NOTES

%group NOTES

%hook NoteCell

-(void)layoutSubviews {
    %orig;
    self.selectedBackgroundView.backgroundColor = [darkColour colorWithAlphaComponent:0.3];
}

%end

%end

#pragma mark TWITTER

%group TWITTER

%hook TFNBarButtonItemButton

-(void)layoutSubviews {
    %orig;
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

-(void) setTintColor:(id)c {
    %orig(barFGColour);
}

%end

%hook T1SwipeTitleView

-(void)_layoutLabels {
    %orig;
    MSHookIvar<UILabel*>(self, "_currentLabel").textColor = barTColour;
    MSHookIvar<UILabel*>(self, "_onDeckLabel").textColor = barTColour;
    MSHookIvar<UIImageView*>(self, "_logoView").tintColor = barTColour;
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

%end

%hook T1TabView

-(void)layoutSubviews {
    %orig;
    if (blendEnabled) {
        [MSHookIvar<UIView*>(self, "_imageView") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        [MSHookIvar<UIView*>(self, "_titleLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

-(void) setSelectedTitleTintColor:(id)color {
    %orig(barFGColour);
}

-(void) setSelectedTintColor:(id)color {
    %orig(barFGColour);
}

-(void) setTintColor:(id)color {
    %orig(tabBarSecondaryColour);
}

-(void) _updateImageView {
    %orig;
    self.imageView.image = [self.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.imageView.tintColor = (self.isSelected ? barFGColour:tabBarSecondaryColour);
}

-(void) _updateTitleLabel {
    %orig;
    self.titleLabel.textColor = (self.isSelected ? barFGColour:tabBarSecondaryColour);
}

%end

%hook TFNTitleView
-(void)layoutSubviews {
    %orig;
    MSHookIvar<UILabel*>(self, "_titleLabel").textColor = barTColour;
    MSHookIvar<UILabel*>(self, "_subtitleLabel").textColor = [barTColour colorWithAlphaComponent:0.5];
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}
%end

%hook TFNNavigationControllerBackButton
-(void)layoutSubviews {
    %orig;
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}
-(void) setImage:(UIImage*)arg1 forState:(unsigned int)arg2 {
    UIImage* i = [arg1 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    %orig(i, arg2);
}
%end

%hook T1LegacyDirectMessageConversationTitleView
-(void)layoutSubviews {
    %orig;
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
    MSHookIvar<UILabel*>(self, "_titleLabel").textColor = barTColour;
    MSHookIvar<UILabel*>(self, "_subtitleLabel").textColor = [barTColour colorWithAlphaComponent:0.5];
    MSHookIvar<UILabel*>(self, "_animatedLabel").textColor = [barTColour colorWithAlphaComponent:0.5];
}
%end

%hook UIColor
+ (id)twitterColorTwitterBlue {
    return darkColour;
}
%end

%hook T1ComposeEntrypointBar
-(void)setBackgroundColor:(id)col {
    %orig(barBGColour);
}
-(void)layoutSubviews {
    %orig;
    MSHookIvar<UIView*>(self,"_writeSubdivider").backgroundColor = barTColour;
    MSHookIvar<UIView*>(self,"_cameraSubdivider").backgroundColor = barTColour;
    if (blendEnabled) {
        [MSHookIvar<UIView*>(self,"_writeSubdivider") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        [MSHookIvar<UIView*>(self,"_cameraSubdivider") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}
%end

%hook TFNButton

-(void)layoutSubviews {
    %orig;
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
    MSHookIvar<UILabel*>(self,"_localTitleLabel").textColor = barFGColour;
    UIImageView * iv = MSHookIvar<UIImageView*>(self,"_localImageView");
    iv.tintColor = barFGColour;
    iv.image = [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

%end

%hook TFNToolbar
-(void)layoutSubviews {
    %orig;
    [(UIView*)self setBackgroundColor:barBGColour];
}
%end

%hook TFNNavigationBar
-(void)layoutSubviews {
    %orig;
    if(blendEnabled) {
        ((UINavigationBar*)self)._backgroundView.alpha = 0.8;
    }
}
%end

%end

#pragma mark FACEBOOK

%group FACEBOOK

%hook FBPublisherButton

-(void)layoutSubviews {
    %orig;
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

-(void) setTintColor:(id)c {
    %orig(barFGColour);
}

%end

%hook FBTabBarItemView

- (void)layoutSubviews {
    %orig;
    UILabel* l = MSHookIvar<UILabel*>(self, "_titleLabel");

    UIImageView* iv = MSHookIvar<UIImageView*>(self, "_imageView");
    iv.image = [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    if (self.isSelected) {
        l.textColor = barFGColour;
        iv.tintColor = barFGColour;
    }
    else {
        l.textColor = tabBarSecondaryColour;
        iv.tintColor = tabBarSecondaryColour;
    }

    if (blendEnabled) {
        [iv _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        [l _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

%end

%hook FBBarButtonItemContainerView

-(void)layoutSubviews {
    %orig;
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

%end

%hook FBNavigationBarSearchTextField

-(void)layoutSubviews {
    %orig;
    UIImageView* iv = MSHookIvar<UIImageView*>(self, "_backgroundView");
    iv.image = [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIColor* col;
    if (darknessForUIColor(barBGColour) < 0.1) {
        col = [lightenedColourFromColour(barBGColour) colorWithAlphaComponent:0.5];
    }
    else {
        col = [darkenedColourFromColour(barBGColour) colorWithAlphaComponent:0.5];
    }
    iv.tintColor = col;
}

%end

%hook FBNavigationBarSearchTextField_DEPRECATED

-(void)layoutSubviews {
    %orig;
    UIImageView* iv = MSHookIvar<UIImageView*>(self, "_backgroundView");
    iv.image = [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIColor* col;
    if (darknessForUIColor(barBGColour) < 0.1) {
        col = [lightenedColourFromColour(barBGColour) colorWithAlphaComponent:0.5];
    }
    else {
        col = [darkenedColourFromColour(barBGColour) colorWithAlphaComponent:0.5];
    }
    iv.tintColor = col;
}

%end

%hook FBJewelButton

-(void)layoutSubviews {
    %orig;
    [self setImage:[[self imageForState:UIControlStateNormal]imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

-(void) setTintColor:(id)col {
    %orig(barFGColour);
}

%end

%hook FBBouncyPressButton

-(void)layoutSubviews {
    %orig;
    [self setImage:[[self imageForState:UIControlStateNormal]imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

%end

%hook FBNavigationBarProfileView

-(void)layoutSubviews {
    %orig;
    MSHookIvar<UILabel*>(self, "_textLabel").textColor = barTColour;
    if (blendEnabled) {
        [MSHookIvar<UILabel*>(self, "_textLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

%end

%hook FBTabBar

-(void)setBackgroundColor:(id)c {
    %orig(barBGColour);
}

%end

//TODO NAV BAR ON IPAD

%end

#pragma mark FBMESSENGER

%group FBMESSENGER

%hook MNMessagesTitleView

- (void)updateLabels {
    %orig;
    MSHookIvar<UILabel*>(self, "_titleLabel").textColor = barTColour;
    MSHookIvar<UILabel*>(self, "_subtitleLabel").textColor = [barTColour colorWithAlphaComponent:0.75];
    MSHookIvar<UILabel*>(self, "_previousSubtitleLabel").textColor = [barTColour colorWithAlphaComponent:0.75];
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

-(void) _updateLabels {
    %orig;
    MSHookIvar<UILabel*>(self, "_titleLabel").textColor = barTColour;
    MSHookIvar<UILabel*>(self, "_subtitleLabel").textColor = [barTColour colorWithAlphaComponent:0.75];
    MSHookIvar<UILabel*>(self, "_previousSubtitleLabel").textColor = [barTColour colorWithAlphaComponent:0.75];
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

%end

%hook FBActionButton

- (void)layoutSubviews {
    %orig;
    if ([self.superview isKindOfClass:%c(UIToolbar)]) {
        [self setImage:[[self imageForState:UIControlStateNormal]imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        [self setImage:[[self imageForState:UIControlStateDisabled]imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateDisabled];
        if (! self.enabled) {
            self.alpha = 0.3;
        }
        else {
            self.alpha = 1;
        }
        if (blendEnabled) {
            [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        }
    }
}

-(void) setTitleColor:(UIColor*)color forState:(UIControlState)state {
    if ([color isEqual:UIColorFromHexString(@"#FF0084FF")] || [color isEqual:[UIColor colorWithWhite:2.0/3.0 alpha:1]]) {
        %orig(barFGColour, state);
    }
    else if ([color isEqual:UIColorFromHexString(@"#FF043673")]) {
        %orig(brightnessAlteredColour(barFGColour, 0.6), state);
    }
    else {
        %orig;
    }
}

%end

%end

#pragma mark PHONE

%group PHONE

%hook PHHandsetDialerView
-(id)dialerColor {
    if (blendEnabled || isBlackColour(barBGColour)) {
        return [UIColor colorWithWhite:0 alpha:0.5];
    }
    else {
        return barBGColour;
    }
}
%end

%hook PHEmergencyHandsetDialerView
-(id)dialerColor {
    if (blendEnabled || isBlackColour(barBGColour)) {
        return [UIColor colorWithWhite:0 alpha:0.5];
    }
    else {
        return barBGColour;
    }
}
%end

%hook PHHandsetDialerLCDView
-(id)lcdColor {
    if (blendEnabled || isBlackColour(barBGColour)) {
        return [UIColor colorWithWhite:0 alpha:0.5];
    }
    else {
        return barBGColour;
    }
}

-(void) layoutSubviews {
    %orig;

    self.numberLabel.textColor = barTColour;
    self.deleteButton.tintColor = barFGColour;
    if ([self respondsToSelector:@selector(addContactButton)]) {
        self.addContactButton.tintColor = barFGColour;
    }

    if (blendEnabled) {
        [self.numberLabel _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        [self.deleteButton _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        if ([self respondsToSelector:@selector(addContactButton)]) {
            [self.addContactButton _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        }
    }
}

%end

%hook PHHandsetDialerNameLabelView

-(void)layoutSubviews {
    %orig;
    MSHookIvar<UILabel*>(self, "_nameAndLabelLabel").textColor = barTColour;
    if (blendEnabled) {
        [MSHookIvar<UILabel*>(self, "_nameAndLabelLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

%end

%hook PHEmergencyHandsetDialerLCDView
-(id)lcdColor {
    if (blendEnabled || isBlackColour(barBGColour)) {
        return [UIColor colorWithWhite:0 alpha:0.5];
    }
    else {
        return barBGColour;
    }
}
%end

%hook TPNumberPadLightStyleButton

+ (id)imageForCharacter:(int)arg1 highlighted:(BOOL)arg2 whiteVersion:(BOOL)arg3 {
    BOOL isDark = darknessForUIColor(barBGColour) < 0.5;
    if (isDark || blendEnabled || isBlackColour(barBGColour)) {
        return %orig(arg1, arg2, YES);
    }
    else {
        return %orig(arg1, arg2, NO);
    }
}

%end

%end

#pragma mark MAIL

%group MAIL

%hook MailStatusLabelView

- (void)layoutSubviews {
    %orig;
    UILabel* p = MSHookIvar<UILabel*>(self, "_primaryLabel");
    UILabel* s = MSHookIvar<UILabel*>(self, "_secondaryLabel");
    p.textColor = barTColour;
    s.textColor = [barTColour colorWithAlphaComponent:0.5];
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

-(void) update {
    %orig;
    UILabel* p = MSHookIvar<UILabel*>(self, "_primaryLabel");
    UILabel* s = MSHookIvar<UILabel*>(self, "_secondaryLabel");
    p.textColor = barTColour;
    s.textColor = [barTColour colorWithAlphaComponent:0.5];
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

%end

%hook MailStatusUpdateView

- (void)update {
    %orig;
    UILabel* p = MSHookIvar<UILabel*>(self, "_primaryLabel");
    UILabel* s = MSHookIvar<UILabel*>(self, "_secondaryLabel");
    p.textColor = barTColour;
    s.textColor = [barTColour colorWithAlphaComponent:0.5];
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

%end

%hook TransferMailboxPickerPalette

- (void)layoutSubviews {
    %orig;
    UILabel* p = MSHookIvar<UILabel*>(self, "_sendersLabel");
    UILabel* s = MSHookIvar<UILabel*>(self, "_subjectLabel");
    p.textColor = barTColour;
    s.textColor = barTColour;
    if (blendEnabled) {
        [(UIView*)p _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        [(UIView*)s _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

%end

%end

#pragma mark MESSAGES

%group MESSAGES

//TODO improve in general

%hook CKUIBehavior

-(id)gray_sendButtonColor {
    return barFGColour;
}

%end

%hook CKMessageEntryView

%new
-(BOOL)isTinctActive {
    return enabled;
}

-(id) backdropView {
    _UIBackdropView* vi = %orig;
    if (blendEnabled || isBlackColour(barBGColour)) {
        [vi transitionToStyle:1];
    }
    else {
        [vi transitionToStyle:0];
        [vi transitionToColor:[barBGColour colorWithAlphaComponent:0.9]];
    }
    return vi;
}

-(id) coverView {
    _UITextFieldRoundedRectBackgroundViewNeue* v = %orig;
    v.alpha = 0.1;
    if (blendEnabled || isBlackColour(barBGColour)) {
        v.fillColor = barTColour;
        [(UIView*)v _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
    else {
        if (darknessForUIColor(barBGColour) < 0.3) {
            v.fillColor = [UIColor whiteColor];
        }
        else {
            v.fillColor = [UIColor blackColor];
        }
    }
    return v;
}

-(id) photoButton {
    UIButton* o = %orig;
    if (blendEnabled) {
        [(UIView*)o _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
    o.tintColor = barFGColour;
    return o;
}

%end

%hook CKMessageEntryTextView

-(void)updateTextView {
    %orig;
    self.placeholderLabel.textColor = barFGColour;
    self.textColor = barTColour;
}

%end

%hook CKMultipleRecipientTableViewCell

- (void)setNameLabel:(id)arg1 {
    UILabel* l = arg1;
    l.textColor = barTColour;
    %orig(l);
}

%end

%hook MFHeaderLabelView

-(void)setTextColor:(id)col {
    %orig(barFGColour);
}

%end

%hook _MFMailRecipientTextField

-(void)setTextColor:(id)col {
    if (! [((UIView*)self).superview isKindOfClass:%c(CKComposeRecipientView)]) {
        %orig(barTColour);
    }
    else {
        %orig;
    }
}

%end

%end

#pragma mark AUXO2

%group Auxo2

%hook UminoControlCenterTopView
-(void)setHidden:(BOOL)h {
    %orig;
    if (ccEnabled) {
        _UIBackdropView* backgroundView = MSHookIvar<_UIBackdropView*>(self, "_backgroundView");
        if (! backgroundView || ! [backgroundView isKindOfClass:%c(_UIBackdropView)]) {
            return;
        }

        if (! [backgroundView.inputSettings.colorTint isEqual:ccColour]) {
            if (ccColour) {
                _UIBackdropViewSettings* s;
                if (isBlackColour(ccColour)) {
                    s = [_UIBackdropViewSettings settingsForStyle:1];
                }
                else {
                    s = [_UIBackdropViewSettings settingsForStyle:0];
                    [s setUsesColorTintView:YES];
                    [s setColorTint:ccColour];
                    [s setColorTintAlpha:0.55];
                }
                [backgroundView transitionToSettings:s];
            }
            else {
                _UIBackdropViewSettings* s = [_UIBackdropViewSettings settingsForStyle:2020];
                [backgroundView transitionToSettings:s];
            }
        }
    }
}
%end

%hook UminoControlCenterBottomView
-(void)setHidden:(BOOL)h {
    %orig;
    if (ccEnabled) {
        _UIBackdropView* backgroundView = MSHookIvar<_UIBackdropView*>(self, "_backgroundView");
        if (! backgroundView || ! [backgroundView isKindOfClass:%c(_UIBackdropView)]) {
            return;
        }

        if (! [backgroundView.inputSettings.colorTint isEqual:ccColour]) {
            if (ccColour) {
                _UIBackdropViewSettings* s;
                if (isBlackColour(ccColour)) {
                    s = [_UIBackdropViewSettings settingsForStyle:1];
                }
                else {
                    s = [_UIBackdropViewSettings settingsForStyle:0];
                    [s setUsesColorTintView:YES];
                    [s setColorTint:ccColour];
                    [s setColorTintAlpha:0.55];
                }
                [backgroundView transitionToSettings:s];
            }
            else {
                _UIBackdropViewSettings* s = [_UIBackdropViewSettings settingsForStyle:2020];
                [backgroundView transitionToSettings:s];
            }
        }
    }
}
%end

%hook UminoControlCenterOriginalView
-(void)setHidden:(BOOL)h {
    %orig;
    if (ccEnabled) {
        _UIBackdropView* backgroundView = MSHookIvar<_UIBackdropView*>(self, "_backgroundView");
        if (! backgroundView || ! [backgroundView isKindOfClass:%c(_UIBackdropView)]) {
            return;
        }

        if (! [backgroundView.inputSettings.colorTint isEqual:ccColour]) {
            if (ccColour) {
                _UIBackdropViewSettings* s;
                if (isBlackColour(ccColour)) {
                    s = [_UIBackdropViewSettings settingsForStyle:1];
                }
                else {
                    s = [_UIBackdropViewSettings settingsForStyle:0];
                    [s setUsesColorTintView:YES];
                    [s setColorTint:ccColour];
                    [s setColorTintAlpha:0.55];
                }
                [backgroundView transitionToSettings:s];
            }
            else {
                _UIBackdropViewSettings* s = [_UIBackdropViewSettings settingsForStyle:2020];
                [backgroundView transitionToSettings:s];
            }
        }
    }
}
%end

%end

#pragma mark SENG

%group SENG

%hook SengContainerView
-(void)viewWillAppear {
    if (ccEnabled) {
        _UIBackdropView* bg = MSHookIvar<_UIBackdropView*>(self, "_backgroundView");
        if (ccColour) {
            _UIBackdropViewSettings* s;
            if (isBlackColour(ccColour)) {
                s = [_UIBackdropViewSettings settingsForStyle:1];
            }
            else {
                s = [_UIBackdropViewSettings settingsForStyle:0];
                [s setUsesColorTintView:YES];
                [s setColorTint:ccColour];
                [s setColorTintAlpha:0.55];
            }
            [bg transitionToSettings:s];
        }
        else {
            if (bg.style != 2060) {
                _UIBackdropViewSettings* s = [_UIBackdropViewSettings settingsForStyle:2060];
                [bg transitionToSettings:s];
            }
        }
    }
    %orig;
}
%end

%end

#pragma mark SPRINGBOARD

%group SPRINGBOARD

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    %init(Auxo2);
    %init(SENG);
}
%end

%hook SBControlCenterContentContainerView
- (void)layoutSubviews {
    %orig;
    if (ccEnabled) {
        if (! self.backdropView.inputSettings.colorTint || ! [self.backdropView.inputSettings.colorTint isEqual:ccColour]) {
            if (ccColour) {
                _UIBackdropViewSettings* s;
                if (isBlackColour(ccColour)) {
                    s = [_UIBackdropViewSettings settingsForStyle:1];
                }
                else {
                    s = [_UIBackdropViewSettings settingsForStyle:0];
                    [s setUsesColorTintView:YES];
                    [s setColorTint:ccColour];
                    [s setColorTintAlpha:0.55];
                }
                [self.backdropView transitionToSettings:s];
            }
            else {
                if (self.backdropView.style != 2060) {
                    _UIBackdropViewSettings* s = [_UIBackdropViewSettings settingsForStyle:2060];
                    [self.backdropView transitionToSettings:s];
                }
            }
        }
    }
}
%end

%hook SBNotificationCenterViewController

-(void)hostWillPresent {
    %orig;
    [self fixBackdropView];
}

%new
-(void)fixBackdropView {
    if (ncEnabled) {
        if (! self.backdropView.inputSettings.colorTint || ! [self.backdropView.inputSettings.colorTint isEqual:ncColour]) {
            if (ncColour) {
                _UIBackdropViewSettings* s;
                if (isBlackColour(ncColour)) {
                    s = [_UIBackdropViewSettings settingsForStyle:1];
                }
                else {
                    s = [_UIBackdropViewSettings settingsForStyle:0];
                    [s setUsesColorTintView:YES];
                    [s setColorTint:ncColour];
                    [s setColorTintAlpha:0.55];
                }
                [self.backdropView transitionToSettings:s];
            }
            else {
                _UIBackdropViewSettings* s = [_UIBackdropViewSettings settingsForStyle:2030];
                [self.backdropView transitionToSettings:s];
            }
        }
    }
}
%end

%hook SBNotificationsSectionHeaderView

- (void)layoutSubviews {
    %orig;
    if (ncEnabled && ncColour) {
        _UIBackdropViewSettings* s;
        if (isBlackColour(ncColour)) {
            s = [_UIBackdropViewSettings settingsForStyle:1];
        }
        else {
            s = [_UIBackdropViewSettings settingsForStyle:0];
            [s setUsesColorTintView:YES];
            [s setColorTint:ncColour];
            [s setColorTintAlpha:0.55];
        }
        _UIBackdropView* v = MSHookIvar<_UIBackdropView*>(self, "_backdrop");
        [v transitionToSettings:s];
    }
}

-(void) setFloating:(BOOL)arg1 {
    if (ncEnabled) {
        %orig(YES);
    }
    else {
        %orig;
    }
}

%end

%hook SBBannerContextView
- (void)layoutSubviews {
    %orig;
    if (ncEnabled && ncColour) {
        _UIBackdropViewSettings* s;
        if (isBlackColour(ncColour)) {
            s = [_UIBackdropViewSettings settingsForStyle:1];
        }
        else {
            s = [_UIBackdropViewSettings settingsForStyle:0];
            [s setUsesColorTintView:YES];
            [s setColorTint:ncColour];
            [s setColorTintAlpha:0.55];
        }
        [self.backdrop transitionToSettings:s];
    }
}
%end

%hook SBHUDView
- (void)layoutSubviews {
    %orig;
    if (hudEnabled) {
        _UIBackdropView* backdropView = MSHookIvar<_UIBackdropView*>(self, "_backdropView");
        if (hudColour) {
            if (! backdropView.inputSettings.colorTint || ! [backdropView.inputSettings.colorTint isEqual:hudColour]) {
                _UIBackdropViewSettings* s;
                if (isBlackColour(hudColour)) {
                    s = [_UIBackdropViewSettings settingsForStyle:1];
                }
                else {
                    s = [_UIBackdropViewSettings settingsForStyle:0];
                    [s setUsesColorTintView:YES];
                    [s setColorTint:hudColour];
                    [s setColorTintAlpha:0.55];
                }
                [backdropView transitionToSettings:s];
            }
        }
        else {
            _UIBackdropViewSettings* s = [_UIBackdropViewSettings settingsForStyle:2060];
            [backdropView transitionToSettings:s];
        }
    }
}
%end

%hook SBSearchViewController

-(void)loadView {
    %orig;
    if (spotEnabled) {
        for(id a in MSHookIvar<UINavigationController*>(self,"_navigationController").navigationBar.subviews) {
            if([a isKindOfClass:%c(SBWallpaperEffectView)]) {
                SBWallpaperEffectView * v = (SBWallpaperEffectView*)a;
                if (v != nil) {
                    if (MSHookIvar<UIView*>(v, "_colorTintView") == nil) {
                        UIView* colorTintView = [[UIView alloc] initWithFrame:v.frame];
                        colorTintView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                        colorTintView.backgroundColor = [barBGColour colorWithAlphaComponent:(translucencyEnabled?0.6:1.0)];
                        [v addSubview:colorTintView];
                        MSHookIvar<UIView*>(v, "_colorTintView") = colorTintView;
                    }
                }
            }
        }
    }
}

%end

%hook SBSearchHeader

-(void) layoutSubviews {
    %orig;
    if (spotEnabled) {
        if(!IS_IOS_8) {
            SBWallpaperEffectView * v = MSHookIvar<SBWallpaperEffectView*>(self, "_blurView");
            if (v != nil) {
                if (MSHookIvar<UIView*>(v, "_colorTintView") == nil) {
                    UIView* colorTintView = [[UIView alloc] initWithFrame:v.frame];
                    colorTintView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                    colorTintView.backgroundColor = [barBGColour colorWithAlphaComponent:(translucencyEnabled?0.6:1.0)];
                    [v addSubview:colorTintView];
                    MSHookIvar<UIView*>(v, "_colorTintView") = colorTintView;
                }
            }
        }
        if (self.searchField != nil) {
            self.searchField.tintColor = barFGColour;
            self.searchField.textColor = barTColour;
        }
        if(MSHookIvar<UIButton*>(self, "_cancelButton") != nil) {
            MSHookIvar<UIButton*>(self, "_cancelButton").tintColor = barFGColour;
        }
    }
}

%end

%end

#pragma mark STOREKIT

%group STOREKIT

%hook SUApplication

-(id)interactionTintColor {
    return darkColour;
}

%end

%hook SUNavigationBarBackgroundView

-(void)layoutSubviews {
    %orig;
    if (blendEnabled || isBlackColour(barBGColour)) {
        [MSHookIvar<_UIBackdropView*>(self, "_backdropView") transitionToStyle:1];
    }
    else if (! [MSHookIvar<_UIBackdropView*>(self, "_backdropView").inputSettings.colorTint isEqual:barBGColour]) {
        if (supportsBlur(MSHookIvar<_UIBackdropView*>(self, "_backdropView"))) {
            _UIBackdropViewSettings* s = [_UIBackdropViewSettings settingsForStyle:0];
            [s setColorTint:barBGColour];
            [s setColorTintAlpha:0.9];
            [MSHookIvar<_UIBackdropView*>(self, "_backdropView") transitionToSettings:s];
        }
        else {
            [MSHookIvar<_UIBackdropView*>(self, "_backdropView") transitionToColor:barBGColour];
        }
    }
}

%end

%hook SKUIStackedBar

-(void)layoutSubviews {
    %orig;
    if (blendEnabled || isBlackColour(barBGColour)) {
        [MSHookIvar<_UIBackdropView*>(self, "_backdropView") transitionToStyle:1];
    }
    else if (! [MSHookIvar<_UIBackdropView*>(self, "_backdropView").inputSettings.colorTint isEqual:barBGColour]) {
        if (supportsBlur(MSHookIvar<_UIBackdropView*>(self, "_backdropView"))) {
            _UIBackdropViewSettings* s = [_UIBackdropViewSettings settingsForStyle:0];
            [s setColorTint:barBGColour];
            [s setColorTintAlpha:0.9];
            [MSHookIvar<_UIBackdropView*>(self, "_backdropView") transitionToSettings:s];
        }
        else {
            [MSHookIvar<_UIBackdropView*>(self, "_backdropView") transitionToColor:barBGColour];
        }
    }
}

%end

%hook SKUIStackedBarCell

-(void)layoutSubviews {
    %orig;
    MSHookIvar<UILabel*>(self, "_expandedLabel").textColor = barTColour;
}

%end

%hook SKUITabBarBackgroundView

-(void)setBackdropStyle:(long)s {
    //%orig;
    if (blendEnabled || isBlackColour(barBGColour)) {
        [MSHookIvar<_UIBackdropView*>(self, "_backdropView") transitionToStyle:1];
    }
    else if (! [MSHookIvar<_UIBackdropView*>(self, "_backdropView").inputSettings.colorTint isEqual:barBGColour]) {
        if (supportsBlur(MSHookIvar<_UIBackdropView*>(self, "_backdropView"))) {
            _UIBackdropViewSettings* s = [_UIBackdropViewSettings settingsForStyle:0];
            [s setColorTint:barBGColour];
            [s setColorTintAlpha:0.9];
            [MSHookIvar<_UIBackdropView*>(self, "_backdropView") transitionToSettings:s];
        }
        else {
            [MSHookIvar<_UIBackdropView*>(self, "_backdropView") transitionToColor:barBGColour];
        }
    }
}

-(void) setBarStyle:(int)s {
    if (blendEnabled || isBlackColour(barBGColour)) {
        %orig(1);
    }
    else {
        %orig(0);
    }
}

-(void) setBarTintColor:(id)c {
    if (blendEnabled || isBlackColour(barBGColour)) {
        %orig(nil);
    }
    else {
        %orig(barBGColour);
    }
}

-(void) setTranslucent:(BOOL)t {
    %orig(translucencyEnabled);
}

%end

%end

#pragma mark WHATSAPP

%group WHATSAPP

%hook _WANoBlurNavigationBar

- (void)layoutSubviews {
    %orig;
    if (MSHookIvar<UIView*>(self, "_grayBackgroundView")) {
        MSHookIvar<UIView*>(self, "_grayBackgroundView").hidden = YES;
    }
    if ([self._backgroundView _adaptiveBackdrop]) {
        [self._backgroundView _adaptiveBackdrop].hidden = NO;
    }
}

%end

%hook MultilineHeaderView

-(void)layoutSubviews {
    %orig;
    MSHookIvar<UILabel*>(self, "_labelFirstLine").textColor = barTColour;
    MSHookIvar<UILabel*>(self, "_labelSecondLine").textColor = barTColour;
    MSHookIvar<UILabel*>(self, "_labelActivity").textColor = barTColour;
    if (blendEnabled) {
        [MSHookIvar<UILabel*>(self, "_labelFirstLine") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        [MSHookIvar<UILabel*>(self, "_labelSecondLine") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        [MSHookIvar<UILabel*>(self, "_labelActivity") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

%end

%hook WAConversationHeaderView

-(void)layoutSubviews {
    %orig;
    MSHookIvar<UILabel*>(self, "_activityLabel").textColor = barTColour;
    MSHookIvar<UILabel*>(self, "_captionLabel").textColor = barTColour;
    MSHookIvar<UILabel*>(self, "_titleLabel").textColor = barTColour;
    if (blendEnabled) {
        [MSHookIvar<UILabel*>(self, "_activityLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        [MSHookIvar<UILabel*>(self, "_captionLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        [MSHookIvar<UILabel*>(self, "_titleLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

%end

%hook WATheme

-(id)tintColor {
    return darkColour;
}

%end

%hook WATabBarController

-(id)tabBar {
    UITabBar* o = %orig;
    o.backgroundColor = [UIColor clearColor];
    UITabBar* temp = [[UITabBar alloc] initWithFrame:o.bounds];
    if (blendEnabled || isBlackColour(barBGColour)) {
        [temp setBarStyle:1];
    }
    else {
        [temp setBarTintColor:barBGColour];
    }
    [o addSubview:temp];
    [temp layoutSubviews];
    [o _setBackgroundView:temp._backgroundView];
    [temp removeFromSuperview];
    return o;
}

%end

%end

#pragma mark DROPBOX

%group DROPBOX

%hook DBNavUnderlayMenuDefaultTableView

-(void)layoutSubviews {
    %orig;
    ((UIView*)self).backgroundColor = [UIColor whiteColor];
}

%end

%hook UIColor

+(id)dropboxBlueColor {
    return darkColour;
}

%end

%hook DBCoreAppearanceIOS7

- (void)customizeTabBar:(id)arg1 {}
-(void) customizeTabBarAppearance {}

%end
%end

#pragma mark 3IT
%group 3IT
%hook MAVVersion
+ (id)globalTintColor {
    return darkColour;
}
%end
%end // DROPBOX

#pragma mark SAFARI

%group SAFARI

%hook FindOnPageResultsLabel

-(void)setTextColor:(id)col {
    %orig(barTColour);
}

%end

%hook BrowserController

- (void)_setPrivateBrowsingEnabled:(BOOL)arg1 {
    %orig;
    NavigationBarURLButton* but = MSHookIvar<NavigationBarURLButton*>(self.navigationBar, "_URLOutline");
    [but updateForPivateBrowsing:arg1];
}

%end

%hook NavigationBar

- (id)_backdropInputSettings {
    if (blendEnabled || isBlackColour(barBGColour)) {
        return [_UIBackdropViewSettings settingsForStyle:1];
    }
    else {
        if (! MSHookIvar<_UIBackdropView*>(self, "_backdrop").backdropEffectView) {
            [MSHookIvar<_UIBackdropView*>(self, "_backdrop") setBackgroundColor:[barBGColour colorWithAlphaComponent:(translucencyEnabled ? 0.8:1)]];
        }

        _UIBackdropViewSettings* s;
        if (blendEnabled || isBlackColour(barBGColour)) {
            s = [_UIBackdropViewSettings settingsForStyle:1];
        }
        else {
            s = [_UIBackdropViewSettings settingsForStyle:2040];
            [s setColorTint:barBGColour];
            [s setColorTintAlpha:(translucencyEnabled ? 0.9:1)];
        }
        return s;
    }
}

-(void) setBackgroundColor:(id)col {
    if (MSHookIvar<_UIBackdropView*>(self, "_backdrop").backdropEffectView) {
        %orig([UIColor colorWithWhite:0.97 alpha:0.47]);
    }
    else {
        %orig;
    }
}

-(void) _updateTextColor {
    %orig;
    MSHookIvar<UILabel*>(self, "_URLLabel").textColor = barTColour;
    MSHookIvar<UILabel*>(self, "_expandedURLLabel").textColor = barTColour;
    if (blendEnabled) {
        [MSHookIvar<UILabel*>(self, "_expandedURLLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        [MSHookIvar<UILabel*>(self, "_URLLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

-(void) _updateControlTints {
    %orig;
    self.tintColor = barFGColour;
    UIButton* cb = MSHookIvar<UIButton*>(self, "_cancelButton");
    cb.tintColor = barFGColour;
    if (blendEnabled) {
        [(UIView*)cb _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

-(id) _placeholderColor {
    return [barTColour colorWithAlphaComponent:0.5];
}

%end

%hook FluidProgressView

-(void)layoutSubviews {
    %orig;
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

-(void) setProgressBarFillColor:(id)color {
    %orig(barFGColour);
}

%end

%hook CrossfadingImageView

-(void)setToImage:(id)a {
    %orig(imageWithBurnTint(a, barTColour));
}

-(void) setFromImage:(id)a {
    %orig(imageWithBurnTint(a, barTColour));
}

%end

%hook DimmingButton

- (void)setImage:(UIImage*)image forState:(UIControlState)state {
    UIImage* o = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    %orig(o, state);
}

%end

%hook NavigationBarReaderButton

-(id)initWithFrame:(CGRect)frame {
    [self performSelector:@selector(fixColours) withObject:nil afterDelay:0.1];
    return %orig;
}

%new

-(void)fixColours {
    UIImageView* gv = MSHookIvar<UIImageView*>(self, "_glyphView");
    UIImageView* gkv = MSHookIvar<UIImageView*>(self, "_glyphKnockoutView");
    gv.tintColor = barFGColour;
    gv.image = [gv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    gkv.tintColor = barFGColour;
    gkv.image = [gkv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

%end

%hook TabBar

-(void)layoutSubviews {
    %orig;
    if(IS_IOS_8) {
        MSHookIvar<UIView*>(self,"_leftBackgroundOverlayView").backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
        MSHookIvar<UIView*>(self,"_rightBackgroundOverlayView").backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    }
}

%end

%hook TabBarItemView

-(void)layoutSubviews {
    %orig;
    if (! IS_IOS_8) {
        MSHookIvar<UIButton*>(self, "_moreTabsButton").tintColor = barFGColour;
        MSHookIvar<UIButton*>(self, "_closeButton").tintColor = barFGColour;
        if (blendEnabled) {
            [MSHookIvar<UIView*>(self, "_moreTabsButton") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
            [MSHookIvar<UIView*>(self, "_closeButton") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        }
    }
}

-(void) _layoutTitleLabel {
    %orig;
    if (blendEnabled) {
        [MSHookIvar<UIView*>(self, "_titleLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
    else {
        [MSHookIvar<UIView*>(self, "_titleLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeNormal];
    }
    if (self.isActive) {
        MSHookIvar<UILabel*>(self, "_titleLabel").textColor = barTColour;
        if(IS_IOS_8) {
            MSHookIvar<UILabel*>(self, "_titleOverlayLabel").alpha = 0;
            MSHookIvar<UILabel*>(self, "_titleLabel").alpha = 1;
        }
    }
    else {
        if(IS_IOS_8) {
            MSHookIvar<UILabel*>(self, "_titleLabel").textColor = barTColour;
            MSHookIvar<UILabel*>(self, "_titleOverlayLabel").alpha = 0;
            MSHookIvar<UILabel*>(self, "_titleLabel").alpha = 1;
        }
        else {
            MSHookIvar<UILabel*>(self, "_titleLabel").textColor = [barTColour colorWithAlphaComponent:0.5];
        }
    }
}

-(void)_updateTitleBlends{
    %orig;
    if (blendEnabled) {
        [MSHookIvar<UIView*>(self, "_titleLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
    else {
        [MSHookIvar<UIView*>(self, "_titleLabel") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeNormal];
    }
    if (self.isActive) {
        MSHookIvar<UILabel*>(self, "_titleLabel").textColor = [barTColour colorWithAlphaComponent:0.5];
        MSHookIvar<UILabel*>(self, "_titleOverlayLabel").alpha = 0;
        MSHookIvar<UILabel*>(self, "_titleLabel").alpha = 1;
    }
    else {
        MSHookIvar<UILabel*>(self, "_titleLabel").textColor = [barTColour colorWithAlphaComponent:0.5];
        MSHookIvar<UILabel*>(self, "_titleOverlayLabel").alpha = 0;
        MSHookIvar<UILabel*>(self, "_titleLabel").alpha = 1;
    }
}

%end

%hook MatchLabel

-(void)setTextColor:(id)arg1 {
    if (kEnabled) {
        %orig(barTColour);
    }
}

%end

%hook BrowserToolbar

-(void)layoutSubviews {
    %orig;
    if([self isEqual:((BrowserController*)[%c(BrowserController) sharedBrowserController]).bottomToolbar]) {
        if (blendEnabled || isBlackColour(barBGColour)) {
            [MSHookIvar<_UIBackdropView*>(self, "_backgroundView") transitionToSettings:[_UIBackdropViewSettings settingsForStyle:1]];
        }
        else {
            _UIBackdropViewSettings* s = [_UIBackdropViewSettings settingsForStyle:2040];
            [s setColorTint:barBGColour];
            [s setColorTintAlpha:(translucencyEnabled ? 0.9:1)];
            [MSHookIvar<_UIBackdropView*>(self, "_backgroundView") transitionToSettings:s];
        }
    }
}

-(void) updateTintColor {}

%end

%hook NavigationBarURLButton
%new
-(void)updateForPivateBrowsing:(BOOL)a {
    for (id s in self.subviews) {
        if ([s isKindOfClass:%c(NavigationBarURLButtonBackgroundView)]) {
            [(NavigationBarURLButtonBackgroundView*)s updateForPivateBrowsing:a];
        }
    }
}
%end

%hook NavigationBarURLButtonBackgroundView

- (void)layoutSubviews {
    %orig;
    self.layer.cornerRadius = 5;
    self.image = nil;
    self.clipsToBounds = YES;
}

-(void) setImage:(id)arg1 {
    if ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPad) {
        NavigationBarURLButton* b = (NavigationBarURLButton*)self.superview;
        self.alpha = b.backgroundAlphaFactor;
    }
    else {
        self.alpha = 1;
    }
}

%new
-(void)updateForPivateBrowsing:(BOOL)a {
    if (a) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    }
    else {
        self.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    }
}

%end

%hook UnifiedField

-(void)layoutSubviews {
    %orig;
    self.textColor = barTColour;
}

%end

%hook BrowserController

- (void)_updatePrivateBrowsingBarButtonItem {
    %orig;
    if (blendEnabled) {
        [MSHookIvar<UIView*>(self, "_tabViewPrivateBrowsingButton") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
        [MSHookIvar<UIView*>(self, "_privateBrowsingButton") _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

%end

%end // SAFARI

#pragma mark INSTAGRAM

%group INSTAGRAM

%hook IGTimelineHeaderView

- (id)init {
    id o = %orig;
    MSHookIvar<UIView*>(o, "_navbarUnderlayView").hidden =  YES;

    UINavigationBar* nb = self.navbar;
    UIView* bg = MSHookIvar<UIView*>(nb, "_backgroundView");
    nb.clipsToBounds = NO;
    CGRect f = bg.frame;
    f.size.height += 20;
    f.origin.y -= 20;
    bg.frame = f;
    UIImageView* iv = MSHookIvar<UIImageView*>(self, "_logoImageView");
    iv.image = [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    iv.tintColor = barTColour;

    if (blendEnabled) {
        [iv _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }

    return o;
}

%end

%hook IGNavigationBar

-(void)layoutSubviews {
    %orig;
    self.clipsToBounds = NO;
}

%end

%hook IGSegmentedControl

- (void)layoutSubviews {
    %orig;
    UIImageView* iv = MSHookIvar<UIImageView*>(self, "_selectionView");
    iv.tintColor = barTColour;
    iv.image = [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

%end

%hook IGTextSegment

- (void)setSelected:(BOOL)arg1 {
    %orig;
    if (arg1) {
        MSHookIvar<UILabel*>(self, "_titleLabel").textColor = barBGColour;
    }
    else {
        MSHookIvar<UILabel*>(self, "_titleLabel").textColor = barTColour;
    }
}

%end

%hook IGInboxButton

-(void)layoutSubviews {
    %orig;
    ((UIView*)self).tintColor = barFGColour;
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

-(void) setImage:(UIImage*)arg1 forState:(unsigned int)arg2 {
    UIImage* i = [arg1 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    %orig(i, arg2);
}

%end

%hook IGBarButton

-(void)layoutSubviews {
    %orig;
    if (blendEnabled) {
        [(UIView*)self _setDrawsAsBackdropOverlayWithBlendMode:kCGBlendModeOverlay];
    }
}

-(id) initWithTitle:(id)arg1 target:(id)arg2 action:(SEL)arg3 style:(int)arg4 {
    id o = %orig;
    MSHookIvar<UIButton*>(o, "_mainButton").titleLabel.textColor = barFGColour;
    return o;
}

+(id) barButtonItemWithImage:(id)arg1 target:(id)arg2 action:(SEL)arg3 {
    return %orig([arg1 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate], arg2, arg3);
}

%end

%end // INSTAGRAM

#pragma mark MUSIC

%group MUSIC

%hook MusicTheme

+(id)tintColor {
    return darkColour;
}

%end

%hook MusicMiniPlayerPlaybackControlsView

-(id)initWithFrame:(CGRect)arg1 {
    id o = %orig;
    [o performSelector:@selector(fixColours) withObject:nil afterDelay:1];
    return o;
}

-(void) layoutSubviews {
    %orig;
    [self fixColours];
}

%new
-(void)fixColours {
    MSHookIvar<UIButton*>(self, "_shuffleButton").tintColor = barFGColour;
    [MSHookIvar<UIButton*>(self, "_shuffleButton") setTitleColor:barFGColour forState:UIControlStateNormal];
    MSHookIvar<UIButton*>(self, "_createButton").tintColor = barFGColour;
    MSHookIvar<UIButton*>(self, "_repeatButton").tintColor = barFGColour;
    [MSHookIvar<UIButton*>(self, "_repeatButton") setTitleColor:barFGColour forState:UIControlStateNormal];

    UIView* detailSlider = MSHookIvar<UIView*>(self, "_progressControl");
    detailSlider.tintColor = barFGColour;
    MSHookIvar<UILabel*>(detailSlider, "_currentTimeInverseLabel").textColor = barTColour;
    MSHookIvar<UILabel*>(detailSlider, "_currentTimeLabel").textColor = barTColour;

    id titles = MSHookIvar<id>(self, "_titlesView");
    MSHookIvar<UILabel*>(titles, "_titleLabel").textColor = barTColour;
    MSHookIvar<UILabel*>(titles, "_detailLabel").textColor = barTColour;

    id tControls = MSHookIvar<id>(self, "_transportControls");
    MSHookIvar<UIButton*>(tControls, "_playButton").tintColor = barFGColour;
    MSHookIvar<UIButton*>(tControls, "_previousButton").tintColor = barFGColour;
    MSHookIvar<UIButton*>(tControls, "_nextButton").tintColor = barFGColour;
}

%end

%end // MUSIC

//TODO finish support for music controls on ipad
//TODO add support for music view?

#pragma mark CALENDAR

%group CALENDAR

%hook CompactWeekDayInitialsHeaderView

-(void)layoutSubviews {
    %orig;
    ((UIView*)self).backgroundColor = [UIColor whiteColor];
}

%end

%hook CompactMonthDividedListSwitchButton

-(id)foregroundImageWithTintColor:(id)c {
    return %orig(barFGColour);
}

%end

%end // CALENDAR

%group ANY

%hook PUPhotoBrowserTitleView

-(void)_updateLabels {
    %orig;
    MSHookIvar<UILabel*>(self,"_primaryTitleLabel").textColor = barTColour;
    MSHookIvar<UILabel*>(self,"_secondaryTitleLabel").textColor = barTColour;
    MSHookIvar<UILabel*>(self,"_landscapeTitleLabel").textColor = barTColour;
}

%end

%end

__attribute__((always_inline)) static BOOL jabba() {
    //return [[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/dpkg/info/me.chewitt.tinct.list"];
    return YES;
}

#pragma mark CONSTRUCTOR

%ctor {
    updatePrefs();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferencesChangedCallback, CFSTR(PreferencesChangedNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);

    /**NSDate *now = [NSDate new];
       NSCalendar *myCalendar = [[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar];
       NSDateComponents* components = [myCalendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:[NSDate date]];
       [components setYear:2014];
       [components setMonth:9];
       [components setDay:15];
       [components setHour:0];
       [components setMinute:00];
       NSDate *startDate1 = [myCalendar dateFromComponents:components];
       NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
       formatter.timeZone = [NSTimeZone localTimeZone];
          NSComparisonResult result1 = [now compare:startDate1];
       if(result1 == NSOrderedDescending) {
            // DISABLED
       }
       else*/
    if (jabba()) {
        BOOL excluded = NO;

        for (NSString* s in excludedAppsArray) {
            if ([s isEqual:[[NSBundle mainBundle] bundleIdentifier]]) {
                excluded = YES;
            }
        }

        if (enabled && ! excluded) {
            %init(UIKIT);
            %init(ANY);

            if (blendEnabled && ! isCurrentApp(@"com.apple.mobilenotes") && ! isCurrentApp(@"com.apple.iBooks")) {
                %init(BLEND);
            }

            if (isCurrentApp(@"com.apple.springboard")) {
                %init(SPRINGBOARD);
            }
            else if (isCurrentApp(@"com.atebits.Tweetie2")) {
                %init(TWITTER);
            }
            else if (isCurrentApp(@"com.facebook.Facebook")) {
                %init(FACEBOOK);
            }
            else if (isCurrentApp(@"com.apple.mobilephone")) {
                %init(PHONE);
            }
            else if (isCurrentApp(@"com.apple.mobilemail")) {
                %init(MAIL);
            }
            else if (isCurrentApp(@"com.apple.mobilenotes")) {
                %init(NOTES);
            }
            else if (isCurrentApp(@"com.apple.Music")) {
                %init(MUSIC);
            }
            else if (isCurrentApp(@"net.whatsapp.WhatsApp")) {
                %init(WHATSAPP);
            }
            else if (isCurrentApp(@"com.hutchison3g.intouch")) {
                %init(3IT);
            }
            else if (isCurrentApp(@"com.getdropbox.Dropbox")) {
                %init(DROPBOX);
            }
            else if (isCurrentApp(@"com.apple.mobilesafari")) {
                %init(SAFARI);
            }
            else if (isCurrentApp(@"com.facebook.Messenger")) {
                %init(FBMESSENGER);
            }
            else if (isCurrentApp(@"com.burbn.instagram")) {
                %init(INSTAGRAM);
            }
            else if (isCurrentApp(@"com.apple.mobilecal")) {
                %init(CALENDAR);
            }

            if (%c(GKUITheme)) {
                %init(GAMECENTER)
            }
            if (%c(CKUIBehavior)) {
                %init(MESSAGES)
            }
            if (%c(SUApplication) || %c(SKUITabBarBackgroundView)) {
                %init(STOREKIT);
            }
        }

        if ((enabled && ! excluded) || (enabled && excluded && chromaForExcluded)) {
            %init(CHROMA);
            %init(KEYBOARD);
        }
    }
}
