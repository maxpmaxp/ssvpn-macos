/*
 * Copyright 2011 Jonathan Bullard
 *
 *  This file is part of Tunnelblick.
 *
 *  Tunnelblick is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License version 2
 *  as published by the Free Software Foundation.
 *
 *  Tunnelblick is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program (see the file COPYING included with this
 *  distribution); if not, write to the Free Software Foundation, Inc.,
 *  59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *  or see http://www.gnu.org/licenses/.
 */


#import <pthread.h>
#import "defines.h"
#import "StatusWindowController.h"
#import "MenuController.h"
#import "TBUserDefaults.h"
#import "helper.h"
#import "TrialVersionSecureStorage.h"


TBUserDefaults * gTbDefaults;         // Our preferences
extern NSArray * gRateUnits;
extern NSArray * gTotalUnits;

#define NUMBER_OF_STATUS_SCREEN_POSITIONS 64

static uint64_t statusScreenPositionsInUse = 0; // Must be 64 bits to match NUMBER_OF_STATUS_SCREEN_POSITIONS

static pthread_mutex_t statusScreenPositionsInUseMutex = PTHREAD_MUTEX_INITIALIZER;

@interface StatusWindowController()   // Private methods

-(CGFloat) adjustWidthsToLargerOf: (NSTextField *) tf1 and: (NSTextField *) tf2;

-(void) initialiseAnim;

-(void) setSizeAndPosition;

-(void) setUpUnits: (NSTextField *) tf1 cell: (NSTextFieldCell *) tfc1
               and: (NSTextField *) tf2 cell: (NSTextFieldCell *) tfc2
             array: (NSArray *) array;

-(NSTextFieldCell *) statusTFC;

-(void)              setTitle:        (NSString *) newTitle ofControl: (id) theControl;

@end

@implementation StatusWindowController

