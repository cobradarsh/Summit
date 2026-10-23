// Private iOS 16 SpringBoard / UIKit / MobileCoreServices declarations used by Summit.
// Only the members we actually touch are declared.

#import <UIKit/UIKit.h>

#pragma mark - SpringBoard icons

@interface SBIcon : NSObject
- (BOOL)isApplicationIcon;
- (NSString *)applicationBundleID;
@end

@interface SBIconView : UIView
@property (nonatomic, strong) SBIcon *icon;
@property (nonatomic, copy) NSString *location;
@property (nonatomic, getter=isEditing) BOOL editing;
- (CGRect)iconImageFrame;
- (NSArray *)applicationShortcutItems;
@end

#pragma mark - Home screen quick actions (context menu)

@interface SBSApplicationShortcutIcon : NSObject
@end

@interface SBSApplicationShortcutSystemPrivateIcon : SBSApplicationShortcutIcon
- (instancetype)initWithSystemImageName:(NSString *)systemImageName;
@end

@interface SBSApplicationShortcutItem : NSObject
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *localizedTitle;
@property (nonatomic, copy) NSString *localizedSubtitle;
@property (nonatomic, copy) SBSApplicationShortcutIcon *icon;
@property (nonatomic, copy) NSString *bundleIdentifierToLaunch;
@end

#pragma mark - App lookup / launching

@interface LSApplicationProxy : NSObject
+ (instancetype)applicationProxyForIdentifier:(NSString *)identifier;
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSString *applicationType;
@property (nonatomic, readonly) NSArray<NSString *> *appTags;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray<LSApplicationProxy *> *)allInstalledApplications;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
@end

// Implemented by SpringBoard (the system app) to launch apps in-process.
@interface UIApplication (SummitPrivate)
- (BOOL)launchApplicationWithIdentifier:(NSString *)identifier suspended:(BOOL)suspended;
@end

@interface UIImage (SummitPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(int)format scale:(CGFloat)scale;
@end
