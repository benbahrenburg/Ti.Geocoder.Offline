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
    
    if(_territoriesInputs == nil){
        _territoriesInputs = [NSMutableDictionary dictionaryWithObjectsAndKeys:territoryFilePath,countryCode,nil];
    }else{
        [_territoriesInputs setValue:territoryFilePath forKey:countryCode];
    }
    
    NSLog(@"[DEBUG] Territories for %@ have been loaded", countryCode);
    NSLog(@"[DEBUG] %d Territories Cached", [_territoriesInputs count]);
}

-(void) cacheTerritory:(NSString*)code
{
    //If we don't have the info needed to load return
    if([_territoriesInputs objectForKey:code] == nil){
        return;
    }
    //If we are already cached, return
    if([_territoriesCache objectForKey:code] != nil)
    {
        return;
    }
    
    NSString *path = [_territoriesInputs objectForKey:code];
    
    if(_territoriesCache == nil){
        _territoriesCache = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                              [self loadGeoJSON:path][BXBFeaturesKey],code,nil];
    }else{
        [_territoriesCache setObject:[self loadGeoJSON:path][BXBFeaturesKey] forKey:code];
    }
    
    NSLog(@"[DEBUG] Territories for %@ have been loaded", code);
    NSLog(@"[DEBUG] %d Territories cached", [_territoriesCache count]);
}

-(void) cacheSubTerritory:(NSString*)code
{
    //If we don't have the info needed to load return
    if([_subTerritoriesInputs objectForKey:code] == nil){
        return;
    }
    //If we are already cached, return
    if([_territoriesCache objectForKey:code] != nil)
    {
        return;
    }
    
    NSString *path = [_subTerritoriesInputs objectForKey:code];
    
    if(_subTerritoriesCache == nil){
        _subTerritoriesCache = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                             [self loadGeoJSON:path][BXBFeaturesKey],code,nil];
    }else{
        [_subTerritoriesCache setObject:[self loadGeoJSON:path][BXBFeaturesKey] forKey:code];
    }
    
    NSLog(@"[DEBUG] Sub Territories for %@ have been loaded", code);
    NSLog(@"[DEBUG] %d Sub Territories cached", [_subTerritoriesCache count]);
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
    
    if(_subTerritoriesInputs == nil){
        _subTerritoriesInputs = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        [self loadGeoJSON:subTerritoryFilePath][BXBFeaturesKey],territoryCode,nil];
    }else{
        [_subTerritoriesInputs setObject:[self loadGeoJSON:subTerritoryFilePath][BXBFeaturesKey] forKey:territoryCode];
    }
    
    NSLog(@"[DEBUG] SubTerritories for %@ have been loaded", territoryCode);
    NSLog(@"[DEBUG] %d SubTerritories loaded", [_subTerritoriesInputs count]);
}


-(void)clearCache:(id)unused
{
    [_territoriesCache removeAllObjects];
    [_subTerritoriesCache removeAllObjects];
}

-(void)unregisterAll:(id)unused
{
    [_countries removeAllObjects];
    [_territoriesCache removeAllObjects];
    [_territoriesInputs removeAllObjects];
    [_subTerritoriesInputs removeAllObjects];
    [_subTerritoriesCache removeAllObjects];
}

-(BOOL) determineSuccess:(BOOL)hasInfo withSuccess:(BOOL)success
{
    if(hasInfo == NO){
        return YES;
    }
    return success;
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
    
    BOOL hasTerritory = NO;
    BOOL hasSubTerritory = NO;
    
    if(countrySearchResults != nil){
        NSString *countryCode = countrySearchResults[@"countryCode"];
        NSLog(@"[DEBUG] countryCode %@", countryCode);
        if([_territoriesInputs objectForKey:countryCode]!= nil){
            hasTerritory = YES;
            [self cacheTerritory:countryCode];

            territoryResults = [self findFromCoordinate:coordinates withInfo:[_territoriesCache objectForKey:countryCode]];
            if(territoryResults != nil){
                
                NSString *territoryCode = countrySearchResults[@"code"];
                NSLog(@"[DEBUG] territoryCode %@", territoryCode);
                if([_subTerritoriesInputs objectForKey:territoryCode]!= nil){
                    hasSubTerritory = YES;
                    [self cacheSubTerritory:territoryCode];
                    subTerritoryResults = [self findFromCoordinate:coordinates withInfo:[_subTerritoriesCache objectForKey:territoryCode]];
                }
                
            }
        }
    }
    
    BOOL success = (countrySearchResults != nil) &&
                    [self determineSuccess:hasTerritory withSuccess:(territoryResults != nil)] &&
                    [self determineSuccess:hasSubTerritory withSuccess:(subTerritoryResults != nil)];
    
    NSMutableDictionary *event =[[NSMutableDictionary alloc] init];
    [event setValue:NUMBOOL(success) forKey:@"success"];
    
    [event setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                      [NSNumber numberWithFloat: lat],@"latitude",
                      [NSNumber numberWithFloat: lon],@"longitude",
                      NUMBOOL(YES),@"country",
                      NUMBOOL(hasTerritory),@"territory",
                      NUMBOOL(hasSubTerritory),@"subTerritory",
                      nil] forKey:@"mapInfo"];
    
    if(countrySearchResults!=nil){
        [event setObject:countrySearchResults forKey:@"country"];
    }else{
        [event setObject:[NSNull null] forKey:@"country"];
    }

    if(territoryResults!=nil){
        [event setObject:territoryResults forKey:@"territory"];
    }else{
        [event setObject:[NSNull null] forKey:@"territory"];
    }
    
    if(subTerritoryResults!=nil){
        [event setObject:subTerritoryResults forKey:@"subTerritory"];
    }else{
        [event setObject:[NSNull null] forKey:@"subTerritory"];
    }
    
    [self _fireEventToListener:@"completed" withObject:event listener:callback thisObject:nil];
}

@end
