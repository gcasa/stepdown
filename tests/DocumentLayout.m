#import "StepDownDocument.h"
#import <math.h>

@interface StepDownDocument (LayoutTests)

- (void)updatePreview;

@end

static void Check(BOOL condition, NSString *message)
{
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static CGFloat ScrollProgress(NSTextView *view)
{
    NSClipView *clip = [[view enclosingScrollView] contentView];
    CGFloat range = NSHeight([view frame]) - NSHeight([clip bounds]);
    return range > 0 ? NSMinY([clip bounds]) / range : 0;
}

static void CheckScroll(NSTextView *source, NSTextView *target, CGFloat progress)
{
    NSClipView *clip = [[source enclosingScrollView] contentView];
    CGFloat range = NSHeight([source frame]) - NSHeight([clip bounds]);
    [clip scrollToPoint:NSMakePoint(0, range * progress)];
    [[source enclosingScrollView] reflectScrolledClipView:clip];
    Check(fabs(ScrollProgress(source) - ScrollProgress(target)) < 0.005,
        @"Both panes must track the same scroll progress");
}

static void CheckWrapping(NSTextView *view)
{
    NSClipView *clip = [[view enclosingScrollView] contentView];
    NSLayoutManager *layout = [view layoutManager];
    NSTextContainer *container = [view textContainer];
    NSRect used;
    [layout ensureLayoutForTextContainer:container];
    used = [layout usedRectForTextContainer:container];
    Check(fabs(NSWidth([view frame]) - NSWidth([clip bounds])) < 1,
        @"Text view must fit its viewport");
    Check(NSMaxX(used) <= [container containerSize].width + 1,
        @"Text must wrap within the text container");
    Check(NSHeight(used) > NSHeight([clip bounds]), @"Long document must scroll vertically");
}

int main(void)
{
    CREATE_AUTORELEASE_POOL(pool);
    StepDownDocument *document;
    NSTextView *editor;
    NSTextView *preview;
    NSWindow *window;
    NSSplitView *split;
    NSMutableString *text;
    NSUInteger i;

    [NSApplication sharedApplication];
    document = [[StepDownDocument alloc] initWithDelegate:nil];
    editor = [document valueForKey:@"editorView"];
    preview = [document valueForKey:@"previewView"];
    window = [document valueForKey:@"window"];
    split = (NSSplitView *)[[editor enclosingScrollView] superview];
    text = [NSMutableString string];
    for (i = 0; i < 100; i++) {
        [text appendString:@"# Heading\nA long paragraph with **bold text** and words that should wrap across several lines in either pane when the window is narrow. More words to ensure that there is plenty of text to wrap.\n\n"];
    }
    [editor setString:text];
    [document updatePreview];
    CheckWrapping(editor);
    CheckWrapping(preview);
    CheckScroll(editor, preview, 0.5);
    CheckScroll(preview, editor, 0.25);
    CheckScroll(editor, preview, 1.0);
    CheckScroll(preview, editor, 0.0);
    [window setContentSize:NSMakeSize(600, 400)];
    [split adjustSubviews];
    CheckWrapping(editor);
    CheckWrapping(preview);
    CheckScroll(preview, editor, 0.6);
    [document updatePreview];
    Check(fabs(ScrollProgress(editor) - ScrollProgress(preview)) < 0.005,
        @"Preview updates must preserve synchronization");
    [split setPosition:180 ofDividerAtIndex:0];
    CheckWrapping(editor);
    CheckWrapping(preview);
    CheckScroll(editor, preview, 0.8);
    [editor setString:@"Short document"];
    [document updatePreview];
    Check(ScrollProgress(editor) == 0 && ScrollProgress(preview) == 0,
        @"Short documents must return both panes to the top");
    RELEASE(document);
    NSLog(@"PASS: wrapping, resize, bidirectional scrolling, preview refresh, short documents");
    RELEASE(pool);
    return 0;
}
