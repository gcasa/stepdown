#import "StepDownDocument.h"
#import "MarkdownRenderer.h"
#import <float.h>

static NSString *StepDownInitialMarkdown(void)
{
    return @"# Untitled\n\nStart writing Markdown on the left. The preview updates on the right.\n\n- Create notes\n- Open existing `.md` files\n- Save your work\n";
}

@implementation StepDownDocument

- (id)initWithDelegate:(id)aDelegate
{
    self = [super init];
    if (self != nil) {
        delegate = aDelegate;
        window = nil;
        editorView = nil;
        previewView = nil;
        currentPath = nil;
        dirty = NO;
        [self buildWindow];
        [[editorView textStorage] setAttributedString:
            [[[NSAttributedString alloc] initWithString:StepDownInitialMarkdown()] autorelease]];
        [self applyEditorThemeToCurrentText];
        [self updateWindowTitle];
        [self updatePreview];
    }
    return self;
}

- (id)initWithPath:(NSString *)path delegate:(id)aDelegate error:(NSError **)error
{
    NSString *contents;

    self = [super init];
    if (self == nil) {
        return nil;
    }

    contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error];
    if (contents == nil) {
        [self release];
        return nil;
    }

    delegate = aDelegate;
    window = nil;
    editorView = nil;
    previewView = nil;
    currentPath = [path copy];
    dirty = NO;
    [self buildWindow];
    [[editorView textStorage] setAttributedString:
        [[[NSAttributedString alloc] initWithString:contents] autorelease]];
    [self applyEditorThemeToCurrentText];
    [self updateWindowTitle];
    [self updatePreview];
    return self;
}

- (void)dealloc
{
    [window setDelegate:nil];
    [editorView setDelegate:nil];
    [window release];
    [editorView release];
    [previewView release];
    [currentPath release];
    [super dealloc];
}

- (void)buildWindow
{
    NSRect frame;
    NSUInteger style;
    NSSplitView *splitView;
    NSScrollView *editorScroll;
    NSScrollView *previewScroll;
    NSFont *editorFont;

    frame = NSMakeRect(100, 100, 1000, 650);
    style = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask;
    window = [[NSWindow alloc] initWithContentRect:frame
        styleMask:style
        backing:NSBackingStoreBuffered
        defer:NO];
    [window setReleasedWhenClosed:NO];
    [window setTitle:@"StepDown"];
    [window setDelegate:self];

    splitView = [[[NSSplitView alloc] initWithFrame:[[window contentView] bounds]] autorelease];
    [splitView setVertical:YES];
    [splitView setDividerStyle:NSSplitViewDividerStyleThin];
    [splitView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [splitView setDelegate:self];

    editorView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 500, 650)];
    previewView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 500, 650)];

    editorFont = [NSFont userFixedPitchFontOfSize:13.0];
    if (editorFont == nil) {
        editorFont = [NSFont systemFontOfSize:13.0];
    }
    [editorView setFont:editorFont];
    [editorView setRichText:NO];
    [editorView setUsesFontPanel:NO];
    [editorView setDelegate:self];
    [editorView setTextColor:[NSColor whiteColor]];
    [editorView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.12 alpha:1.0]];
    [editorView setInsertionPointColor:[NSColor whiteColor]];

    [previewView setEditable:NO];
    [previewView setSelectable:YES];
    [previewView setRichText:YES];
    [previewView setImportsGraphics:YES];
    [previewView setUsesFontPanel:NO];
    [previewView setBackgroundColor:[NSColor whiteColor]];
    [previewView setTextColor:[NSColor blackColor]];

    editorScroll = [self scrollViewForTextView:editorView];
    previewScroll = [self scrollViewForTextView:previewView];
    [splitView addSubview:editorScroll];
    [splitView addSubview:previewScroll];

    [[window contentView] addSubview:splitView];
}

