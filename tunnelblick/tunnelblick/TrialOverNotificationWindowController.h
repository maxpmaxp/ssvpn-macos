//
//  TrialOverNotificationWindowController.h
//  Tunnelblick
//
//  Created by Valik Plunk on 15/02/2013.
//
//

#import <Cocoa/Cocoa.h>

@interface TrialOverNotificationWindowController : NSWindowController
{
    IBOutlet NSButton           * OKButton;
    
    IBOutlet NSTextFieldCell    * buyNowTextField;
    
    IBOutlet NSButton           * huperLinkButton;
    
    id                            delegate;
}
-(id)           initWithDelegate:       (id)            theDelegate;
-(void)         redisplay;

-(IBAction)     huperLinkButtonWasClicked: (id)            sender;
-(IBAction)     OKButtonWasClicked:     (id)            sender;

@end
