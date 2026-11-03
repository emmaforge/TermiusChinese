#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "zh_dict.h"

// TermiusChinese: runtime display-layer translation for Termius iOS.
//
// Design decisions (do not "improve" silently):
// 1. FULL-MATCH ONLY. A string is translated only if the whole string
//    (or the whole string after trimming spaces) is a dictionary key.
//    No substring / prefix replacement. This is what keeps host names,
//    usernames, file paths, commands and terminal output safe: they are
//    almost never exactly equal to a UI phrase like "Connect".
// 2. NO terminal / input content hooks. UITextView.text and
//    UITextField.text are deliberately NOT hooked. Only placeholders,
//    labels, buttons, nav/tab items, alerts and segmented titles are.
// 3. Dictionary is compiled INTO the dylib (zh_dict.h). No external
//    .bundle / .json file is needed, so TrollFools injection (dylib
//    only) works the same as a jailbreak .deb install.
// 4. Pure ObjC runtime swizzling, no Logos, no Substrate headers.
//    Works under ElleKit (RootHide/Relaxin) and under TrollFools'
//    substrate shim, because the constructor runs when the dylib loads.
//
// LIMITS, stated plainly:
// - This translates UIKit text. If Termius iOS renders a screen with
//   SwiftUI Text, a custom-drawn terminal view, or a web view, that
//   screen will not be covered by these hooks. That is why the
//   extract script exists: dump the real IPA strings first, then
//   extend the dictionary / hooks for what is actually there.
// - A translated label keeps only the first attribute run. Labels
//   with mixed colours/fonts inside one string will lose the mix.

static NSDictionary<NSString *, NSString *> *gDict = nil;

static NSString *TermiusZhTranslate(NSString *s) {
    if (!s || s.length == 0 || s.length > 260) return s;
    if ([s rangeOfString:@"\n"].location != NSNotFound) return s;
    NSString *hit = gDict[s];
    if (hit) return hit;
    NSString *trimmed = [s stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceCharacterSet]];
    if (trimmed.length == 0 || [trimmed isEqualToString:s]) return s;
    hit = gDict[trimmed];
    if (!hit) return s;
    // Re-apply leading/trailing spaces so layout does not shift.
    NSUInteger lead = 0;
    while (lead < s.length && [s characterAtIndex:lead] == ' ') lead++;
    NSUInteger trail = 0;
    while (trail < s.length - lead &&
           [s characterAtIndex:(s.length - 1 - trail)] == ' ') trail++;
    return [NSString stringWithFormat:@"%@%@%@",
        [s substringToIndex:lead], hit,
        [s substringFromIndex:(s.length - trail)]];
}

static NSAttributedString *TermiusZhTranslateAttributed(NSAttributedString *a) {
    if (!a || a.length == 0) return a;
    NSString *t = TermiusZhTranslate(a.string);
    if ([t isEqualToString:a.string]) return a;
    NSDictionary *attrs = [a attributesAtIndex:0 effectiveRange:NULL];
    return [[NSAttributedString alloc] initWithString:t attributes:attrs];
}

static void TermiusZhSwizzle(Class cls, SEL origSel, SEL newSel) {
    Method orig = class_getInstanceMethod(cls, origSel);
    Method repl = class_getInstanceMethod(cls, newSel);
    if (!orig || !repl) return;
    // If the class does not implement orig itself, add repl as orig first.
    if (class_addMethod(cls, origSel, method_getImplementation(repl),
                        method_getTypeEncoding(repl))) {
        class_replaceMethod(cls, newSel, method_getImplementation(orig),
                            method_getTypeEncoding(orig));
    } else {
        method_exchangeImplementations(orig, repl);
    }
}

static void TermiusZhSwizzleClass(Class cls, SEL origSel, SEL newSel) {
    Class meta = object_getClass((id)cls);
    Method orig = class_getClassMethod(cls, origSel);
    Method repl = class_getClassMethod(cls, newSel);
    if (!orig || !repl) return;
    if (class_addMethod(meta, origSel, method_getImplementation(repl),
                        method_getTypeEncoding(repl))) {
        class_replaceMethod(meta, newSel, method_getImplementation(orig),
                            method_getTypeEncoding(orig));
    } else {
        method_exchangeImplementations(orig, repl);
    }
}

