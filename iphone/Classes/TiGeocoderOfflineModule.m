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

-(NSString*)getNormalizedPath:(NSString*)source
{
    if ([source hasPrefix:@"file:/"]) {
        NSURL* url = [NSURL URLWithString:source];
        return [url path];
    }

    return source;
}

- (NSDictionary *)loadGeoJSON:(NSString*) path
{
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary *parsedJSON = [NSJSONSerialization JSONObjectWithData:data
                                                               options:NSJSONReadingAllowFragments
                                                                 error:&error];
    
    if (!error) {
        return [parsedJSON copy];
    } else {
        NSLog(@"[ERROR] Cannot parse JSON %@", [error localizedDescription]);
        [NSException raise:@"Cannot parse JSON." format:@"JSON URL - %@\nError:%@", path, parsedJSON];
    }
}

- (NSMutableDictionary *) buildResults:(NSDictionary *)dictionary
{

    NSString *identifier = [NSLocale localeIdentifierFromComponents: @{NSLocaleCountryCode: dictionary[@"id"]}];
    NSLocale * countryLocale = [NSLocale localeWithLocaleIdentifier:identifier];

    NSMutableDictionary* info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                              dictionary[@"id"],@"code",
                              dictionary[@"properties"][@"name"],@"name",
                              [countryLocale objectForKey: NSLocaleCountryCode],@"countryCode",
                                 nil];
    return info;
}

- (NSMutableDictionary *)findFromCoordinate:(CLLocationCoordinate2D)coordinate withInfo:(NSArray*) geoArray
{
    for (int i = 0; i < [geoArray count]; i++){
        
        NSDictionary *geoDict = [geoArray objectAtIndex:i];
        NSDictionary *geometry = [geoDict objectForKey:@"geometry"];
        NSString *geometryType = [geometry valueForKey:@"type"];
        NSArray *coordinates = [geometry objectForKey:@"coordinates"];
        
        /* Check the polygon type */
        if ([geometryType isEqualToString:@"Polygon"]) {
            
            /* Create the polygon */
            NSArray *polygonPoints  = [coordinates objectAtIndex:0];
            APPolygon *polygon = [APPolygon polygonWithPoints:polygonPoints];
            
            /* Cehck containment */
            if ([polygon containsLocation:coordinate]) {
                return [self buildResults:geoDict];
            }
            
            /* Loop through all sub-polygons and make the checks */
        } else if([geometryType isEqualToString:@"MultiPolygon"]){
            for (int j = 0; j < [coordinates count]; j++){
                
                NSArray *polygonPoints = [[coordinates objectAtIndex:j] objectAtIndex:0];
                APPolygon *polygon = [APPolygon polygonWithPoints:polygonPoints];
                
                if([polygon containsLocation:coordinate]) {
                    return [self buildResults:geoDict];
                }
            }
        }
    }
    return nil;
}


#pragma Public APIs

-(void)registerCountryInfo:(id)args
{
    ENSURE_SINGLE_ARG(args,NSDictionary);
    ENSURE_UI_THREAD(registerCountryInfo,args);
    
    if(![args objectForKey:@"url"]){
        NSLog(@"[ERROR] url is required");
        return;
    }
    
    NSString* countryPath = [args objectForKey:@"url"];
    NSURL *countryUrl = [TiUtils  toURL:[self getNormalizedPath:countryPath] proxy:self];
    NSString*  countryFilePath = [countryUrl path];
    NSLog(@"[DEBUG] url %@", countryFilePath);

    if(![[NSFileManager defaultManager] fileExistsAtPath:countryFilePath])
    {
        NSLog(@"[ERROR] Invalid url location %@",countryFilePath);
        return;
    }

    if (!_countries) {
        _countries = [self loadGeoJSON:countryFilePath][BXBFeaturesKey];
    }
    
    NSLog(@"[DEBUG] %d countries loaded", [_countries count]);
    
}

-(void)registerTerritoryInfoForCountryCode:(id)args
{
    ENSURE_SINGLE_ARG(args,NSDictionary);
    ENSURE_UI_THREAD(registerTerritoryInfoForCountryCode,args);

    if(![args objectForKey:@"countryCode"]){
        NSLog(@"[ERROR] countryCode is required");
        return;
    }
    
    if(![args objectForKey:@"url"]){
        NSLog(@"[ERROR] url is required");
        return;
    }
    
    NSString* territoryPath = [args objectForKey:@"url"];
    NSURL *territoryUrl = [TiUtils  toURL:[self getNormalizedPath:territoryPath] proxy:self];
    NSString* territoryFilePath = [territoryUrl path];
    NSLog(@"[DEBUG] url %@", territoryFilePath);
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:territoryFilePath])
    {
        NSLog(@"[ERROR] Invalid url location %@",territoryFilePath);
        return;
    }
    
    NSString *countryCode = [args objectForKey:@"countryCode"];
    
    if(_territories == nil){
        _territories = [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [self loadGeoJSON:territoryFilePath][BXBFeaturesKey],countryCode,nil];
    }else{
        [_territories setObject:[self loadGeoJSON:territoryFilePath][BXBFeaturesKey] forKey:countryCode];
    }
    
    NSLog(@"[DEBUG] Territories for %@ have been loaded", countryCode);
    NSLog(@"[DEBUG] %d Territories loaded", [_territories count]);
}

