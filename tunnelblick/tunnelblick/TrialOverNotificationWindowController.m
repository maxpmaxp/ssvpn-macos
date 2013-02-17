//
//  TrialOverNotificationWindowController.m
//  Tunnelblick
//
//  Created by Valik Plunk on 15/02/2013.
//
//

#import "TrialOverNotificationWindowController.h"

@interface TrialOverNotificationWindowController ()

@end

@implementation TrialOverNotificationWindowController


-(id)           initWithDelegate:       (id)            theDelegate
{
    if (  ![super initWithWindowNibName:@"TrialOverNotificationWindow"]  ) {
        return nil;
    }
    
    delegate = [theDelegate retain];
    return self;
}

-(void) awakeFromNib
{
//    [[self window] setTitle: @"SurfSafeVPN: Trial Registration Required"];
    
    
    [OKButton setTitle: @"OK"];
    [self redisplay];
}

-(void) redisplay
{
    [OKButton setEnabled: YES];
    [huperLinkButton setEnabled:YES];
    
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:@"Click here"];
    NSRange range = NSMakeRange(0, [string length]);
    
    [string addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSSingleUnderlineStyle] range:range];
    [string addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
    
    [buyNowTextField setAttributedStringValue:string];
    [string release];

    [[self window] center];
    [[self window] display];
    [self showWindow: self];
    [NSApp activateIgnoringOtherApps: YES];
    [[self window] makeKeyAndOrderFront: self];
}

- (void) dealloc
{
    [buyNowTextField               release];
    [huperLinkButton               release];
    [OKButton               release];
    [delegate               release];
    
	[super dealloc];
}

-(IBAction)     huperLinkButtonWasClicked: (id)            sender
{
    NSString * strPurchaseUrl = [[delegate trialVersionSecureStorage] getPurchaseURL];
    NSURL *url = [[NSURL alloc] initWithString:strPurchaseUrl];
    [[NSWorkspace sharedWorkspace] openURL:url];
    
    //exit after click
    [self OKButtonWasClicked:sender];
}

-(IBAction)     OKButtonWasClicked:     (id)            sender
{
    [huperLinkButton setEnabled: NO];
    [OKButton setEnabled: NO];
    [NSApp stopModal];
}

@end