-(id) initWithDelegate: (id) theDelegate
{
    if (  ![super initWithWindowNibName:@"StatusWindow"]  ) {
        return nil;
    }
    
    [super setShouldCascadeWindows: NO];    // We always set the window's position
    
    name   = @"";
    status = @"";
    
    originalWidth = 0.0;
    currentWidth  = 0.0;
    
    trackingRectTag = 0;
    
    haveLoadedFromNib = FALSE;
    isOpen = FALSE;
    
    delegate = [theDelegate retain];
    
    trialVersionSecureStorage = [[TrialVersionSecureStorage alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver: self 
                                             selector: @selector(NSWindowWillCloseNotification:) 
                                                 name: NSWindowWillCloseNotification 
                                               object: nil];        
    
    return self;
}

-(void) startMouseTracking {
    if ( haveLoadedFromNib ) {
        if (  trackingRectTag == 0  ) {
            NSView * windowView = [[self window] contentView];
            NSRect trackingFrame = [windowView frame];
            trackingFrame.size.height += 1000.0;    // Include the title bar in the tracking rectangle (will be clipped)
            
            trackingRectTag = [windowView addTrackingRect: trackingFrame
                                                    owner: self
                                                 userData: nil
                                             assumeInside: NO];
        }
    }
}

-(void) stopMouseTracking {
    if (  trackingRectTag != 0  ) {
        [[[self window] contentView] removeTrackingRect: trackingRectTag];
        trackingRectTag = 0;
    }
}

-(void) restore
{
#ifdef TRIAL_VERSION_BUILD
    [bannerButton setEnabled:YES];
    [bannerButton setHidden:NO];
    [trialInfoTF setEnabled:YES];
    [trialInfoTF setHidden:NO];
    //[trialInfoTF setStringValue:[TrialVersionSecureStorage getNumberOfDaysTrialLast]];
#endif
    [cancelButton setEnabled: YES];
    [self startMouseTracking];
    [self setSizeAndPosition];
    [[self window] display];
    [self showWindow: self];
    [self fadeIn];
}

// Sets the frame for the window so the entire title (name of connection) is visible
// and the window is in the upper-right corner of the screen
-(void) setSizeAndPosition
{
    if (  originalWidth == 0.0  ) {
        originalWidth = [NSWindow minFrameWidthWithTitle: [[self window] title] styleMask: NSHUDWindowMask];
    }

    NSWindow * panel = [self window];
    NSRect panelFrame = [panel frame];
    
    // Adjust the width of the window to fit the complete title
    // But never make it smaller than the original window, or larger than will fit on the screen
    NSRect screen = [[[NSScreen screens] objectAtIndex: 0] visibleFrame];
    if (  currentWidth == 0.0  ) {
        currentWidth = [NSWindow minFrameWidthWithTitle: [panel title] styleMask: NSHUDWindowMask];
    }
    CGFloat newWidth = [NSWindow minFrameWidthWithTitle: name styleMask: NSHUDWindowMask];
    if (  newWidth < originalWidth  ) {
        newWidth = originalWidth;
    }
    CGFloat sizeChange = (CGFloat) newWidth - currentWidth;
    if (  sizeChange > 0.0  )  {
        if (  newWidth < (screen.size.width - 20.0)  ) {
            panelFrame.size.width = newWidth;
        } else {
            panelFrame.size.width = screen.size.width;
        }
    }
    
    // The panels are stacked top to bottom, right to left, like this:
    //
    //              10         5         0
    //              11         6         1
    //              12         7         2
    //              13         8         3
    //              14         9         4
    //
    // But the number in each column and row needs to be calculated.
    
    double verticalScreenSize = screen.size.height - 10.0;  // Size we can use on the screen
    NSUInteger screensWeCanStackVertically = verticalScreenSize / (panelFrame.size.height + 5);
    if (  screensWeCanStackVertically < 1  ) {
        screensWeCanStackVertically = 1;
    }
    
    double horizontalScreenSize = screen.size.width - 10.0;  // Size we can use on the screen
    NSUInteger screensWeCanStackHorizontally = horizontalScreenSize / (panelFrame.size.width + 5);
    if (  screensWeCanStackHorizontally < 1  ) {
        screensWeCanStackHorizontally = 1;
    }
    
    // Figure out what position number to try to get:
    NSUInteger startPositionNumber;
    if (   [[NSApp delegate] mouseIsInsideAnyView]
        && (   [gTbDefaults boolForKey: @"placeIconInStandardPositionInStatusBar"] )
        && ( ! [gTbDefaults boolForKey: @"doNotShowNotificationWindowOnMouseover"] )
        && ( ! [gTbDefaults boolForKey: @"doNotShowNotificationWindowBelowIconOnMouseover"] )  ) {
        
        MainIconView * view = [[NSApp delegate] ourMainIconView];
		NSPoint iconOrigin  = [[view window] convertBaseToScreen: NSMakePoint(0.0, 0.0)];
        
        for ( startPositionNumber=0; startPositionNumber<screensWeCanStackVertically * screensWeCanStackHorizontally; startPositionNumber+=screensWeCanStackVertically ) {
            double horizontalOffset = (panelFrame.size.width  + 5.0) * ((startPositionNumber / screensWeCanStackVertically) % screensWeCanStackHorizontally);
            double panelOriginX = screen.origin.x + screen.size.width - panelFrame.size.width  - 10.0 - horizontalOffset; 
            if (  panelOriginX < iconOrigin.x  ) {
                break;
            }
        }
        if (  startPositionNumber >= screensWeCanStackVertically * screensWeCanStackHorizontally  ) {
            startPositionNumber = 0;
        }
    } else {
        startPositionNumber = 0;
    }
    
    // Put the window in the lowest available position number equal to or greater than startPositionNumber, wrapping around
    // to position 0, 1, 2, etc. if we didn't start at position 0

    pthread_mutex_lock( &statusScreenPositionsInUseMutex );
    
    NSUInteger mask  = 1 << startPositionNumber;
    NSUInteger positionNumber;
    for (  positionNumber=startPositionNumber; positionNumber<NUMBER_OF_STATUS_SCREEN_POSITIONS; positionNumber++  ) {
        if (  (statusScreenPositionsInUse & mask) == 0  ) {
            break;
        }
        mask  = mask  << 1;
    }
    
    if (  positionNumber < NUMBER_OF_STATUS_SCREEN_POSITIONS  ) {
        statusScreenPositionsInUse = statusScreenPositionsInUse | mask;
        statusScreenPosition = positionNumber;
    } else {
        if (  startPositionNumber != 0  ) {
            mask  = 1;
            for (  positionNumber=0; positionNumber<startPositionNumber; positionNumber++  ) {
                if (  (statusScreenPositionsInUse & mask) == 0  ) {
                    break;
                }
                mask  = mask  << 1;
            }
            
            if (  positionNumber < startPositionNumber  ) {
                statusScreenPositionsInUse = statusScreenPositionsInUse | mask;
                statusScreenPosition = positionNumber;
            } else {
                statusScreenPosition = NSNotFound;
            }
        }
    }
    
    pthread_mutex_unlock( &statusScreenPositionsInUseMutex );

    // If all positions are filled, wrap back around to startPositionNumber and put it on top of another window but offset by (10, 10)
    double screenOverlapVerticalOffset;
    double screenOverlapHorizontalOffset;
    
    if (  statusScreenPosition == NSNotFound  ) {
        statusScreenPosition = startPositionNumber;
        screenOverlapVerticalOffset   = 10.0;
        screenOverlapHorizontalOffset = 10.0;
    } else {
        screenOverlapVerticalOffset   = 0.0;
        screenOverlapHorizontalOffset = 0.0;
    }
    
    double verticalOffset   = (panelFrame.size.height + 5.0) *  (positionNumber % screensWeCanStackVertically);
    double horizontalOffset = (panelFrame.size.width  + 5.0) * ((positionNumber / screensWeCanStackVertically) % screensWeCanStackHorizontally);
    
    double verticalPosition   = screen.origin.y + screen.size.height - panelFrame.size.height - 10.0 - verticalOffset   + screenOverlapVerticalOffset;
    double horizontalPosition = screen.origin.x + screen.size.width  - panelFrame.size.width  - 10.0 - horizontalOffset + screenOverlapHorizontalOffset;
    
    // Put the window in the upper-right corner of the screen but offset in X and Y by the position number    
    NSRect onScreenRect = NSMakeRect(horizontalPosition,
                              verticalPosition,
                              panelFrame.size.width,
                              panelFrame.size.height);
    
    [panel setFrame: onScreenRect display: YES];
    currentWidth = onScreenRect.size.width;
}

-(void) awakeFromNib
{
    [self setStatus: status forName: name connectedSince: connectedSince];

    [inTFC  setTitle: NSLocalizedString(@"In:", @"Window text")];
    [outTFC setTitle: NSLocalizedString(@"Out:", @"Window text")];
    [self adjustWidthsToLargerOf: inTF and: outTF];
    
    [self setUpUnits: inRateUnitsTF  cell: inRateUnitsTFC  and: outRateUnitsTF  cell: outRateUnitsTFC  array: gRateUnits];
    [self setUpUnits: inTotalUnitsTF cell: inTotalUnitsTFC and: outTotalUnitsTF cell: outTotalUnitsTFC array: gTotalUnits];
    
    if (  ! runningOnLeopardOrNewer()  ) {
        [[self window] setBackgroundColor: [NSColor blackColor]];
        [[self window] setAlphaValue: 0.77];
    }
    
    [self setSizeAndPosition];
    NSString * title = [NSString stringWithFormat:NSLocalizedString(@"SurfSafeVPN %@", @"Window title"), surfsafevpnVersion([NSBundle mainBundle])];
    
    [[self window] setTitle: title];
    
    NSView * windowView = [[self window] contentView];
    NSRect trackingFrame = [windowView frame];
    trackingFrame.size.height += 1000.0;    // Include the title bar in the tracking rectangle (will be clipped)
    
    trackingRectTag = [windowView addTrackingRect: trackingFrame
                                            owner: self
                                         userData: nil
                                     assumeInside: NO];
    


    
#ifdef TRIAL_VERSION_BUILD
    [bannerButton setEnabled:YES];
    [bannerButton setHidden:NO];
    [trialInfoTF setEnabled:YES];
    [trialInfoTF setHidden:NO];
    NSString *strTrialDasLef = [trialVersionSecureStorage getDaysLeftString];
    [trialInfoTF setStringValue: strTrialDasLef];
    NSLog(@"awakeFromNib %@, %@", NSStringFromRect([bannerButton bounds]), NSStringFromRect([trialInfoTF bounds]));
    [bannerButton addCursorRect:[bannerButton bounds] cursor:[NSCursor pointingHandCursor]];
    [trialInfoTF addCursorRect:[trialInfoTF bounds] cursor:[NSCursor pointingHandCursor]];
#endif
    
    [self showWindow: self];
    [self initialiseAnim];
    haveLoadedFromNib = TRUE;
    [self fadeIn];
}

// Sets the title for a control, shifting the origin of the control itself to the left, and the origin of other controls to the left or right to accomodate any change in width.
-(void) setTitle: (NSString *) newTitle ofControl: (id) theControl
{
    NSRect oldRect = [theControl frame];
    [theControl setTitle: newTitle];
    [theControl sizeToFit];
    
    NSRect newRect = [theControl frame];
    float widthChange = newRect.size.width - oldRect.size.width;
    NSRect oldPos;
    
    if (   [theControl isEqual: cancelButton]  ) {  // Shift the control itself left/right if necessary
        oldPos = [theControl frame];
        oldPos.origin.x = oldPos.origin.x - (widthChange/2);
        [theControl setFrame:oldPos];
    }
}

-(CGFloat) adjustWidthsToLargerOf: (NSTextField *) tf1 and: (NSTextField *) tf2 {
    
    CGFloat widthBeforeAdjustment = [tf1 frame].size.width;
    CGFloat adjustment;
    [tf1 sizeToFit];
    [tf2 sizeToFit];
    NSRect size1 = [tf1 frame];
    NSRect size2 = [tf2 frame];
    
    if (  size1.size.width > size2.size.width  ) {
        adjustment = size1.size.width - widthBeforeAdjustment; 
        size2.size.width = size1.size.width;
        [tf2 setFrame: size2];
    } else {
        adjustment = size2.size.width - widthBeforeAdjustment; 
        size1.size.width = size2.size.width;
        [tf1 setFrame: size1];
    }
    
    return adjustment;
}

-(void) setUpUnits: (NSTextField *) tf1 cell: (NSTextFieldCell *) tfc1
               and: (NSTextField *) tf2 cell: (NSTextFieldCell *) tfc2
             array: (NSArray *) array {
    
    // Find the maximum width of the units
    CGFloat maxWidth = 0.0;
    NSString * unitsName;
    NSEnumerator * e = [array objectEnumerator];
    while (  unitsName = [e nextObject]  ) {
        [tfc1 setTitle: unitsName];
        [tf1 sizeToFit];
        NSRect f = [tf1 frame];
        if (  f.size.width > maxWidth  ) {
            maxWidth = f.size.width;
        }
    }
    
    // Set the width of both text fields to the maximum
    NSRect f = [tf1 frame];
    f.size.width = maxWidth;
    [tf1 setFrame: f];
    f = [tf2 frame];
    f.size.width = maxWidth;
    [tf2 setFrame: f];
    
    // Set the text fields to the first entry in the array
    [tfc1 setTitle: [array objectAtIndex: 0]];
    [tfc2 setTitle: [array objectAtIndex: 0]];
}

-(void) initialiseAnim
{
    if (  theAnim == nil  ) {
        int i;
        // theAnim is an NSAnimation instance variable
        theAnim = [[NSAnimation alloc] initWithDuration:2.0
                                         animationCurve:NSAnimationLinear];
        [theAnim setFrameRate:7.0];
        [theAnim setDelegate:self];
        
        for (i=1; i<=[[[NSApp delegate] largeAnimImages] count]; i++) {
            NSAnimationProgress p = ((float)i)/((float)[[[NSApp delegate] largeAnimImages] count]);
            [theAnim addProgressMark:p];
        }
        [theAnim setAnimationBlockingMode:  NSAnimationNonblocking];
        [theAnim startAnimation];
    }
}

-(void)animationDidEnd:(NSAnimation*)animation
{
	if (   (![status isEqualToString:@"EXITING"])
        && (![status isEqualToString:@"CONNECTED"])) {
		[theAnim startAnimation];
	}
}

-(void)animation:(NSAnimation *)animation didReachProgressMark:(NSAnimationProgress)progress
{
	if (animation == theAnim) {
        [animationIV performSelectorOnMainThread:@selector(setImage:) withObject:[[[NSApp delegate] largeAnimImages] objectAtIndex:lround(progress * [[[NSApp delegate] largeAnimImages] count]) - 1] waitUntilDone:YES];
	}
}

-(void) fadeIn
{
    [self startMouseTracking];
    
	if (  ! isOpen  ) {
        NSWindow * window = [self window];
		
        [window makeKeyAndOrderFront: self];
        
        if (   [window respondsToSelector: @selector(animator)]
            && [[window animator] respondsToSelector: @selector(setAlphaValue:)]  ) {
            [[window animator] setAlphaValue: 1.0];
        }
		
        isOpen = YES;
    }
}

-(void) fadeOut
{
	if (  isOpen  ) {
        NSWindow * window = [self window];
        
        if (   [window respondsToSelector: @selector(animator)]
            && [[window animator] respondsToSelector: @selector(setAlphaValue:)]  ) {
            [[window animator] setAlphaValue:0.0];
        } else {
            [window close];
        }

		isOpen = NO;
        
        if (  statusScreenPosition != NSNotFound  ) {
            pthread_mutex_lock( &statusScreenPositionsInUseMutex );
            statusScreenPositionsInUse = statusScreenPositionsInUse & ( ~ (1 << statusScreenPosition));
            pthread_mutex_unlock( &statusScreenPositionsInUseMutex );
        }
        
        [NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval) 0.2   // Wait for the window to become transparent
                                         target: self
                                       selector: @selector(closeAfterFadeOutHandler:)
                                       userInfo: nil
                                        repeats: NO];
	}
    
    [self stopMouseTracking];
}

