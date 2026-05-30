#import "MarkdownRenderer.h"

static NSFont *StepDownFont(NSString *family, CGFloat size, BOOL bold, BOOL italic)
{
    NSFontManager *manager;
    NSFont *base;
    NSFont *font;
    unsigned int traits;

    base = [NSFont fontWithName:family size:size];
    if (base == nil) {
        base = [NSFont systemFontOfSize:size];
    }

    traits = 0;
    if (bold) {
        traits |= NSBoldFontMask;
    }
    if (italic) {
        traits |= NSItalicFontMask;
    }

    manager = [NSFontManager sharedFontManager];
    font = [manager convertFont:base toHaveTrait:traits];
    if (font == nil) {
        font = base;
    }
    return font;
}

static NSDictionary *StepDownAttrs(NSFont *font, NSColor *color)
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
        font, NSFontAttributeName,
        color, NSForegroundColorAttributeName,
        nil];
}

static NSString *StepDownTrimLeft(NSString *string)
{
    NSUInteger i;
    NSUInteger length;
    unichar ch;

    length = [string length];
    i = 0;
    while (i < length) {
        ch = [string characterAtIndex:i];
        if (ch != ' ' && ch != '\t') {
            break;
        }
        i++;
    }
    return [string substringFromIndex:i];
}

static BOOL StepDownHasPrefix(NSString *string, NSString *prefix)
{
    if ([string length] < [prefix length]) {
        return NO;
    }
    return [string hasPrefix:prefix];
}

static BOOL StepDownIsRule(NSString *line)
{
    NSString *trimmed;
    NSUInteger i;
    NSUInteger count;
    NSUInteger length;
    unichar first;
    unichar ch;

    trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    length = [trimmed length];
    if (length < 3) {
        return NO;
    }

    first = [trimmed characterAtIndex:0];
    if (first != '-' && first != '*' && first != '_') {
        return NO;
    }

    count = 0;
    for (i = 0; i < length; i++) {
        ch = [trimmed characterAtIndex:i];
        if (ch == first) {
            count++;
        } else if (ch != ' ' && ch != '\t') {
            return NO;
        }
    }
    return count >= 3;
}

static BOOL StepDownOrderedMarkerLength(NSString *line, NSUInteger *markerLength)
{
    NSUInteger i;
    NSUInteger length;
    unichar ch;

    length = [line length];
    i = 0;
    while (i < length) {
        ch = [line characterAtIndex:i];
        if (ch < '0' || ch > '9') {
            break;
        }
        i++;
    }

    if (i == 0 || i + 1 >= length) {
        return NO;
    }
    if ([line characterAtIndex:i] != '.') {
        return NO;
    }
    ch = [line characterAtIndex:i + 1];
    if (ch != ' ' && ch != '\t') {
        return NO;
    }

    *markerLength = i + 2;
    return YES;
}

static NSString *StepDownStripLinkMarkup(NSString *text)
{
    NSMutableString *out;
    NSUInteger i;
    NSUInteger length;
    NSRange closeText;
    NSRange openURL;
    NSRange closeURL;
    NSString *label;

    out = [NSMutableString string];
    length = [text length];
    i = 0;

    while (i < length) {
        if ([text characterAtIndex:i] == '[') {
            closeText = [text rangeOfString:@"](" options:0 range:NSMakeRange(i, length - i)];
            if (closeText.location != NSNotFound) {
                openURL.location = closeText.location + 2;
                openURL.length = length - openURL.location;
                closeURL = [text rangeOfString:@")" options:0 range:openURL];
                if (closeURL.location != NSNotFound) {
                    label = [text substringWithRange:NSMakeRange(i + 1, closeText.location - i - 1)];
                    [out appendString:label];
                    i = closeURL.location + 1;
                    continue;
                }
            }
        }
        [out appendFormat:@"%C", [text characterAtIndex:i]];
        i++;
    }

    return out;
}

static NSMutableDictionary *StepDownImageCache(void)
{
    static NSMutableDictionary *cache = nil;

    if (cache == nil) {
        cache = [[NSMutableDictionary alloc] init];
    }
    return cache;
}

