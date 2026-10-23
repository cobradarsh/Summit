#import "SMTStackOverlay.h"
#import "SMTStore.h"
#import "SMTAppPicker.h"
#import "Headers.h"

// _applicationIconImageForBundleIdentifier format that matches Home Screen icon size.
static const int kSMTHomeIconFormat = 2;

static SMTStackOverlay *gCurrentOverlay;

static CGPoint SMTOffsetForDirection(NSString *direction, CGFloat hStep, CGFloat vStep) {
    if ([direction isEqualToString:SMTDirectionUp]) return CGPointMake(0, -vStep);
    if ([direction isEqualToString:SMTDirectionDown]) return CGPointMake(0, vStep);
    if ([direction isEqualToString:SMTDirectionLeft]) return CGPointMake(-hStep, 0);
    return CGPointMake(hStep, 0);
}

#pragma mark - Slot

// One position around the parent: either a child app or (while editing) an empty "+" slot.
@interface SMTSlotView : UIControl
@property (nonatomic, copy) NSString *direction;
@property (nonatomic, copy, readonly) NSString *bundleID;
@property (nonatomic) CGPoint targetCenter;
@end

@implementation SMTSlotView

- (instancetype)initWithIconSize:(CGFloat)size labelHeight:(CGFloat)labelHeight bundleID:(NSString *)bundleID editing:(BOOL)editing {
    if (!(self = [super initWithFrame:CGRectMake(0, 0, size, size + labelHeight)])) return nil;
    _bundleID = [bundleID copy];
    CGRect iconRect = CGRectMake(0, 0, size, size);

    if (bundleID) {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:iconRect];
        imageView.image = SMTIconImage(bundleID, kSMTHomeIconFormat);
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.userInteractionEnabled = NO;
        [self addSubview:imageView];

        if (editing) {
            UIImageView *badge = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"minus.circle.fill"]];
            badge.frame = CGRectMake(-7, -7, 24, 24);
            badge.tintColor = [UIColor systemRedColor];
            badge.backgroundColor = [UIColor whiteColor];
            badge.layer.cornerRadius = 12;
            badge.userInteractionEnabled = NO;
            [self addSubview:badge];
        }
    } else {
        UIView *placeholder = [[UIView alloc] initWithFrame:iconRect];
        placeholder.backgroundColor = [UIColor colorWithWhite:1 alpha:0.18];
        placeholder.layer.cornerRadius = size * 0.225;
        placeholder.layer.cornerCurve = kCACornerCurveContinuous;
        placeholder.layer.borderWidth = 1.5;
        placeholder.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.55].CGColor;
        placeholder.userInteractionEnabled = NO;

        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:size * 0.38 weight:UIImageSymbolWeightSemibold];
        UIImageView *plus = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"plus" withConfiguration:config]];
        plus.tintColor = [UIColor whiteColor];
        plus.center = CGPointMake(size / 2, size / 2);
        [placeholder addSubview:plus];
        [self addSubview:placeholder];
    }

    if (labelHeight > 0) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(-14, size + 4, size + 28, labelHeight - 4)];
        label.text = bundleID ? SMTDisplayName(bundleID) : @"Add";
        label.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        label.layer.shadowColor = [UIColor blackColor].CGColor;
        label.layer.shadowOpacity = 0.4;
        label.layer.shadowRadius = 2;
        label.layer.shadowOffset = CGSizeZero;
        [self addSubview:label];
    }

    return self;
}

@end

#pragma mark - Overlay

@implementation SMTStackOverlay {
    __weak SBIconView *_iconView;
    NSString *_bundleID;
    BOOL _editing;
    BOOL _dismissing;
    CGFloat _savedIconAlpha;

    CGRect _originFrame;       // parent icon image, in overlay coordinates
    CGPoint _anchor;           // where the parent sits while the stack is open
    CGFloat _iconSize;
    CGFloat _labelHeight;
    UIEdgeInsets _safeInsets;

    UIView *_dimView;
    UIImageView *_parentView;
    NSMutableArray<SMTSlotView *> *_slots;
}

+ (void)presentForIconView:(SBIconView *)iconView bundleID:(NSString *)bundleID editing:(BOOL)editing {
    UIWindow *window = iconView.window;
    if (gCurrentOverlay || !window || !bundleID) return;

    SMTStackOverlay *overlay = [[self alloc] initWithIconView:iconView bundleID:bundleID editing:editing];
    gCurrentOverlay = overlay;
    [window addSubview:overlay];
    [overlay animateIn];
}

