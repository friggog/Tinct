
#import <UIKit/_UIBackdropViewSettings.h>
#import <UIKit/_UIBackdropView.h>

@interface FBJewelButton : UIButton
@end

@interface FBActionButton : UIButton
@end

@interface FBBouncyPressButton : UIButton
@end



@interface UISearchBarTextField : UITextField
@end

@interface UISearchBar (chew)
-(UISearchBarTextField*)searchField;
-(void)setDrawsBackground:(BOOL)a;
@end

@interface UIKBRenderConfig : NSObject
+(id)darkConfig;
@end

@interface TabBarItemView : UIView {}
@property(nonatomic, getter=isActive) BOOL active;
@end

@interface NavigationBarURLButton : UIButton
@property(nonatomic) _Bool showsDarkBackground;
@property(nonatomic) CGFloat backgroundAlphaFactor;
- (void)_updateBackgroundImageAnimated:(_Bool)arg1;
-(void)updateForPivateBrowsing:(BOOL)a;
@end

@interface NavigationBarReaderButton : UIView
@end

@interface NavigationBar : UINavigationBar
@end

@interface NavigationBarURLButtonBackgroundView : UIImageView
-(void)updateForPivateBrowsing:(BOOL)a;
@end

@interface BrowserToolbar : UIView
@end

@interface BrowserController : UIView
+ (id)sharedBrowserController;
@property(readonly, nonatomic) id navigationBar;
@property(readonly, nonatomic) BrowserToolbar *topToolbar;
@property(readonly, nonatomic) BrowserToolbar *bottomToolbar;
@end

@interface UIKBBackdropView : _UIBackdropView
-(void)updateColours;
@end

@interface UnifiedField : UITextField {}
@end

@interface CrossfadingImageView : UIView
@end

@interface UIKBInputBackdropView : UIView
@property (nonatomic,retain) UIKBBackdropView * inputBackdropFullView;
@property (nonatomic,retain) UIKBBackdropView * inputBackdropLeftView;
@property (nonatomic,retain) UIKBBackdropView * inputBackdropRightView;
@end

@interface UISegmentedControl (chew)
-(UIColor*)correctTintColorForThis;
@end

@interface SBControlCenterContentContainerView : UIView
@property(readonly, nonatomic) _UIBackdropView *backdropView;
@end

@interface SBWallpaperEffectView: UIView
-(void)setStyle:(int)s;
@end

@interface SBNotificationCenterViewController : UIView
@property(readonly, nonatomic) _UIBackdropView *backdropView;
-(void)fixBackdropView;
@end

@interface SBBannerContextView : UIView {}
@property(readonly, nonatomic) _UIBackdropView *backdrop;
@end

@interface UIColor (chew)
+(id)systemBlueColor;
+(id)systemGreenColor;
+(id)systemOrangeColor;
+(id)systemYellowColor;
+(id)systemTealColor;
+(id)systemRedColor;
+(id)systemPinkColor;
+(id)systemGrayColor;
+(id)systemMidGrayColor;
+(id)systemDarkRedColor;
@end

@interface UITabBarButton : UIView
-(void)_setUnselectedTintColor:(id)arg1;
@end

@interface FBTabBarItemView
@property(readonly, nonatomic) BOOL isSelected;
@end

@interface NoteCell : UITableViewCell {}
@end

@interface _UITextFieldRoundedRectBackgroundViewNeue : UIView{}
@property(retain) UIColor * fillColor;
@property(retain) UIColor * strokeColor;
@end

@interface CKMessageEntryView : UIView {}
@property(retain) UIButton * sendButton;
@property BOOL sendButtonColor;
@property(retain) _UITextFieldRoundedRectBackgroundViewNeue * coverView;
@property (nonatomic,copy) NSString * placeholderText;
@property (nonatomic,retain) _UIBackdropView * backdropView;
-(void)updateBackgroundColourForTinct;
@end

@interface CKMessageEntryTextView : UITextView {}
@property (nonatomic,retain) UILabel * placeholderLabel;
@end

@interface CKTranscriptController : UIViewController {}
@property (nonatomic,retain) CKMessageEntryView * entryView;
@end

@interface SUNavigationBarBackgroundView : UIView
- (void)setBarStyle:(long long)arg1;
- (void)setTranslucent:(bool)arg1;
- (void)setBarTintColor:(id)arg1;

@end

@interface _UINavigationBarBackground : UIView
-(_UIBackdropView*)_adaptiveBackdrop;
@end

@interface UINavigationBar (chewitt)
@property _UINavigationBarBackground * _backgroundView;
@end

@interface _WANoBlurNavigationBar : UINavigationBar
@end

@interface UITabBar (chewitt)
@property UIView * _backgroundView;
-(void)_setBackgroundView:(id)arg1 ;
@end

@interface UIStatusBar : UIView
+(id)_styleAttributesForStatusBarStyle:(long long)arg1 legacy:(bool)arg2 ;
@end


@interface IGTimelineHeaderView : UIView {}
@property(retain, nonatomic) UINavigationBar *navbar;
@end

@interface IGNavigationBar: UIView {}
@end

@interface UIView (chew)
-(void)_setDrawsAsBackdropOverlayWithBlendMode:(long)a;
@end

@interface UIToolbarButton : UIView
@end

@interface UINavigationButton : UIView
@end

@interface MusicMiniPlayerPlaybackControlsView : UIView
-(void)fixColours;
@end

@interface PHHandsetDialerLCDView : UIView
@property(retain) UIButton *deleteButton;
@property(retain) UIButton *addContactButton;
@property(retain, nonatomic) UILabel *numberLabel;
@end

@interface FBFlexibleSplitViewController : UIViewController
@end

@interface SKUITabBarBackgroundView
-(void)setBarStyle:(long long)arg1 ;
-(void)setBarTintColor:(UIColor *)arg1 ;
-(void)setTranslucent:(BOOL)arg1 ;
@end

@interface T1TabView
@property(nonatomic, getter=isSelected) BOOL selected;
@property(readonly, nonatomic) UILabel *titleLabel;
@property(readonly, nonatomic) UIImageView *imageView;
@end

@interface SBSearchHeader
@property (nonatomic,retain,readonly) UITextField * searchField;
@end

@interface TFNButton : UIView
-(void)setTintColor:(id)a forState:(NSInteger)b;
@end