static NSImage *StepDownImageFromSource(NSString *source, NSURL *baseURL)
{
    NSURL *url;
    NSString *cacheKey;
    NSMutableDictionary *cache;
    NSString *trimmedSource;
    NSImage *image;

    trimmedSource = [source stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmedSource length] == 0) {
        return nil;
    }

    if ([trimmedSource hasPrefix:@"http://"] || [trimmedSource hasPrefix:@"https://"] || [trimmedSource hasPrefix:@"file://"]) {
        url = [NSURL URLWithString:trimmedSource];
    } else if (baseURL != nil) {
        url = [NSURL URLWithString:trimmedSource relativeToURL:baseURL];
    } else {
        url = [NSURL fileURLWithPath:trimmedSource];
    }

    if (url == nil) {
        return nil;
    }

    cacheKey = [url absoluteString];
    cache = StepDownImageCache();
    image = [cache objectForKey:cacheKey];
    if (image != nil) {
        return image;
    }

    {
        NSData *data;

        data = [NSData dataWithContentsOfURL:url];
        if (data != nil) {
            image = [[[NSImage alloc] initWithData:data] autorelease];
        }
    }
    if (image != nil) {
        [cache setObject:image forKey:cacheKey];
    }
    return image;
}

static BOOL StepDownExtractHTMLImageTag(NSString *text, NSUInteger startIndex, NSUInteger *endIndex, NSString **sourceOut, NSString **altOut)
{
    NSRange closeRange;
    NSRange tagRange;
    NSString *tag;
    NSString *lowerTag;
    NSUInteger srcLocation;
    NSUInteger altLocation;
    NSUInteger valueStart;
    NSUInteger valueEnd;
    NSString *source;
    NSString *altText;
    unichar ch;

    if (startIndex + 4 > [text length]) {
        return NO;
    }

    tagRange = NSMakeRange(startIndex, 4);
    if ([[[text substringWithRange:tagRange] lowercaseString] caseInsensitiveCompare:@"<img"] != NSOrderedSame) {
        return NO;
    }

    closeRange = [text rangeOfString:@">" options:0 range:NSMakeRange(startIndex, [text length] - startIndex)];
    if (closeRange.location == NSNotFound) {
        return NO;
    }

    tagRange = NSMakeRange(startIndex, closeRange.location - startIndex + 1);
    tag = [text substringWithRange:tagRange];
    lowerTag = [tag lowercaseString];

    srcLocation = [lowerTag rangeOfString:@"src"].location;
    if (srcLocation == NSNotFound) {
        return NO;
    }

    valueStart = srcLocation + 3;
    while (valueStart < [tag length]) {
        ch = [tag characterAtIndex:valueStart];
        if (ch != ' ' && ch != '\t') {
            break;
        }
        valueStart++;
    }
    if (valueStart >= [tag length] || [tag characterAtIndex:valueStart] != '=') {
        return NO;
    }
    valueStart++;
    while (valueStart < [tag length]) {
        ch = [tag characterAtIndex:valueStart];
        if (ch != ' ' && ch != '\t') {
            break;
        }
        valueStart++;
    }
    if (valueStart >= [tag length]) {
        return NO;
    }

    ch = [tag characterAtIndex:valueStart];
    if (ch == '"' || ch == '\'') {
        valueStart++;
        valueEnd = valueStart;
        while (valueEnd < [tag length] && [tag characterAtIndex:valueEnd] != ch) {
            valueEnd++;
        }
    } else {
        valueEnd = valueStart;
        while (valueEnd < [tag length]) {
            ch = [tag characterAtIndex:valueEnd];
            if (ch == ' ' || ch == '\t' || ch == '>') {
                break;
            }
            valueEnd++;
        }
    }

    if (valueEnd <= valueStart) {
        return NO;
    }

    source = [tag substringWithRange:NSMakeRange(valueStart, valueEnd - valueStart)];
    altText = @"";

    altLocation = [lowerTag rangeOfString:@"alt"].location;
    if (altLocation != NSNotFound) {
        valueStart = altLocation + 3;
        while (valueStart < [tag length]) {
            ch = [tag characterAtIndex:valueStart];
            if (ch != ' ' && ch != '\t') {
                break;
            }
            valueStart++;
        }
        if (valueStart < [tag length] && [tag characterAtIndex:valueStart] == '=') {
            valueStart++;
            while (valueStart < [tag length]) {
                ch = [tag characterAtIndex:valueStart];
                if (ch != ' ' && ch != '\t') {
                    break;
                }
                valueStart++;
            }
            if (valueStart < [tag length]) {
                ch = [tag characterAtIndex:valueStart];
                if (ch == '"' || ch == '\'') {
                    valueStart++;
                    valueEnd = valueStart;
                    while (valueEnd < [tag length] && [tag characterAtIndex:valueEnd] != ch) {
                        valueEnd++;
                    }
                } else {
                    valueEnd = valueStart;
                    while (valueEnd < [tag length]) {
                        ch = [tag characterAtIndex:valueEnd];
                        if (ch == ' ' || ch == '\t' || ch == '>') {
                            break;
                        }
                        valueEnd++;
                    }
                }
                if (valueEnd > valueStart) {
                    altText = [tag substringWithRange:NSMakeRange(valueStart, valueEnd - valueStart)];
                }
            }
        }
    }

    *endIndex = closeRange.location + 1;
    if (sourceOut != NULL) {
        *sourceOut = source;
    }
    if (altOut != NULL) {
        *altOut = altText;
    }
    return YES;
}

