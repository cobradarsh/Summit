#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <notify.h>

static NSString *const kSuiteName = @"com.adarsh.summit";
static const char *kPrefsChanged = "com.adarsh.summit/prefschanged";

@interface FBSSystemService : NSObject
+ (instancetype)sharedService;
- (void)sendActions:(NSSet *)actions withResult:(id)result;
@end

@interface SBSRelaunchAction : NSObject
+ (instancetype)actionWithReason:(NSString *)reason options:(NSUInteger)options targetURL:(NSURL *)targetURL;
@end

@interface SMTRootListController : PSListController
@end

@implementation SMTRootListController

- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}

- (void)resetStacks {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset All Stacks?"
                                                                   message:@"Every stack will be removed. Your apps are not affected."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kSuiteName];
        [defaults removeObjectForKey:@"Stacks"];
        [defaults synchronize];
        notify_post(kPrefsChanged);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)respring {
    // RestartRenderServer + option 4 (fade to black) is the standard soft respring.
    SBSRelaunchAction *action = [NSClassFromString(@"SBSRelaunchAction") actionWithReason:@"RestartRenderServer" options:4 targetURL:nil];
    [[NSClassFromString(@"FBSSystemService") sharedService] sendActions:[NSSet setWithObject:action] withResult:nil];
}

@end
