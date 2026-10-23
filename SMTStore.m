#import "SMTStore.h"
#import "Headers.h"

NSString *const SMTSuiteName = @"com.adarsh.summit";
NSString *const SMTPrefsChangedNotification = @"com.adarsh.summit/prefschanged";

NSString *const SMTDirectionUp = @"up";
NSString *const SMTDirectionDown = @"down";
NSString *const SMTDirectionLeft = @"left";
NSString *const SMTDirectionRight = @"right";

static NSString *const kStacksKey = @"Stacks";

NSArray<NSString *> *SMTAllDirections(void) {
    return @[SMTDirectionUp, SMTDirectionDown, SMTDirectionLeft, SMTDirectionRight];
}

@implementation SMTStore {
    NSUserDefaults *_defaults;
}

+ (instancetype)shared {
    static SMTStore *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SMTStore alloc] init]; });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) [self reload];
    return self;
}

- (void)reload {
    // Drop SpringBoard's cached copy so changes made in Settings are picked up.
    CFPreferencesAppSynchronize((__bridge CFStringRef)SMTSuiteName);
    _defaults = [[NSUserDefaults alloc] initWithSuiteName:SMTSuiteName];
}

- (BOOL)boolForKey:(NSString *)key fallback:(BOOL)fallback {
    id value = [_defaults objectForKey:key];
    return value ? [value boolValue] : fallback;
}

- (CGFloat)floatForKey:(NSString *)key fallback:(CGFloat)fallback {
    id value = [_defaults objectForKey:key];
    return value ? [value doubleValue] : fallback;
}

- (BOOL)enabled { return [self boolForKey:@"enabled" fallback:YES]; }
- (BOOL)showLabels { return [self boolForKey:@"showLabels" fallback:YES]; }
- (BOOL)haptics { return [self boolForKey:@"haptics" fallback:YES]; }
- (CGFloat)fadeAmount { return [self floatForKey:@"fadeAmount" fallback:0.6]; }
- (CGFloat)fadeDuration { return [self floatForKey:@"fadeDuration" fallback:0.25]; }
- (CGFloat)moveDuration { return [self floatForKey:@"moveDuration" fallback:0.5]; }
- (CGFloat)springDamping { return [self floatForKey:@"springDamping" fallback:0.75]; }
- (CGFloat)springVelocity { return [self floatForKey:@"springVelocity" fallback:0.5]; }

#pragma mark - Stacks

- (NSDictionary *)stacks {
    NSDictionary *stacks = [_defaults dictionaryForKey:kStacksKey];
    return stacks ?: @{};
}

- (NSDictionary *)stackForParent:(NSString *)parent {
    id stack = self.stacks[parent];
    return [stack isKindOfClass:[NSDictionary class]] ? stack : nil;
}

- (BOOL)hasStackForBundleID:(NSString *)bundleID {
    return [self stackForParent:bundleID].count > 0;
}

- (NSString *)childForParent:(NSString *)parent direction:(NSString *)direction {
    id child = [self stackForParent:parent][direction];
    return [child isKindOfClass:[NSString class]] ? child : nil;
}

- (NSArray<NSString *> *)childrenForParent:(NSString *)parent {
    NSMutableArray *children = [NSMutableArray array];
    for (NSString *direction in SMTAllDirections()) {
        NSString *child = [self childForParent:parent direction:direction];
        if (child) [children addObject:child];
    }
    return children;
}

- (void)setChild:(NSString *)child forParent:(NSString *)parent direction:(NSString *)direction {
    NSMutableDictionary *all = [self.stacks mutableCopy];
    NSMutableDictionary *stack = [[self stackForParent:parent] mutableCopy] ?: [NSMutableDictionary dictionary];
    if (child) stack[direction] = child;
    else [stack removeObjectForKey:direction];

    if (stack.count) all[parent] = stack;
    else [all removeObjectForKey:parent];
    [_defaults setObject:all forKey:kStacksKey];
}

@end

#pragma mark - Helpers

UIImage *SMTIconImage(NSString *bundleID, int format) {
    if (!bundleID.length) return nil;
    return [UIImage _applicationIconImageForBundleIdentifier:bundleID format:format scale:[UIScreen mainScreen].scale];
}

NSString *SMTDisplayName(NSString *bundleID) {
    LSApplicationProxy *proxy = [NSClassFromString(@"LSApplicationProxy") applicationProxyForIdentifier:bundleID];
    return proxy.localizedName.length ? proxy.localizedName : bundleID;
}

void SMTLaunchApp(NSString *bundleID) {
    if (!bundleID.length) return;

    // Launch through SpringBoard itself. Calling LaunchServices synchronously from SpringBoard's
    // main thread stalls for seconds, because LaunchServices turns around and asks SpringBoard to open the app.
    UIApplication *springBoard = [UIApplication sharedApplication];
    if ([springBoard respondsToSelector:@selector(launchApplicationWithIdentifier:suspended:)]) {
        [springBoard launchApplicationWithIdentifier:bundleID suspended:NO];
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        [[NSClassFromString(@"LSApplicationWorkspace") defaultWorkspace] openApplicationWithBundleID:bundleID];
    });
}