static void StepDownAppendImage(NSMutableAttributedString *target, NSString *source, NSString *altText, NSURL *baseURL, NSFont *baseFont, CGFloat maxImageWidth)
{
    NSImage *image;
    NSTextAttachment *attachment;
    NSTextAttachmentCell *cell;
    NSMutableAttributedString *piece;
    NSSize size;

    image = StepDownImageFromSource(source, baseURL);
    if (image == nil) {
        if ([altText length] > 0) {
            piece = [[[NSMutableAttributedString alloc] initWithString:altText attributes:StepDownAttrs(baseFont, [NSColor textColor])] autorelease];
            [target appendAttributedString:piece];
        }
        return;
    }

    size = [image size];
    if (maxImageWidth > 0.0 && size.width > maxImageWidth && size.width > 0.0) {
        size.height = size.height * (maxImageWidth / size.width);
        size.width = maxImageWidth;
        [image setSize:size];
    }

    attachment = [[[NSTextAttachment alloc] init] autorelease];
    cell = [[[NSTextAttachmentCell alloc] initImageCell:image] autorelease];
    [attachment setAttachmentCell:cell];
    piece = [[[NSMutableAttributedString alloc] initWithAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]] autorelease];
    [target appendAttributedString:piece];
}

static void StepDownAppendInline(NSMutableAttributedString *target, NSString *text, NSFont *baseFont, NSURL *baseURL, CGFloat maxImageWidth)
{
    NSUInteger i;
    NSUInteger length;
    NSRange close;
    NSUInteger imageEnd;
    NSString *chunk;
    NSString *plain;
    NSString *source;
    NSString *altText;
    NSFont *boldFont;
    NSFont *italicFont;
    NSFont *codeFont;
    NSColor *bodyColor;
    NSColor *codeColor;
    NSMutableAttributedString *piece;

    bodyColor = [NSColor textColor];
    codeColor = [NSColor colorWithCalibratedRed:0.58 green:0.12 blue:0.12 alpha:1.0];
    boldFont = StepDownFont([baseFont familyName], [baseFont pointSize], YES, NO);
    italicFont = StepDownFont([baseFont familyName], [baseFont pointSize], NO, YES);
    codeFont = [NSFont userFixedPitchFontOfSize:[baseFont pointSize] - 1.0];
    if (codeFont == nil) {
        codeFont = baseFont;
    }

    plain = StepDownStripLinkMarkup(text);
    length = [plain length];
    i = 0;
    while (i < length) {
        if ([plain characterAtIndex:i] == '<' && StepDownExtractHTMLImageTag(plain, i, &imageEnd, &source, &altText)) {
            StepDownAppendImage(target, source, altText, baseURL, baseFont, maxImageWidth);
            i = imageEnd;
            continue;
        }

        if ([plain characterAtIndex:i] == '`') {
            close = [plain rangeOfString:@"`" options:0 range:NSMakeRange(i + 1, length - i - 1)];
            if (close.location != NSNotFound) {
                chunk = [plain substringWithRange:NSMakeRange(i + 1, close.location - i - 1)];
                piece = [[[NSMutableAttributedString alloc] initWithString:chunk attributes:StepDownAttrs(codeFont, codeColor)] autorelease];
                [target appendAttributedString:piece];
                i = close.location + 1;
                continue;
            }
        }

        if (i + 1 < length && [plain characterAtIndex:i] == '*' && [plain characterAtIndex:i + 1] == '*') {
            close = [plain rangeOfString:@"**" options:0 range:NSMakeRange(i + 2, length - i - 2)];
            if (close.location != NSNotFound) {
                chunk = [plain substringWithRange:NSMakeRange(i + 2, close.location - i - 2)];
                piece = [[[NSMutableAttributedString alloc] initWithString:chunk attributes:StepDownAttrs(boldFont, bodyColor)] autorelease];
                [target appendAttributedString:piece];
                i = close.location + 2;
                continue;
            }
        }

        if ([plain characterAtIndex:i] == '*') {
            close = [plain rangeOfString:@"*" options:0 range:NSMakeRange(i + 1, length - i - 1)];
            if (close.location != NSNotFound) {
                chunk = [plain substringWithRange:NSMakeRange(i + 1, close.location - i - 1)];
                piece = [[[NSMutableAttributedString alloc] initWithString:chunk attributes:StepDownAttrs(italicFont, bodyColor)] autorelease];
                [target appendAttributedString:piece];
                i = close.location + 1;
                continue;
            }
        }

        chunk = [NSString stringWithFormat:@"%C", [plain characterAtIndex:i]];
        piece = [[[NSMutableAttributedString alloc] initWithString:chunk attributes:StepDownAttrs(baseFont, bodyColor)] autorelease];
        [target appendAttributedString:piece];
        i++;
    }
}

