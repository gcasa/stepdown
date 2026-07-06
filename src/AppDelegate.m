#import "AppDelegate.h"
#import "StepDownDocument.h"

@implementation AppDelegate

- (id)init
{
    self = [super init];
    if (self != nil) {
        documents = [[NSMutableArray alloc] init];
        pendingOpenPaths = [[NSMutableArray alloc] init];
        finishedLaunching = NO;
    }
    return self;
}

- (void)dealloc
{
    [documents release];
    [pendingOpenPaths release];
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSImage *icon;
    NSUInteger i;

    icon = [NSImage imageNamed:@"StepDown"];
    if (icon != nil) {
        [NSApp setApplicationIconImage:icon];
    }

    [self buildMenu];
    finishedLaunching = YES;
    if ([pendingOpenPaths count] > 0) {
        for (i = 0; i < [pendingOpenPaths count]; i++) {
            [self openDocumentAtPath:[pendingOpenPaths objectAtIndex:i]];
        }
        [pendingOpenPaths removeAllObjects];
    } else {
        [self newDocument:nil];
    }
}

- (BOOL)application:(NSApplication *)application openFile:(NSString *)filename
{
    if (!finishedLaunching) {
        [pendingOpenPaths addObject:filename];
        return YES;
    }
    return [self openDocumentAtPath:filename];
}

- (void)application:(NSApplication *)application openFiles:(NSArray *)filenames
{
    NSUInteger i;
    BOOL openedAny;

    openedAny = NO;
    for (i = 0; i < [filenames count]; i++) {
        if ([self application:application openFile:[filenames objectAtIndex:i]]) {
            openedAny = YES;
        }
    }

    [application replyToOpenOrPrint:
        openedAny ? NSApplicationDelegateReplySuccess : NSApplicationDelegateReplyFailure];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application
{
    return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    NSArray *snapshot;
    NSUInteger i;
    StepDownDocument *document;

    snapshot = [NSArray arrayWithArray:documents];
    for (i = 0; i < [snapshot count]; i++) {
        document = [snapshot objectAtIndex:i];
        if (![document canCloseDocument]) {
            return NSTerminateCancel;
        }
    }
    return NSTerminateNow;
}

- (void)buildMenu
{
    NSMenu *mainMenu;
    NSMenu *appMenu;
    NSMenu *fileMenu;
    NSMenu *editMenu;
    NSMenuItem *appItem;
    NSMenuItem *fileItem;
    NSMenuItem *editItem;
    NSString *quitTitle;
    NSString *appName;

    appName = [[NSProcessInfo processInfo] processName];
    if (appName == nil || [appName length] == 0) {
        appName = @"StepDown";
    }

#ifdef __APPLE__
    mainMenu = [[[NSMenu alloc] initWithTitle:@"Main Menu"] autorelease];
#else
    mainMenu = [[[NSMenu alloc] initWithTitle:appName] autorelease];
#endif

    appItem = [[[NSMenuItem alloc] initWithTitle:appName action:NULL keyEquivalent:@""] autorelease];
    [mainMenu addItem:appItem];
    appMenu = [[[NSMenu alloc] initWithTitle:appName] autorelease];
    quitTitle = [NSString stringWithFormat:@"Quit %@", appName];
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

    editItem = [[[NSMenuItem alloc] initWithTitle:@"Edit" action:NULL keyEquivalent:@""] autorelease];
    [mainMenu addItem:editItem];
    editMenu = [[[NSMenu alloc] initWithTitle:@"Edit"] autorelease];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    [editItem setSubmenu:editMenu];

    [NSApp setMainMenu:mainMenu];
}

- (StepDownDocument *)activeDocument
{
    NSUInteger i;
    StepDownDocument *document;

    for (i = 0; i < [documents count]; i++) {
        document = [documents objectAtIndex:i];
        if ([document isKeyDocument]) {
            return document;
        }
    }

    if ([documents count] > 0) {
        return [documents lastObject];
    }
    return nil;
}

- (void)newDocument:(id)sender
{
    StepDownDocument *document;

    document = [[StepDownDocument alloc] initWithDelegate:self];
    [documents addObject:document];
    [document showWindow];
    [document release];
}

- (void)openDocument:(id)sender
{
    NSOpenPanel *panel;
    int result;
    NSArray *types;
    NSArray *filenames;
    NSUInteger i;

    panel = [NSOpenPanel openPanel];
    types = [NSArray arrayWithObjects:@"md", @"markdown", @"txt", nil];
    [panel setAllowsMultipleSelection:YES];
    result = [panel runModalForTypes:types];
    if (result != NSOKButton) {
        return;
    }

    filenames = [panel filenames];
    for (i = 0; i < [filenames count]; i++) {
        [self openDocumentAtPath:[filenames objectAtIndex:i]];
    }
}

- (BOOL)openDocumentAtPath:(NSString *)path
{
    StepDownDocument *document;
    NSError *error;

    error = nil;
    document = [[StepDownDocument alloc] initWithPath:path delegate:self error:&error];
    if (document == nil) {
        [self showError:@"Could not open the selected file."];
        return NO;
    }

    [documents addObject:document];
    [document showWindow];
    [document release];
    return YES;
}

- (void)saveDocument:(id)sender
{
    StepDownDocument *document;

    document = [self activeDocument];
    if (document != nil) {
        [document saveDocument:sender];
    }
}

- (void)saveDocumentAs:(id)sender
{
    StepDownDocument *document;

    document = [self activeDocument];
    if (document != nil) {
        [document saveDocumentAs:sender];
    }
}

- (void)documentDidClose:(id)document
{
    [documents removeObject:document];
}

- (void)showError:(NSString *)message
{
    NSAlert *alert;

    alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:message];
    [alert runModal];
}

@end
