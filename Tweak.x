// Summit — nest apps in a "stack" under any Home Screen icon.
//
//  • Swipe up on an icon that has a stack  → its child apps fan out around it.
//  • Swipe up on any icon in jiggle mode   → edit that icon's stack.
//  • Long-press an icon → "Create Stack" / "Edit Stack" → edit that icon's stack.

#import <objc/runtime.h>
#import "Headers.h"
#import "SMTStore.h"
#import "SMTStackOverlay.h"

static NSString *const kSMTShortcutType = @"com.adarsh.summit.edit-stack";
static char kSMTSwipeKey;

static NSString *SMTEligibleBundleID(SBIconView *iconView) {
    if (![SMTStore shared].enabled) return nil;

    SBIcon *icon = iconView.icon;
    if (![icon respondsToSelector:@selector(isApplicationIcon)] || ![icon isApplicationIcon]) return nil;

    // Keep out of the App Library and other non-Home-Screen icon lists.
    NSString *location = [iconView respondsToSelector:@selector(location)] ? iconView.location : nil;
    if ([location containsString:@"AppLibrary"]) return nil;

    NSString *bundleID = [icon applicationBundleID];
    return bundleID.length ? bundleID : nil;
}

%hook SBIconView

- (void)didMoveToWindow {
    %orig;
    if (!self.window || objc_getAssociatedObject(self, &kSMTSwipeKey)) return;

    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(smt_handleSwipeUp:)];
    swipe.direction = UISwipeGestureRecognizerDirectionUp;
    [self addGestureRecognizer:swipe];
    objc_setAssociatedObject(self, &kSMTSwipeKey, swipe, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (void)smt_handleSwipeUp:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateRecognized) return;

    NSString *bundleID = SMTEligibleBundleID(self);
    if (!bundleID) return;

    BOOL editing = [self respondsToSelector:@selector(isEditing)] && self.isEditing;
    if (!editing && ![[SMTStore shared] hasStackForBundleID:bundleID]) return;

    [SMTStackOverlay presentForIconView:self bundleID:bundleID editing:editing];
}

- (NSArray *)applicationShortcutItems {
    NSArray *items = %orig;
    NSString *bundleID = SMTEligibleBundleID(self);
    if (!bundleID) return items;

    SBSApplicationShortcutItem *item = [[%c(SBSApplicationShortcutItem) alloc] init];
    item.type = kSMTShortcutType;
    item.localizedTitle = [[SMTStore shared] hasStackForBundleID:bundleID] ? @"Edit Stack" : @"Create Stack";
    item.icon = [[%c(SBSApplicationShortcutSystemPrivateIcon) alloc] initWithSystemImageName:@"square.stack.3d.up"];
    item.bundleIdentifierToLaunch = bundleID;

    NSMutableArray *result = items ? [items mutableCopy] : [NSMutableArray array];
    [result addObject:item];
    return result;
}

+ (void)activateShortcut:(SBSApplicationShortcutItem *)item withBundleIdentifier:(NSString *)bundleID forIconView:(SBIconView *)iconView {
    if (![item.type isEqualToString:kSMTShortcutType]) {
        %orig;
        return;
    }
    // Let the context menu finish dismissing before the overlay appears.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SMTStackOverlay presentForIconView:iconView bundleID:bundleID editing:YES];
    });
}

%end

static void SMTPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[SMTStore shared] reload];
}

%ctor {
    [SMTStore shared];
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, SMTPrefsChanged,
                                    (__bridge CFStringRef)SMTPrefsChangedNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}