@implementation MarkdownRenderer

+ (NSAttributedString *)attributedStringFromMarkdown:(NSString *)markdown
{
    return [self attributedStringFromMarkdown:markdown baseURL:nil];
}

+ (NSAttributedString *)attributedStringFromMarkdown:(NSString *)markdown baseURL:(NSURL *)baseURL
{
    return [self attributedStringFromMarkdown:markdown baseURL:baseURL maxImageWidth:420.0];
}

+ (NSAttributedString *)attributedStringFromMarkdown:(NSString *)markdown baseURL:(NSURL *)baseURL maxImageWidth:(CGFloat)maxImageWidth
{
    NSMutableAttributedString *out;
    NSArray *lines;
    NSUInteger i;
    NSUInteger count;
    NSUInteger headingLevel;
    NSUInteger markerLength;
    BOOL inCode;
    NSString *line;
    NSString *trimmed;
    NSString *content;
    NSString *prefix;
    NSFont *bodyFont;
    NSFont *headingFont;
    NSFont *codeFont;
    NSColor *bodyColor;
    NSColor *mutedColor;
    NSMutableAttributedString *piece;

    if (markdown == nil) {
        markdown = @"";
    }

    out = [[[NSMutableAttributedString alloc] init] autorelease];
    lines = [markdown componentsSeparatedByString:@"\n"];
    bodyFont = [NSFont userFontOfSize:13.0];
    if (bodyFont == nil) {
        bodyFont = [NSFont systemFontOfSize:13.0];
    }
    codeFont = [NSFont userFixedPitchFontOfSize:12.0];
    if (codeFont == nil) {
        codeFont = bodyFont;
    }
    bodyColor = [NSColor textColor];
    mutedColor = [NSColor secondarySelectedControlColor];
    inCode = NO;
    count = [lines count];

    for (i = 0; i < count; i++) {
        line = [lines objectAtIndex:i];
        trimmed = StepDownTrimLeft(line);

        if (StepDownHasPrefix(trimmed, @"```")) {
            inCode = !inCode;
            continue;
        }

        if (inCode) {
            piece = [[[NSMutableAttributedString alloc] initWithString:
                [NSString stringWithFormat:@"%@\n", line]
                attributes:StepDownAttrs(codeFont, bodyColor)] autorelease];
            [out appendAttributedString:piece];
            continue;
        }

        if ([trimmed length] == 0) {
            piece = [[[NSMutableAttributedString alloc] initWithString:@"\n"
                attributes:StepDownAttrs(bodyFont, bodyColor)] autorelease];
            [out appendAttributedString:piece];
            continue;
        }

        if (StepDownIsRule(trimmed)) {
            piece = [[[NSMutableAttributedString alloc] initWithString:@"------------------------------\n"
                attributes:StepDownAttrs(codeFont, mutedColor)] autorelease];
            [out appendAttributedString:piece];
            continue;
        }

        headingLevel = 0;
        while (headingLevel < [trimmed length] &&
               headingLevel < 6 &&
               [trimmed characterAtIndex:headingLevel] == '#') {
            headingLevel++;
        }

        if (headingLevel > 0 &&
            headingLevel < [trimmed length] &&
            [trimmed characterAtIndex:headingLevel] == ' ') {
            content = [trimmed substringFromIndex:headingLevel + 1];
            headingFont = StepDownFont(@"Helvetica", 25.0 - (CGFloat)(headingLevel * 2), YES, NO);
            StepDownAppendInline(out, content, headingFont, baseURL, maxImageWidth);
            piece = [[[NSMutableAttributedString alloc] initWithString:@"\n"
                attributes:StepDownAttrs(bodyFont, bodyColor)] autorelease];
            [out appendAttributedString:piece];
            continue;
        }

        if (StepDownHasPrefix(trimmed, @"> ")) {
            content = [trimmed substringFromIndex:2];
            prefix = @"| ";
            piece = [[[NSMutableAttributedString alloc] initWithString:prefix
                attributes:StepDownAttrs(codeFont, mutedColor)] autorelease];
            [out appendAttributedString:piece];
            StepDownAppendInline(out, content, bodyFont, baseURL, maxImageWidth);
            piece = [[[NSMutableAttributedString alloc] initWithString:@"\n"
                attributes:StepDownAttrs(bodyFont, bodyColor)] autorelease];
            [out appendAttributedString:piece];
            continue;
        }

        if (StepDownHasPrefix(trimmed, @"- ") ||
            StepDownHasPrefix(trimmed, @"* ") ||
            StepDownHasPrefix(trimmed, @"+ ")) {
            content = [trimmed substringFromIndex:2];
            piece = [[[NSMutableAttributedString alloc] initWithString:@"  - "
                attributes:StepDownAttrs(bodyFont, bodyColor)] autorelease];
            [out appendAttributedString:piece];
            StepDownAppendInline(out, content, bodyFont, baseURL, maxImageWidth);
            piece = [[[NSMutableAttributedString alloc] initWithString:@"\n"
                attributes:StepDownAttrs(bodyFont, bodyColor)] autorelease];
            [out appendAttributedString:piece];
            continue;
        }

        if (StepDownOrderedMarkerLength(trimmed, &markerLength)) {
            content = [trimmed substringFromIndex:markerLength];
            piece = [[[NSMutableAttributedString alloc] initWithString:
                [NSString stringWithFormat:@"  %@ ", [trimmed substringToIndex:markerLength]]
                attributes:StepDownAttrs(bodyFont, bodyColor)] autorelease];
            [out appendAttributedString:piece];
            StepDownAppendInline(out, content, bodyFont, baseURL, maxImageWidth);
            piece = [[[NSMutableAttributedString alloc] initWithString:@"\n"
                attributes:StepDownAttrs(bodyFont, bodyColor)] autorelease];
            [out appendAttributedString:piece];
            continue;
        }

        StepDownAppendInline(out, trimmed, bodyFont, baseURL, maxImageWidth);
        piece = [[[NSMutableAttributedString alloc] initWithString:@"\n"
            attributes:StepDownAttrs(bodyFont, bodyColor)] autorelease];
        [out appendAttributedString:piece];
    }

    return out;
}

@end
