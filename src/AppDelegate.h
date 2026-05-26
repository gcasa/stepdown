#ifndef APP_DELEGATE_H
#define APP_DELEGATE_H

#ifdef __APPLE__
#import <Cocoa/Cocoa.h>
#else
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#endif

@interface AppDelegate : NSObject
{
    NSWindow *window;
    NSTextView *editorView;
    NSTextView *previewView;
    NSString *currentPath;
    NSString *pendingOpenPath;
    BOOL dirty;
}

- (void)newDocument:(id)sender;
- (void)openDocument:(id)sender;
- (void)saveDocument:(id)sender;
- (void)saveDocumentAs:(id)sender;
- (BOOL)openDocumentAtPath:(NSString *)path confirmingDiscard:(BOOL)confirm;
- (void)updatePreview;

@end

#endif
