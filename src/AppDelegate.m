#import "AppDelegate.h"
#import "MarkdownRenderer.h"
#import <float.h>

static NSString *StepDownInitialMarkdown(void)
{
    return @"# Untitled\n\nStart writing Markdown on the left. The preview updates on the right.\n\n- Create notes\n- Open existing `.md` files\n- Save your work\n";
}

@implementation AppDelegate

- (id)init
{
    self = [super init];
    if (self != nil) {
        window = nil;
        editorView = nil;
        previewView = nil;
        currentPath = nil;
        dirty = NO;
    }
    return self;
}

- (void)dealloc
{
    [currentPath release];
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSImage *icon;

    icon = [NSImage imageNamed:@"StepDown"];
    if (icon != nil) {
        [NSApp setApplicationIconImage:icon];
    }

    [self buildMenu];
    [self buildWindow];
    [[editorView textStorage] setAttributedString:
        [[[NSAttributedString alloc] initWithString:StepDownInitialMarkdown()] autorelease]];
    [self updatePreview];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application
{
    return YES;
}

- (void)buildMenu
{
    NSMenu *mainMenu;
    NSMenu *appMenu;
    NSMenu *fileMenu;
    NSMenuItem *appItem;
    NSMenuItem *fileItem;
    NSString *quitTitle;

    mainMenu = [[[NSMenu alloc] initWithTitle:@"Main Menu"] autorelease];

    appItem = [[[NSMenuItem alloc] initWithTitle:@"StepDown" action:NULL keyEquivalent:@""] autorelease];
    [mainMenu addItem:appItem];
    appMenu = [[[NSMenu alloc] initWithTitle:@"StepDown"] autorelease];
    quitTitle = @"Quit StepDown";
    [appMenu addItemWithTitle:quitTitle action:@selector(terminate:) keyEquivalent:@"q"];
    [appItem setSubmenu:appMenu];

    fileItem = [[[NSMenuItem alloc] initWithTitle:@"File" action:NULL keyEquivalent:@""] autorelease];
    [mainMenu addItem:fileItem];
    fileMenu = [[[NSMenu alloc] initWithTitle:@"File"] autorelease];
    [fileMenu addItemWithTitle:@"New" action:@selector(newDocument:) keyEquivalent:@"n"];
    [fileMenu addItemWithTitle:@"Open..." action:@selector(openDocument:) keyEquivalent:@"o"];
    [fileMenu addItemWithTitle:@"Save" action:@selector(saveDocument:) keyEquivalent:@"s"];
    [fileMenu addItemWithTitle:@"Save As..." action:@selector(saveDocumentAs:) keyEquivalent:@"S"];
    [fileItem setSubmenu:fileMenu];

    [NSApp setMainMenu:mainMenu];
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
    [window setTitle:@"StepDown"];
    [window setDelegate:self];

    splitView = [[[NSSplitView alloc] initWithFrame:[[window contentView] bounds]] autorelease];
    [splitView setVertical:YES];
    [splitView setDividerStyle:NSSplitViewDividerStyleThin];
    [splitView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

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

    [previewView setEditable:NO];
    [previewView setSelectable:YES];
    [previewView setRichText:YES];
    [previewView setUsesFontPanel:NO];

    editorScroll = [self scrollViewForTextView:editorView];
    previewScroll = [self scrollViewForTextView:previewView];
    [splitView addSubview:editorScroll];
    [splitView addSubview:previewScroll];

    [[window contentView] addSubview:splitView];
    [window makeKeyAndOrderFront:nil];
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

- (BOOL)confirmDiscardIfNeeded
{
    int result;
    NSAlert *alert;

    if (!dirty) {
        return YES;
    }

    alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:@"Discard unsaved changes?"];
    [alert setInformativeText:@"The current document has changes that have not been saved."];
    [alert addButtonWithTitle:@"Discard"];
    [alert addButtonWithTitle:@"Cancel"];
    result = [alert runModal];
    return result == NSAlertFirstButtonReturn;
}

- (void)newDocument:(id)sender
{
    if (![self confirmDiscardIfNeeded]) {
        return;
    }

    [currentPath release];
    currentPath = nil;
    [[editorView textStorage] setAttributedString:
        [[[NSAttributedString alloc] initWithString:@"# Untitled\n\n"] autorelease]];
    dirty = NO;
    [self updateWindowTitle];
    [self updatePreview];
}

- (void)openDocument:(id)sender
{
    NSOpenPanel *panel;
    int result;
    NSString *path;
    NSString *contents;
    NSError *error;
    NSArray *types;

    if (![self confirmDiscardIfNeeded]) {
        return;
    }

    panel = [NSOpenPanel openPanel];
    types = [NSArray arrayWithObjects:@"md", @"markdown", @"txt", nil];
    [panel setAllowsMultipleSelection:NO];
    result = [panel runModalForTypes:types];
    if (result != NSOKButton) {
        return;
    }

    path = [panel filename];
    error = nil;
    contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (contents == nil) {
        [self showError:@"Could not open the selected file."];
        return;
    }

    [currentPath release];
    currentPath = [path copy];
    [[editorView textStorage] setAttributedString:
        [[[NSAttributedString alloc] initWithString:contents] autorelease]];
    dirty = NO;
    [self updateWindowTitle];
    [self updatePreview];
}

- (void)saveDocument:(id)sender
{
    if (currentPath == nil) {
        [self saveDocumentAs:sender];
        return;
    }
    [self writeToPath:currentPath];
}

- (void)saveDocumentAs:(id)sender
{
    NSSavePanel *panel;
    int result;
    NSString *path;

    panel = [NSSavePanel savePanel];
    [panel setRequiredFileType:@"md"];
    result = [panel runModal];
    if (result != NSOKButton) {
        return;
    }

    path = [panel filename];
    if ([self writeToPath:path]) {
        [currentPath release];
        currentPath = [path copy];
        [self updateWindowTitle];
    }
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

    rendered = [MarkdownRenderer attributedStringFromMarkdown:[editorView string]];
    [[previewView textStorage] setAttributedString:rendered];
}

@end