+ (void)dismissCurrentAnimated:(BOOL)animated {
    [gCurrentOverlay dismissAnimated:animated];
}

- (instancetype)initWithIconView:(SBIconView *)iconView bundleID:(NSString *)bundleID editing:(BOOL)editing {
    UIWindow *window = iconView.window;
    if (!(self = [super initWithFrame:window.bounds])) return nil;

    _iconView = iconView;
    _bundleID = [bundleID copy];
    _editing = editing;
    _safeInsets = window.safeAreaInsets;
    _slots = [NSMutableArray array];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    CGRect imageFrame = [iconView respondsToSelector:@selector(iconImageFrame)]
        ? [iconView iconImageFrame]
        : CGRectMake(0, 0, iconView.bounds.size.width, iconView.bounds.size.width);
    _originFrame = [iconView convertRect:imageFrame toView:window];
    _iconSize = _originFrame.size.width;
    _labelHeight = [SMTStore shared].showLabels ? 20 : 0;

    _dimView = [[UIView alloc] initWithFrame:self.bounds];
    _dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _dimView.backgroundColor = [UIColor blackColor];
    _dimView.alpha = 0;
    [_dimView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped)]];
    [self addSubview:_dimView];

    _parentView = [[UIImageView alloc] initWithFrame:_originFrame];
    _parentView.image = SMTIconImage(bundleID, kSMTHomeIconFormat);
    _parentView.contentMode = UIViewContentModeScaleAspectFit;
    _parentView.userInteractionEnabled = YES;
    [_parentView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(parentTapped)]];
    [self addSubview:_parentView];

    [self rebuildSlots];
    return self;
}

#pragma mark Layout

- (CGFloat)horizontalStep { return _iconSize + MAX(18, _iconSize * 0.4); }
- (CGFloat)verticalStep { return _iconSize + _labelHeight + MAX(14, _iconSize * 0.3); }

- (CGPoint)originCenter {
    return CGPointMake(CGRectGetMidX(_originFrame), CGRectGetMidY(_originFrame));
}

- (NSArray<NSString *> *)visibleDirections {
    if (_editing) return SMTAllDirections();
    NSMutableArray *directions = [NSMutableArray array];
    for (NSString *direction in SMTAllDirections()) {
        if ([[SMTStore shared] childForParent:_bundleID direction:direction]) [directions addObject:direction];
    }
    return directions;
}

// Slide the parent inward when it sits near an edge so every slot stays on screen.
- (CGPoint)anchorForDirections:(NSArray<NSString *> *)directions {
    CGPoint center = [self originCenter];
    CGFloat margin = 10, half = _iconSize / 2;
    CGSize size = self.bounds.size;

    CGFloat minX = _safeInsets.left + margin + half;
    CGFloat maxX = size.width - _safeInsets.right - margin - half;
    CGFloat minY = _safeInsets.top + margin + half;
    CGFloat maxY = size.height - _safeInsets.bottom - margin - half - _labelHeight;

    if ([directions containsObject:SMTDirectionLeft]) minX += [self horizontalStep];
    if ([directions containsObject:SMTDirectionRight]) maxX -= [self horizontalStep];
    if ([directions containsObject:SMTDirectionUp]) minY += [self verticalStep];
    if ([directions containsObject:SMTDirectionDown]) maxY -= [self verticalStep];

    center.x = MIN(MAX(center.x, minX), maxX);
    center.y = MIN(MAX(center.y, minY), maxY);
    return center;
}

- (void)rebuildSlots {
    for (SMTSlotView *slot in _slots) [slot removeFromSuperview];
    [_slots removeAllObjects];

    NSArray<NSString *> *directions = [self visibleDirections];
    _anchor = [self anchorForDirections:directions];

    for (NSString *direction in directions) {
        NSString *child = [[SMTStore shared] childForParent:_bundleID direction:direction];
        SMTSlotView *slot = [[SMTSlotView alloc] initWithIconSize:_iconSize labelHeight:_labelHeight bundleID:child editing:_editing];
        slot.direction = direction;

        CGPoint offset = SMTOffsetForDirection(direction, [self horizontalStep], [self verticalStep]);
        slot.targetCenter = CGPointMake(_anchor.x + offset.x, _anchor.y + offset.y + _labelHeight / 2);
        [slot addTarget:self action:@selector(slotTapped:) forControlEvents:UIControlEventTouchUpInside];

        // Slots live under the parent so they appear to slide out from beneath it.
        [self insertSubview:slot belowSubview:_parentView];
        [_slots addObject:slot];
    }
}

