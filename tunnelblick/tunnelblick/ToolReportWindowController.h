//
//  ToolReportWindowController.h
//  Tunnelblick
//
//  Created by Valik Plunk on 06/02/2013.
//
//

#import <Cocoa/Cocoa.h>

@interface ToolReportWindowController : NSWindowController <NSWindowDelegate>
{
    IBOutlet NSButton           * cancelButton;
    IBOutlet NSButton           * submitButton;
    
    IBOutlet NSTextField        * vpnid;
    IBOutlet NSTextField        * email;
    IBOutlet NSTextView        * ticketDescription;
    IBOutlet NSTextView        * mainLogText;
    
    IBOutlet NSTextFieldCell    * vpnidTFC;
    IBOutlet NSTextFieldCell    * emailTFC;
    
    IBOutlet NSButton           * agreeToSendLogsCheckbox;
    
    IBOutlet NSWindow           * toolReportWindow;

    id                            delegate;
}

-(IBAction)     cancelButtonWasClicked: (id)            sender;
-(IBAction)     submitButtonWasClicked:    (id)            sender;
-(IBAction)     agreeToSendChecked:     (id)            sender;


@end