// ---- NSBundle: covers NSLocalizedString / .strings tables ----
@interface NSBundle (TermiusZh)
- (NSString *)tc_localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName;
@end
@implementation NSBundle (TermiusZh)
- (NSString *)tc_localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName {
    NSString *orig = [self tc_localizedStringForKey:key value:value table:tableName];
    NSString *t = TermiusZhTranslate(orig);
    if (![t isEqualToString:orig]) return t;
    // Bundle returned the key unchanged (no localisation): try the key itself.
    return TermiusZhTranslate(key);
}
@end

@interface UILabel (TermiusZh)
- (void)tc_setText:(NSString *)text;
- (void)tc_setAttributedText:(NSAttributedString *)text;
@end
@implementation UILabel (TermiusZh)
- (void)tc_setText:(NSString *)text { [self tc_setText:TermiusZhTranslate(text)]; }
- (void)tc_setAttributedText:(NSAttributedString *)text {
    [self tc_setAttributedText:TermiusZhTranslateAttributed(text)];
}
@end

@interface UIButton (TermiusZh)
- (void)tc_setTitle:(NSString *)title forState:(UIControlState)state;
- (void)tc_setAttributedTitle:(NSAttributedString *)title forState:(UIControlState)state;
@end
@implementation UIButton (TermiusZh)
- (void)tc_setTitle:(NSString *)title forState:(UIControlState)state {
    [self tc_setTitle:TermiusZhTranslate(title) forState:state];
}
- (void)tc_setAttributedTitle:(NSAttributedString *)title forState:(UIControlState)state {
    [self tc_setAttributedTitle:TermiusZhTranslateAttributed(title) forState:state];
}
@end

// Placeholder only: UITextField.text (user/host input) is NOT hooked.
@interface UITextField (TermiusZh)
- (void)tc_setPlaceholder:(NSString *)placeholder;
@end
@implementation UITextField (TermiusZh)
- (void)tc_setPlaceholder:(NSString *)placeholder {
    [self tc_setPlaceholder:TermiusZhTranslate(placeholder)];
}
@end

@interface UISearchBar (TermiusZh)
- (void)tc_setPlaceholder:(NSString *)placeholder;
@end
@implementation UISearchBar (TermiusZh)
- (void)tc_setPlaceholder:(NSString *)placeholder {
    [self tc_setPlaceholder:TermiusZhTranslate(placeholder)];
}
@end

@interface UINavigationItem (TermiusZh)
- (void)tc_setTitle:(NSString *)title;
@end
@implementation UINavigationItem (TermiusZh)
- (void)tc_setTitle:(NSString *)title { [self tc_setTitle:TermiusZhTranslate(title)]; }
@end

@interface UITabBarItem (TermiusZh)
- (void)tc_setTitle:(NSString *)title;
@end
@implementation UITabBarItem (TermiusZh)
- (void)tc_setTitle:(NSString *)title { [self tc_setTitle:TermiusZhTranslate(title)]; }
@end

@interface UIBarButtonItem (TermiusZh)
- (void)tc_setTitle:(NSString *)title;
@end
@implementation UIBarButtonItem (TermiusZh)
- (void)tc_setTitle:(NSString *)title { [self tc_setTitle:TermiusZhTranslate(title)]; }
@end

@interface UISegmentedControl (TermiusZh)
- (void)tc_setTitle:(NSString *)title forSegmentAtIndex:(NSUInteger)segment;
@end
@implementation UISegmentedControl (TermiusZh)
- (void)tc_setTitle:(NSString *)title forSegmentAtIndex:(NSUInteger)segment {
    [self tc_setTitle:TermiusZhTranslate(title) forSegmentAtIndex:segment];
}
@end

@interface UIAlertController (TermiusZh)
- (void)tc_setTitle:(NSString *)title;
- (void)tc_setMessage:(NSString *)message;
@end
@implementation UIAlertController (TermiusZh)
- (void)tc_setTitle:(NSString *)title { [self tc_setTitle:TermiusZhTranslate(title)]; }
- (void)tc_setMessage:(NSString *)message { [self tc_setMessage:TermiusZhTranslate(message)]; }
@end