-(void) closeAfterFadeOutHandler: (NSTimer *) timer
{
	[self performSelectorOnMainThread: @selector(closeAfterFadeOut:) withObject: nil waitUntilDone: NO];
}

-(void) closeAfterFadeOut: (NSDictionary *) dict
{
    if ( [[self window] alphaValue] == 0.0 ) {
        [[self window] close];
    } else {
        [NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval) 0.2   // Wait for the window to become transparent
                                         target: self
                                       selector: @selector(closeAfterFadeOutHandler:)
                                       userInfo: nil
                                        repeats: NO];
    }

}

- (IBAction) cancelButtonWasClicked: sender
{
    [sender setEnabled: NO];
	[[NSApp delegate] statusWindowController: self
                          finishedWithChoice: (cancelButtonIsConnectButton ? statusWindowControllerConnectChoice : statusWindowControllerDisconnectChoice)
                              forDisplayName: [self name]];
}

- (IBAction)openBannerURL:(id)sender
{
    NSURL *myURL = [NSURL URLWithString:[trialVersionSecureStorage getPurchaseURL]];
    [[NSWorkspace sharedWorkspace] openURL:myURL];
}

- (void) dealloc
{
    [self stopMouseTracking];
    
    [[NSApp delegate] mouseExitedStatusWindow: self event: nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver: self]; 

    [cancelButton   release];
    [bannerButton   release];
    [trialInfoTF    release];
    
    
    [statusTFC      release];
    [animationIV    release];
    
    [name           release];
    [status         release];
    
    [theAnim        release];    
    [delegate       release];
    
    [trialVersionSecureStorage release];
    
	[super dealloc];
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"%@", [self class]];
}