- (NSScrollView *)scrollViewForTextView:(NSTextView *)textView
{
    NSScrollView *scrollView;

    scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)] autorelease];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:NO];
    [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [textView setMinSize:NSMakeSize(0, 0)];
    [textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [textView setVerticallyResizable:YES];
    [textView setHorizontallyResizable:NO];
    [textView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [[textView textContainer] setContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [[textView textContainer] setWidthTracksTextView:YES];
    [scrollView setDocumentView:textView];
    return scrollView;
}

- (void)showWindow
{
    [window makeKeyAndOrderFront:nil];
}

- (BOOL)isKeyDocument
{
    return [window isKeyWindow] || [window isMainWindow];
}

- (NSString *)currentPath
{
    return currentPath;
}

- (void)applyEditorThemeToCurrentText
{
    NSRange fullRange;
    NSMutableDictionary *typingAttrs;

    [editorView setTextColor:[NSColor whiteColor]];
    [editorView setInsertionPointColor:[NSColor whiteColor]];

    fullRange = NSMakeRange(0, [[editorView string] length]);
    if (fullRange.length > 0) {
        [[editorView textStorage] addAttribute:NSForegroundColorAttributeName
            value:[NSColor whiteColor]
            range:fullRange];
    }

    typingAttrs = [NSMutableDictionary dictionaryWithDictionary:[editorView typingAttributes]];
    if ([editorView font] != nil) {
        [typingAttrs setObject:[editorView font] forKey:NSFontAttributeName];
    }
    [typingAttrs setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
    [editorView setTypingAttributes:typingAttrs];
}

- (void)textDidChange:(NSNotification *)notification
{
    dirty = YES;
    [self updateWindowTitle];
    [self updatePreview];
}

- (void)updateWindowTitle
{
    NSString *name;
    NSString *title;

    if (currentPath != nil) {
        name = [currentPath lastPathComponent];
    } else {
        name = @"Untitled";
    }
    title = dirty ? [NSString stringWithFormat:@"%@ - Edited", name] : name;
    [window setTitle:[NSString stringWithFormat:@"StepDown - %@", title]];
}

- (BOOL)saveDocument:(id)sender
{
    if (currentPath == nil) {
        return [self saveDocumentAs:sender];
    }
    return [self writeToPath:currentPath];
}

- (BOOL)saveDocumentAs:(id)sender
{
    NSSavePanel *panel;
    int result;
    NSString *path;

    panel = [NSSavePanel savePanel];
    [panel setRequiredFileType:@"md"];
    result = [panel runModal];
    if (result != NSOKButton) {
        return NO;
    }

    path = [panel filename];
    if ([self writeToPath:path]) {
        [currentPath release];
        currentPath = [path copy];
        [self updateWindowTitle];
        [self updatePreview];
        return YES;
    }
    return NO;
}

- (BOOL)writeToPath:(NSString *)path
{
    NSString *text;
    NSError *error;
    BOOL ok;

    text = [editorView string];
    error = nil;
    ok = [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!ok) {
        [self showError:@"Could not save the document."];
        return NO;
    }
    dirty = NO;
    [self updateWindowTitle];
    return YES;
}

- (BOOL)canCloseDocument
{
    NSAlert *alert;
    int result;

    if (!dirty) {
        return YES;
    }

    alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:@"Save changes before closing?"];
    [alert setInformativeText:@"This document has changes that have not been saved."];
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Discard"];
    result = [alert runModal];

    if (result == NSAlertFirstButtonReturn) {
        return [self saveDocument:nil];
    }
    if (result == NSAlertSecondButtonReturn) {
        return NO;
    }
    dirty = NO;
    return YES;
}

- (BOOL)windowShouldClose:(id)sender
{
    return [self canCloseDocument];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [self retain];
    if (delegate != nil && [delegate respondsToSelector:@selector(documentDidClose:)]) {
        [delegate performSelector:@selector(documentDidClose:) withObject:self];
    }
    [self autorelease];
}

- (void)showError:(NSString *)message
{
    NSAlert *alert;

    alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:message];
    [alert runModal];
}

- (void)updatePreview
{
    NSAttributedString *rendered;
    NSURL *baseURL;
    NSString *basePath;
    CGFloat previewWidth;

    if (currentPath != nil) {
        basePath = [currentPath stringByDeletingLastPathComponent];
    } else {
        basePath = [[NSFileManager defaultManager] currentDirectoryPath];
    }
    baseURL = [NSURL fileURLWithPath:basePath];
    previewWidth = NSWidth([previewView bounds]);
    if (previewWidth > 24.0) {
        previewWidth -= 24.0;
    }
    if (previewWidth < 200.0) {
        previewWidth = 200.0;
    }

    rendered = [MarkdownRenderer attributedStringFromMarkdown:[editorView string] baseURL:baseURL maxImageWidth:previewWidth];
    [[previewView textStorage] setAttributedString:rendered];
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
    [self updatePreview];
}

@end