#pragma mark Animation

- (void)animateIn {
    SMTStore *store = [SMTStore shared];
    SBIconView *iconView = _iconView;
    _savedIconAlpha = iconView.alpha;
    iconView.alpha = 0;

    CGPoint origin = [self originCenter];
    for (SMTSlotView *slot in _slots) {
        slot.center = CGPointMake(origin.x, origin.y + _labelHeight / 2);
        slot.alpha = 0;
        slot.transform = CGAffineTransformMakeScale(0.3, 0.3);
    }

    if (store.haptics) [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    [UIView animateWithDuration:store.fadeDuration animations:^{
        self->_dimView.alpha = store.fadeAmount;
    }];
    [UIView animateWithDuration:store.moveDuration
                          delay:0
         usingSpringWithDamping:store.springDamping
          initialSpringVelocity:store.springVelocity
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self->_parentView.center = self->_anchor;
        for (SMTSlotView *slot in self->_slots) {
            slot.center = slot.targetCenter;
            slot.alpha = 1;
            slot.transform = CGAffineTransformIdentity;
        }
    } completion:nil];
}

- (void)dismissAnimated:(BOOL)animated {
    if (_dismissing) return;
    _dismissing = YES;
    if (gCurrentOverlay == self) gCurrentOverlay = nil;
    self.userInteractionEnabled = NO;

    SMTStore *store = [SMTStore shared];
    CGPoint origin = [self originCenter];
    void (^finish)(BOOL) = ^(BOOL finished) {
        self->_iconView.alpha = self->_savedIconAlpha;
        [self removeFromSuperview];
    };

    if (!animated) {
        finish(YES);
        return;
    }

    [UIView animateWithDuration:store.fadeDuration animations:^{
        self->_dimView.alpha = 0;
    }];
    [UIView animateWithDuration:store.moveDuration * 0.7
                          delay:0
         usingSpringWithDamping:1
          initialSpringVelocity:0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self->_parentView.center = origin;
        for (SMTSlotView *slot in self->_slots) {
            slot.center = CGPointMake(origin.x, origin.y + self->_labelHeight / 2);
            slot.alpha = 0;
            slot.transform = CGAffineTransformMakeScale(0.3, 0.3);
        }
    } completion:finish];
}

// After an edit, swap the slots in place with a small pop on the changed one.
- (void)refreshSlotsHighlightingDirection:(NSString *)direction {
    [self rebuildSlots];
    for (SMTSlotView *slot in _slots) {
        slot.center = slot.targetCenter;
        if ([slot.direction isEqualToString:direction]) slot.transform = CGAffineTransformMakeScale(0.7, 0.7);
    }
    _parentView.center = _anchor;

    SMTStore *store = [SMTStore shared];
    [UIView animateWithDuration:store.moveDuration
                          delay:0
         usingSpringWithDamping:store.springDamping
          initialSpringVelocity:store.springVelocity
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        for (SMTSlotView *slot in self->_slots) slot.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark Actions

- (void)backgroundTapped {
    [self dismissAnimated:YES];
}

- (void)parentTapped {
    [self dismissAnimated:YES];
    if (!_editing) SMTLaunchApp(_bundleID);
}

- (void)slotTapped:(SMTSlotView *)slot {
    SMTStore *store = [SMTStore shared];

    if (!_editing) {
        [self dismissAnimated:YES];
        SMTLaunchApp(slot.bundleID);
        return;
    }

    NSString *direction = slot.direction;
    if (slot.bundleID) {
        [store setChild:nil forParent:_bundleID direction:direction];
        if (store.haptics) [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
        [self refreshSlotsHighlightingDirection:direction];
        return;
    }

    NSMutableSet *excluded = [NSMutableSet setWithObject:_bundleID];
    [excluded addObjectsFromArray:[store childrenForParent:_bundleID]];

    NSString *parent = _bundleID;
    __weak SMTStackOverlay *weakSelf = self;
    [SMTAppPicker presentFromView:self excluding:excluded completion:^(NSString *picked) {
        if (!picked) return;
        [[SMTStore shared] setChild:picked forParent:parent direction:direction];
        [weakSelf refreshSlotsHighlightingDirection:direction];
    }];
}

@end
