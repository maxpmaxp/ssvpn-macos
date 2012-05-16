//
//  NSAttributedString+Hyperlink.m
//  Tunnelblick
//
//  Created by Lion User on 16/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSAttributedString+Hyperlink.h"

@implementation NSAttributedString(Hyperlink)
+(id) hyperlinkFromString:(NSString *)inString withURL:(NSURL *)aURL{
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:inString];
    NSRange range = NSMakeRange(0, [attrString length]);
    [attrString beginEditing];
    [attrString addAttribute:NSLinkAttributeName value: [aURL absoluteString] range: range];
    
    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
    
    [attrString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSSingleUnderlineStyle] range:range];
    
    
    [attrString endEditing];
    return [attrString autorelease];
}
@end
