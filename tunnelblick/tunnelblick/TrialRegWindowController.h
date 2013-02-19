//
//  TrialRegWindowController.h
//  Tunnelblick
//
//  Created by Valik Plunk on 11/02/2013.
//
//

#import <Cocoa/Cocoa.h>

@interface TrialRegWindowController : NSWindowController
{
    
    IBOutlet NSTextField    * email;
    IBOutlet NSTextField    * firstName;
    IBOutlet NSTextField    * lastName;
    
    IBOutlet NSButton           * cancelButton;
    IBOutlet NSButton           * OKButton;
    
    
    IBOutlet NSButton           * alreadyHaveVPNIdCheckbox;
    
    id                            delegate;
}

-(id)           initWithDelegate:       (id)            theDelegate;
-(void)         redisplay;

-(IBAction)     cancelButtonWasClicked: (id)            sender;
-(IBAction)     OKButtonWasClicked:     (id)            sender;
-(IBAction)     alreadyHaveVPNIdWasClicked:(id)         sender;

-(NSTextField *)email;
-(NSTextField *)firstName;
-(NSTextField *)lastName;
-(BOOL) alreadyHaveVPNID;

-(id)           delegate;

@end
