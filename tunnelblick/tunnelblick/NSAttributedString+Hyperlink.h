//
//  NSAttributedString+Hyperlink.h
//  Tunnelblick
//
//  Created by Lion User on 16/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSAttributedString (Hyperlink)
+(id) hyperlinkFromString:(NSString *)inString withURL: (NSURL*)aURL;
@end