@interface UIAlertAction (TermiusZh)
+ (instancetype)tc_actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *action))handler;
@end
@implementation UIAlertAction (TermiusZh)
+ (instancetype)tc_actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *action))handler {
    return [self tc_actionWithTitle:TermiusZhTranslate(title) style:style handler:handler];
}
@end

// Re-apply to already-created views (covers dylib loaded after UI exists).
static void TermiusZhRefreshView(UIView *v) {
    if ([v isKindOfClass:[UILabel class]]) {
        UILabel *l = (UILabel *)v;
        if (l.text) [l setText:l.text];
        else if (l.attributedText) [l setAttributedText:l.attributedText];
    } else if ([v isKindOfClass:[UIButton class]]) {
        UIButton *b = (UIButton *)v;
        for (NSNumber *st in @[@(UIControlStateNormal), @(UIControlStateHighlighted),
                               @(UIControlStateDisabled), @(UIControlStateSelected)]) {
            NSString *t = [b titleForState:(UIControlState)st.unsignedIntegerValue];
            if (t) [b setTitle:t forState:(UIControlState)st.unsignedIntegerValue];
        }
    } else if ([v isKindOfClass:[UINavigationBar class]]) {
        for (UINavigationItem *item in ((UINavigationBar *)v).items) {
            if (item.title) [item setTitle:item.title];
        }
    }
    for (UIView *sub in v.subviews) TermiusZhRefreshView(sub);
}

static void TermiusZhRefreshAll(void) {
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        TermiusZhRefreshView(w);
    }
}

__attribute__((constructor))
static void TermiusZhInit(void) {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:kTermiusZhPairCount];
    for (unsigned long i = 0; i < kTermiusZhPairCount; i++) {
        NSString *en = [NSString stringWithUTF8String:kTermiusZhPairs[i].en];
        NSString *zh = [NSString stringWithUTF8String:kTermiusZhPairs[i].zh];
        if (en && zh) d[en] = zh;
    }
    gDict = [d copy];

    TermiusZhSwizzle([NSBundle class], @selector(localizedStringForKey:value:table:),
                     @selector(tc_localizedStringForKey:value:table:));
    TermiusZhSwizzle([UILabel class], @selector(setText:), @selector(tc_setText:));
    TermiusZhSwizzle([UILabel class], @selector(setAttributedText:), @selector(tc_setAttributedText:));
    TermiusZhSwizzle([UIButton class], @selector(setTitle:forState:), @selector(tc_setTitle:forState:));
    TermiusZhSwizzle([UIButton class], @selector(setAttributedTitle:forState:), @selector(tc_setAttributedTitle:forState:));
    TermiusZhSwizzle([UITextField class], @selector(setPlaceholder:), @selector(tc_setPlaceholder:));
    TermiusZhSwizzle([UISearchBar class], @selector(setPlaceholder:), @selector(tc_setPlaceholder:));
    TermiusZhSwizzle([UINavigationItem class], @selector(setTitle:), @selector(tc_setTitle:));
    TermiusZhSwizzle([UITabBarItem class], @selector(setTitle:), @selector(tc_setTitle:));
    TermiusZhSwizzle([UIBarButtonItem class], @selector(setTitle:), @selector(tc_setTitle:));
    TermiusZhSwizzle([UISegmentedControl class], @selector(setTitle:forSegmentAtIndex:), @selector(tc_setTitle:forSegmentAtIndex:));
    TermiusZhSwizzle([UIAlertController class], @selector(setTitle:), @selector(tc_setTitle:));
    TermiusZhSwizzle([UIAlertController class], @selector(setMessage:), @selector(tc_setMessage:));
    TermiusZhSwizzleClass([UIAlertAction class], @selector(actionWithTitle:style:handler:),
                          @selector(tc_actionWithTitle:style:handler:));

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *note) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ TermiusZhRefreshAll(); });
        }];
    NSLog(@"[TermiusChinese] loaded, %lu phrases", (unsigned long)kTermiusZhPairCount);
}
