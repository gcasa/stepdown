#ifndef MARKDOWN_RENDERER_H
#define MARKDOWN_RENDERER_H

#ifdef __APPLE__
#import <Cocoa/Cocoa.h>
#else
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#endif

@interface MarkdownRenderer : NSObject
+ (NSAttributedString *)attributedStringFromMarkdown:(NSString *)markdown;
+ (NSAttributedString *)attributedStringFromMarkdown:(NSString *)markdown baseURL:(NSURL *)baseURL;
+ (NSAttributedString *)attributedStringFromMarkdown:(NSString *)markdown baseURL:(NSURL *)baseURL maxImageWidth:(CGFloat)maxImageWidth;
@end

#endif