-(NSTextFieldCell *) statusTFC
{
    return [[statusTFC retain] autorelease];
}

-(NSTextFieldCell *) configurationNameTFC
{
    return [[configurationNameTFC retain] autorelease];
}

-(void) setCancelButtonTitle: (NSString *) buttonName {
    if (  cancelButton  ) {
        [self setTitle: localizeNonLiteral(buttonName, @"Button") ofControl: cancelButton ];
        [cancelButton setEnabled: YES];
        cancelButtonIsConnectButton = [buttonName isEqualToString: @"Connect"];
    }
}

-(void) setStatus: (NSString *) theStatus forName: (NSString *) theName connectedSince: (NSString *) theTime
{
    [self setName: theName];
    [self setStatus: theStatus];
    if (  [theStatus isEqualToString: @"EXITING"]  ) {
        [self setConnectedSince: @""];
    } else {
        [self setConnectedSince: [NSString stringWithFormat: @" %@", theTime]];
    }
    
    [configurationNameTFC setStringValue: theName];
    [statusTFC            setStringValue: [NSString stringWithFormat: @"%@%@",
                                           localizeNonLiteral(theStatus, @"Connection status"),
                                           [self connectedSince]]];
    
    if (   [theStatus isEqualToString: @"EXITING"]  ) {
        [configurationNameTFC setTextColor: [NSColor redColor]];
        [statusTFC            setTextColor: [NSColor redColor]];
        [theAnim stopAnimation];
        [animationIV setImage: [[NSApp delegate] largeMainImage]];
        [self setCancelButtonTitle: @"Connect"];
        
    } else if (  [theStatus isEqualToString: @"CONNECTED"]  ) {
        [configurationNameTFC setTextColor: [NSColor greenColor]];
        [statusTFC            setTextColor: [NSColor greenColor]];
        [theAnim stopAnimation];
        [animationIV setImage: [[NSApp delegate] largeConnectedImage]];
        [self setCancelButtonTitle: @"Disconnect"];

    } else {
        [configurationNameTFC setTextColor: [NSColor yellowColor]];
        [statusTFC            setTextColor: [NSColor yellowColor]];
        [theAnim startAnimation];
        [self setCancelButtonTitle: @"Disconnect"];
    }
}

