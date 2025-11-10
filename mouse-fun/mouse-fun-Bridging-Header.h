//
//  mouse-fun-Bridging-Header.h
//  mouse-fun
//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#ifndef mouse_fun_Bridging_Header_h
#define mouse_fun_Bridging_Header_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// Private APIs for cursor control from background app
// These are undocumented APIs used to control cursor when app is not in foreground
typedef int CGSConnectionID;
typedef int CGSWindowID;

// Function to get the default connection
int _CGSDefaultConnection(void);

// Function to set connection properties
CGError CGSSetConnectionProperty(CGSConnectionID cid, CGSConnectionID targetCID, CFStringRef key, CFTypeRef value);

// Function to get connection properties
CFTypeRef CGSCopyConnectionProperty(CGSConnectionID cid, CGSConnectionID targetCID, CFStringRef key);

// Additional private cursor APIs for complete hiding
CGError CGSHideCursor(CGSConnectionID cid);
CGError CGSShowCursor(CGSConnectionID cid);
CGError CGSObscureCursor(CGSConnectionID cid);
CGError CGSRevealCursor(CGSConnectionID cid);

// Set cursor scale (can be used to make cursor extremely small)
CGError CGSSetCursorScale(CGSConnectionID cid, float scale);

// Get current cursor data
CGError CGSGetCurrentCursorLocation(CGSConnectionID cid, CGPoint *point);

#endif /* mouse_fun_Bridging_Header_h */