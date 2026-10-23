#import "SMTAppPicker.h"
#import "SMTStore.h"
#import "Headers.h"

// Small (settings-sized) icon format for table rows.
static const int kSMTRowIconFormat = 0;

static UIWindow *gPickerWindow;
static __weak UIWindow *gPreviousKeyWindow;

static void SMTTearDownPickerWindow(void) {
    gPickerWindow.hidden = YES;
    gPickerWindow = nil;
    [gPreviousKeyWindow makeKeyWindow];
}

@interface SMTAppEntry : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *bundleID;
@end

@implementation SMTAppEntry
@end

@interface SMTAppPicker () <UISearchResultsUpdating, UIAdaptivePresentationControllerDelegate>
@end

@implementation SMTAppPicker {
    NSSet<NSString *> *_excluded;
    void (^_completion)(NSString *);
    NSArray<SMTAppEntry *> *_apps;
    NSArray<SMTAppEntry *> *_filtered;
    NSCache<NSString *, UIImage *> *_iconCache;
    BOOL _finished;
}

+ (void)presentFromView:(UIView *)view excluding:(NSSet<NSString *> *)excluded completion:(void (^)(NSString *))completion {
    UIWindowScene *scene = view.window.windowScene;
    if (gPickerWindow || !scene) return;

    gPreviousKeyWindow = view.window;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    window.windowLevel = UIWindowLevelAlert + 1;
    window.backgroundColor = [UIColor clearColor];
    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = [UIColor clearColor];
    window.rootViewController = root;
    gPickerWindow = window;
    [window makeKeyAndVisible];

    SMTAppPicker *picker = [[SMTAppPicker alloc] initWithExcluded:excluded completion:completion];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
    nav.presentationController.delegate = picker;
    [root presentViewController:nav animated:YES completion:nil];
}

- (instancetype)initWithExcluded:(NSSet<NSString *> *)excluded completion:(void (^)(NSString *))completion {
    if (!(self = [super initWithStyle:UITableViewStylePlain])) return nil;
    _excluded = [excluded copy];
    _completion = [completion copy];
    _apps = @[];
    _filtered = @[];
    _iconCache = [[NSCache alloc] init];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Add to Stack";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(cancel)];
    self.tableView.rowHeight = 56;

    UISearchController *search = [[UISearchController alloc] initWithSearchResultsController:nil];
    search.searchResultsUpdater = self;
    search.obscuresBackgroundDuringPresentation = NO;
    search.searchBar.placeholder = @"Search Apps";
    self.navigationItem.searchController = search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;

    [self loadApps];
}

- (void)loadApps {
    NSSet *excluded = _excluded;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray<SMTAppEntry *> *apps = [NSMutableArray array];
        for (LSApplicationProxy *proxy in [[NSClassFromString(@"LSApplicationWorkspace") defaultWorkspace] allInstalledApplications]) {
            NSString *bundleID = proxy.applicationIdentifier;
            NSString *type = proxy.applicationType;
            if (!bundleID.length || [excluded containsObject:bundleID]) continue;
            if (![type isEqualToString:@"User"] && ![type isEqualToString:@"System"]) continue;
            if ([proxy.appTags containsObject:@"hidden"]) continue;

            SMTAppEntry *entry = [[SMTAppEntry alloc] init];
            entry.bundleID = bundleID;
            entry.name = proxy.localizedName.length ? proxy.localizedName : bundleID;
            [apps addObject:entry];
        }
        [apps sortUsingComparator:^NSComparisonResult(SMTAppEntry *a, SMTAppEntry *b) {
            return [a.name localizedCaseInsensitiveCompare:b.name];
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            self->_apps = apps;
            [self updateSearchResultsForSearchController:self.navigationItem.searchController];
        });
    });
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = [searchController.searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!query.length) {
        _filtered = _apps;
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@ OR bundleID CONTAINS[cd] %@", query, query];
        _filtered = [_apps filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

#pragma mark Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _filtered.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const reuseID = @"SMTAppCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseID]
        ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseID];

    SMTAppEntry *entry = _filtered[indexPath.row];
    UIImage *icon = [_iconCache objectForKey:entry.bundleID];
    if (!icon) {
        icon = SMTIconImage(entry.bundleID, kSMTRowIconFormat);
        if (icon) [_iconCache setObject:icon forKey:entry.bundleID];
    }
    cell.imageView.image = icon;
    cell.textLabel.text = entry.name;
    cell.detailTextLabel.text = entry.bundleID;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self finishWithBundleID:_filtered[indexPath.row].bundleID];
}

#pragma mark Finishing

- (void)cancel {
    [self finishWithBundleID:nil];
}

- (void)finishWithBundleID:(NSString *)bundleID {
    if (_finished) return;
    _finished = YES;
    void (^completion)(NSString *) = _completion;
    [self.navigationController dismissViewControllerAnimated:YES completion:^{
        SMTTearDownPickerWindow();
        if (completion) completion(bundleID);
    }];
}

// Swipe-down dismissal of the sheet.
- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    if (_finished) return;
    _finished = YES;
    SMTTearDownPickerWindow();
    if (_completion) _completion(nil);
}

@end
