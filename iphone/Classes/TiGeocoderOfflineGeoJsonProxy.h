/**
 * Ti.Geocoder.Offline Project
 * Copyright (c) 2015 to present by Ben Bahrenburg. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#import "TiProxy.h"

@interface TiGeocoderOfflineGeoJsonProxy : TiProxy {
    @private
    BOOL _debug;
}

@property (nonatomic, strong, readwrite) NSMutableArray *places;

@end