-(id) delegate
{
    return [[delegate retain] autorelease];
}

// *******************************************************************************************
// Getters & Setters

TBSYNTHESIZE_OBJECT(retain, NSString *, name,           setName)
TBSYNTHESIZE_OBJECT(retain, NSString *, status,         setStatus)
TBSYNTHESIZE_OBJECT(retain, NSString *, connectedSince, setConnectedSince)

-(BOOL) haveLoadedFromNib {
    return haveLoadedFromNib;
}

TBSYNTHESIZE_OBJECT_GET(retain, NSTextFieldCell *, inTFC)
TBSYNTHESIZE_OBJECT_GET(retain, NSTextFieldCell *, inRateTFC)
TBSYNTHESIZE_OBJECT_GET(retain, NSTextFieldCell *, inRateUnitsTFC)
TBSYNTHESIZE_OBJECT_GET(retain, NSTextFieldCell *, inTotalTFC)
TBSYNTHESIZE_OBJECT_GET(retain, NSTextFieldCell *, inTotalUnitsTFC)

TBSYNTHESIZE_OBJECT_GET(retain, NSTextFieldCell *, outTFC)
TBSYNTHESIZE_OBJECT_GET(retain, NSTextFieldCell *, outRateTFC)
TBSYNTHESIZE_OBJECT_GET(retain, NSTextFieldCell *, outRateUnitsTFC)
TBSYNTHESIZE_OBJECT_GET(retain, NSTextFieldCell *, outTotalTFC)
TBSYNTHESIZE_OBJECT_GET(retain, NSTextFieldCell *, outTotalUnitsTFC)

// Event Handlers
-(void) mouseEntered: (NSEvent *) theEvent {
    // Event handler; NOT on MainThread
    // Mouse entered the tracking area of the Tunnelblick icon

    [[NSApp delegate] mouseEnteredStatusWindow: self event: theEvent];
}

-(void) mouseExited: (NSEvent *) theEvent {
    // Event handler; NOT on MainThread
    // Mouse exited the tracking area of the Tunnelblick icon
    
    [[NSApp delegate] mouseExitedStatusWindow: self event: theEvent];
}

-(void) NSWindowWillCloseNotification: (NSNotification *) n {
    // Event handler; NOT on MainThread
    
    [[NSApp delegate] mouseExitedStatusWindow: self event: nil];
}
@end