-(void)registerSubTerritoryInfoForTerritoryCode:(id)args
{
    ENSURE_SINGLE_ARG(args,NSDictionary);
    ENSURE_UI_THREAD(registerSubTerritoryInfoForTerritoryCode,args);
    
    if(![args objectForKey:@"territoryCode"]){
        NSLog(@"[ERROR] territoryCode is required");
        return;
    }
    
    if(![args objectForKey:@"url"]){
        NSLog(@"[ERROR] url is required");
        return;
    }
    
    NSString* subTerritoryPath = [args objectForKey:@"url"];
    NSURL *subTerritoryUrl = [TiUtils  toURL:[self getNormalizedPath:subTerritoryPath] proxy:self];
    NSString* subTerritoryFilePath = [subTerritoryUrl path];
    NSLog(@"[DEBUG] url %@", subTerritoryFilePath);
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:subTerritoryFilePath])
    {
        NSLog(@"[ERROR] Invalid url location %@",subTerritoryFilePath);
        return;
    }
    
    NSString *territoryCode = [args objectForKey:@"territoryCode"];
    
    if(_subTerritories == nil){
        _subTerritories = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        [self loadGeoJSON:subTerritoryFilePath][BXBFeaturesKey],territoryCode,nil];
    }else{
        [_subTerritories setObject:[self loadGeoJSON:subTerritoryFilePath][BXBFeaturesKey] forKey:territoryCode];
    }
    
    NSLog(@"[DEBUG] SubTerritories for %@ have been loaded", territoryCode);
    NSLog(@"[DEBUG] %d SubTerritories loaded", [_subTerritories count]);
}


-(void)unregisterAll:(id)unused
{
    [_countries removeAllObjects];
    [_territories removeAllObjects];
}

-(void)reverseGeocoder:(id)args
{
    ENSURE_ARG_COUNT(args,3);
    CGFloat lat = [TiUtils floatValue:[args objectAtIndex:0]];
    CGFloat lon = [TiUtils floatValue:[args objectAtIndex:1]];
    KrollCallback *callback = [args objectAtIndex:2];
    ENSURE_TYPE(callback,KrollCallback);
    ENSURE_UI_THREAD(reverseGeocoder,args);
    
    if (!_countries) {
        NSLog(@"[ERROR] Call register before calling reverseGeocoder");
        return;
    }
    
    if(callback == nil ){
        NSLog(@"[ERROR] callback is required");
        return;
    }
    
    CLLocationCoordinate2D coordinates = CLLocationCoordinate2DMake(lat, lon);
    
    NSMutableDictionary *countrySearchResults = [self findFromCoordinate:coordinates withInfo:_countries];
    NSMutableDictionary * territoryResults;
    NSMutableDictionary * subTerritoryResults;
    
    BOOL countrySuccess = (countrySearchResults != nil);
    BOOL territorySuccess = YES;
    BOOL subTerritorySuccess = YES;
    
    if(countrySuccess){
        NSString *countryCode = countrySearchResults[@"countryCode"];
        NSLog(@"[DEBUG] countryCode %@", countryCode);
        if([_territories objectForKey:countryCode]!= nil){
            territoryResults = [self findFromCoordinate:coordinates withInfo:[_territories objectForKey:countryCode]];
            territorySuccess = (territoryResults != nil);
            if(territorySuccess){
                NSString *territoryCode = countrySearchResults[@"code"];
                NSLog(@"[DEBUG] territoryCode %@", territoryCode);
                if([_subTerritories objectForKey:territoryCode]!= nil){
                    subTerritoryResults = [self findFromCoordinate:coordinates withInfo:[_subTerritories objectForKey:territoryCode]];
                    subTerritorySuccess = (subTerritoryResults != nil);
                }
            }
        }
    }
    
    BOOL success = countrySuccess && territorySuccess && subTerritorySuccess;
    
    NSMutableDictionary *event =[[NSMutableDictionary alloc] init];
    [event setValue:NUMBOOL(success) forKey:@"success"];
    [event setValue:[NSNumber numberWithFloat: lat] forKey:@"latitude"];
    [event setValue:[NSNumber numberWithFloat: lon] forKey:@"longitude"];
    
    if(countrySuccess){
        if(countrySearchResults!=nil){
            [event setObject:countrySearchResults forKey:@"country"];
        }
    }

    if(territorySuccess){
        if(territoryResults!=nil){
            [event setObject:territoryResults forKey:@"territory"];
        }
    }
    
    if(subTerritorySuccess){
        if(subTerritoryResults!=nil){
            [event setObject:subTerritoryResults forKey:@"subterritory"];
        }
    }
    
    [self _fireEventToListener:@"completed" withObject:event listener:callback thisObject:nil];
}

@end
