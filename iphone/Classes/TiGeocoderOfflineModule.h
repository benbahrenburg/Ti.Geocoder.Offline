/**
 * Ti.Geocoder.Offline Project
 * Copyright (c) 2015 to present by Ben Bahrenburg. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiModule.h"

static NSString *const BXBFeaturesKey  = @"features";

@interface TiGeocoderOfflineModule : TiModule{
}

@property (nonatomic, strong, readwrite) NSMutableArray *countries;
@property (nonatomic, strong, readwrite) NSMutableDictionary *territories;
@property (nonatomic, strong, readwrite) NSMutableDictionary *subTerritories;

@end
