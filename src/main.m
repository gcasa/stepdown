#ifdef __APPLE__
#import <Cocoa/Cocoa.h>
#else
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#endif

#import "AppDelegate.h"

//int main(int argc, const char **argv)

int main()
{
    //CREATE_AUTORELEASE_POOL (pool);

    NSAutoreleasePool *pool;
    AppDelegate *delegate;

    pool = [[NSAutoreleasePool alloc] init];
    [NSApplication sharedApplication];

    delegate = [[AppDelegate alloc] init];
    [NSApp setDelegate: delegate];
    [NSApp run];

    [delegate release];
    [pool release];
    return 0;

    //RELEASE (pool);
    //return NSApplicationMain (argc, argv); 
}
