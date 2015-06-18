/**
 * Ti.Geocoder.Offline Project
 * Copyright (c) 2015 to present by Ben Bahrenburg. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiGeocoderOfflineModule.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"
#import "APPolygon.h"

@implementation TiGeocoderOfflineModule

#pragma mark Internal

// this is generated for your module, please do not change it
-(id)moduleGUID
{
	return @"149b1004-c13c-4b48-9a41-4b5d78d44bfd";
}

// this is generated for your module, please do not change it
-(NSString*)moduleId
{
	return @"ti.geocoder.offline";
}

#pragma mark Lifecycle

-(void)startup
{
	[super startup];
}

-(void)shutdown:(id)sender
{
	[super shutdown:sender];
}

#pragma mark Cleanup

#pragma mark Internal Memory Management

-(void)didReceiveMemoryWarning:(NSNotification*)notification
{
	[super didReceiveMemoryWarning:notification];
}

@end
