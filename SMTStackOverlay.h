#import <UIKit/UIKit.h>

@class SBIconView;

// Full-screen overlay that fans a parent icon's stack out around it.
// In editing mode every direction shows a slot: "+" to add an app, tap an app to remove it.
@interface SMTStackOverlay : UIView
+ (void)presentForIconView:(SBIconView *)iconView bundleID:(NSString *)bundleID editing:(BOOL)editing;
+ (void)dismissCurrentAnimated:(BOOL)animated;
@end
