#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Searchable list of installed apps, shown in its own window above the Home Screen.
// completion receives the chosen bundle ID, or nil if the picker was cancelled.
@interface SMTAppPicker : UITableViewController
+ (void)presentFromView:(UIView *)view
              excluding:(NSSet<NSString *> *)excluded
             completion:(void (^)(NSString *_Nullable bundleID))completion;
@end

NS_ASSUME_NONNULL_END
