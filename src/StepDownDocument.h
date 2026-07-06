#ifndef STEP_DOWN_DOCUMENT_H
#define STEP_DOWN_DOCUMENT_H

#ifdef __APPLE__
#import <Cocoa/Cocoa.h>
#else
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#endif

@interface StepDownDocument : NSObject
{
    id delegate;
    NSWindow *window;
    NSTextView *editorView;
    NSTextView *previewView;
    NSString *currentPath;
    BOOL dirty;
}

- (id)initWithDelegate:(id)aDelegate;
- (id)initWithPath:(NSString *)path delegate:(id)aDelegate error:(NSError **)error;
- (void)showWindow;
- (BOOL)isKeyDocument;
- (BOOL)saveDocument:(id)sender;
- (BOOL)saveDocumentAs:(id)sender;
- (BOOL)canCloseDocument;
- (NSString *)currentPath;

@end

#endif
