/**
 * Ti.Geocoder.Offline Project
 * Copyright (c) 2015 to present by Ben Bahrenburg. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiGeocoderOfflineGeoJsonProxy.h"
#import "TiUtils.h"
#import "APPolygon.h"

@implementation TiGeocoderOfflineGeoJsonProxy


-(void)_initWithProperties:(NSDictionary *)properties
{
    _debug = [TiUtils boolValue:@"debug" properties:properties def:NO];
    if(![properties objectForKey:@"filePath"]){
        NSLog(@"[ERROR] url is required");
    }else{
        NSString *url = [TiUtils stringValue:@"filePath" properties:properties];
        [self loadPlaces:url];
    }
    
    [super _initWithProperties:properties];
}


-(NSString*)getNormalizedPath:(NSString*)source
{
    if ([source hasPrefix:@"file:/"]) {
        NSURL* url = [NSURL URLWithString:source];
        return [url path];
    }
    
    return source;
}

-(void)loadPlaces:(NSString*)url
{
    NSURL *fileUrl = [TiUtils  toURL:[self getNormalizedPath:url] proxy:self];
    NSString* filePath = [fileUrl path];
    
    if(_debug){
        NSLog(@"[DEBUG] url %@", filePath);
    }
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:filePath])
    {
        NSLog(@"[ERROR] Invalid url location %@",filePath);
        return;
    }

    if (_places) {
        [_places removeAllObjects];
        _places = nil;
    }
    
    _places = [[self loadGeoJSON:filePath][@"features"] mutableCopy];
    
    if(_debug){
        NSLog(@"[DEBUG] %d places loaded", [_places count]);
    }
}

- (NSDictionary *)loadGeoJSON:(NSString*) path
{
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary *parsedJSON = [NSJSONSerialization JSONObjectWithData:data
                                                               options:NSJSONReadingAllowFragments
                                                                 error:&error];
    
    if (!error) {
        return parsedJSON;
    } else {
        NSLog(@"[ERROR] Cannot parse JSON %@", [error localizedDescription]);
        [NSException raise:@"Cannot parse JSON." format:@"JSON URL - %@\nError:%@", path, parsedJSON];
    }
}

- (NSMutableDictionary *) buildResults:(NSDictionary *)dictionary
{
    if(_debug){
        NSLog(@"[DEBUG] packaging results %@",dictionary);
    }
 
    NSMutableDictionary *info =[[NSMutableDictionary alloc] init];
    
    if(dictionary[@"id"]){
        [info setObject:dictionary[@"id"] forKey:@"id"];
    }

    if(dictionary[@"properties"]){
        [info setObject:dictionary[@"properties"] forKey:@"properties"];
    }
    
    if(!dictionary[@"properties"] && !dictionary[@"id"])
    {
        [info setObject:dictionary forKey:@"raw"];
    }
    
    return info;
}

// GeoJSON comes is oftenly poorly formatted
-(BOOL) isRecordValid:(NSDictionary*)geoDict
{
    if(geoDict == nil){
        return NO;
    }
    
    if(!geoDict[@"geometry"]){
        return NO;
    }
    
    if(![[geoDict objectForKey:@"geometry"] isKindOfClass:[NSDictionary class]])
    {
        return NO;
    }
    
    if([geoDict objectForKey:@"geometry"] == nil){
        return NO;
    }
    
    NSDictionary *geometry = [geoDict objectForKey:@"geometry"];
    if(!geometry[@"type"]){
        return NO;
    }
    
    if(!geometry[@"coordinates"]){
        return NO;
    }
 
    if(![[geometry objectForKey:@"coordinates"] isKindOfClass:[NSArray class]])
    {
        return NO;
    }

    if([geometry objectForKey:@"coordinates"] == nil){
        return NO;
    }
    
    return YES;
}

- (NSMutableDictionary *)findFromCoordinate:(CLLocationCoordinate2D)coordinate withInfo:(NSArray*) geoArray
{
    for (int i = 0; i < [geoArray count]; i++){
        
        NSDictionary *geoDict = [geoArray objectAtIndex:i];
        
        BOOL isValid = [self isRecordValid:geoDict];
        
        if((!isValid) && (_debug)){
            NSLog(@"[DEBUG] record %d contains invalid formatting and will be skipped", i);
        }
    
        if(isValid){
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
        
    }
    return nil;
}

-(void)registerFile:(id)args
{
    ENSURE_SINGLE_ARG(args,NSDictionary);
    ENSURE_UI_THREAD(registerFile,args);
    
    if(![args objectForKey:@"url"]){
        NSLog(@"[ERROR] url is required");
        return;
    }
    
    NSString* url = [args objectForKey:@"url"];

    if(_debug){
        NSLog(@"[DEBUG] url %@", url);
    }
    
    [self loadPlaces:url];
}

-(void)findByPosition:(id)args
{
    ENSURE_ARG_COUNT(args,3);
    CGFloat lat = [TiUtils floatValue:[args objectAtIndex:0]];
    CGFloat lon = [TiUtils floatValue:[args objectAtIndex:1]];
    KrollCallback *callback = [args objectAtIndex:2];
    ENSURE_TYPE(callback,KrollCallback);
    ENSURE_UI_THREAD(findByPosition,args);
    
    if (!_places) {
        NSLog(@"[ERROR] Call register before calling findByPosition");
        return;
    }
    
    if(callback == nil ){
        NSLog(@"[ERROR] callback is required");
        return;
    }
    
    CLLocationCoordinate2D coordinates = CLLocationCoordinate2DMake(lat, lon);
    
    NSMutableDictionary *searchResults = [self findFromCoordinate:coordinates withInfo:_places];
    
    BOOL success = (searchResults != nil) && ([[searchResults allKeys] count] > 0);
    
    NSMutableDictionary *event =[[NSMutableDictionary alloc] init];
    [event setValue:NUMBOOL(success) forKey:@"success"];
    
    [event setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithFloat: lat],@"latitude",
                          [NSNumber numberWithFloat: lon],@"longitude",
                          nil] forKey:@"mapInfo"];
    
    if(success){
        if(_debug){
            NSLog(@"[DEBUG] searchResults %@", searchResults);
        }
        [event setObject:searchResults forKey:@"results"];
    }
    
    [self _fireEventToListener:@"completed" withObject:event listener:callback thisObject:nil];

}

-(void)resetCache:(id)unused
{
    ENSURE_UI_THREAD(resetCache,unused);
    if (_places) {
        [_places removeAllObjects];
    }
}

-(void)placesLoaded:(id)unused
{
    ENSURE_UI_THREAD(placesLoaded,unused);
    if (!_places) {
        return NUMBOOL(NO);
    }
    
    return NUMBOOL([_places count] > 0);
}

@end
