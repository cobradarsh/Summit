#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const SMTSuiteName;
extern NSString *const SMTPrefsChangedNotification;

// Directions a child app can sit in relative to its parent icon.
extern NSString *const SMTDirectionUp;
extern NSString *const SMTDirectionDown;
extern NSString *const SMTDirectionLeft;
extern NSString *const SMTDirectionRight;
NSArray<NSString *> *SMTAllDirections(void);

// Settings + stack storage, backed by the com.adarsh.summit preferences domain.
// Stacks are stored as { parentBundleID: { direction: childBundleID } }.
@interface SMTStore : NSObject
+ (instancetype)shared;
- (void)reload;

@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) BOOL showLabels;
@property (nonatomic, readonly) BOOL haptics;
@property (nonatomic, readonly) CGFloat fadeAmount;
@property (nonatomic, readonly) CGFloat fadeDuration;
@property (nonatomic, readonly) CGFloat moveDuration;
@property (nonatomic, readonly) CGFloat springDamping;
@property (nonatomic, readonly) CGFloat springVelocity;

- (BOOL)hasStackForBundleID:(NSString *)bundleID;
- (nullable NSString *)childForParent:(NSString *)parent direction:(NSString *)direction;
- (NSArray<NSString *> *)childrenForParent:(NSString *)parent;
// Pass nil as child to clear that slot.
- (void)setChild:(nullable NSString *)child forParent:(NSString *)parent direction:(NSString *)direction;
@end

// Small helpers shared by the overlay and picker.
UIImage *_Nullable SMTIconImage(NSString *bundleID, int format);
NSString *SMTDisplayName(NSString *bundleID);
void SMTLaunchApp(NSString *bundleID);

NS_ASSUME_NONNULL_END
