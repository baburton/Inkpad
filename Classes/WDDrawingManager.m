//
//  WDDrawingManager.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//  Copyright (c) 2020 Ben Burton
//

#import "UIImage+Additions.h"
#import "WDDocument.h"
#import "WDDrawingManager.h"
#import "WDSVGParser.h"
#import "WDSVGThumbnailExtractor.h"

NSString *WDDrawingFileExtension = @"inkpad";
NSString *WDSVGFileExtension = @"svg";
NSString *WDDefaultDrawingExtension = @"inkpad";

NSString *WDCreatedSamples = @"WDCreatedSamples";

@interface NSString (WDAdditions)
- (NSComparisonResult) compareNumeric:(NSString *)string;
@end

@implementation NSString (WDAdditions)
- (NSComparisonResult) compareNumeric:(NSString *)string {
    return [self compare:string options:NSNumericSearch];
}
@end

@implementation WDDrawingManager

+ (WDDrawingManager *) sharedInstance
{
    static WDDrawingManager *shared = nil;
    
    if (!shared) {
        shared = [[WDDrawingManager alloc] init];
    }
    
    return shared;
}

+ (NSString *) drawingPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0];
    return documentsDirectory;
}

+ (BOOL) drawingExists:(NSString *)drawing
{
    NSFileManager   *fm = [NSFileManager defaultManager];
    
    NSString        *inkpadFilename = [[drawing stringByDeletingPathExtension] stringByAppendingPathExtension:WDDrawingFileExtension];
    NSString        *svgFilename = [[drawing stringByDeletingPathExtension] stringByAppendingPathExtension:WDSVGFileExtension];
    
    NSString        *inkpadPath = [[self drawingPath] stringByAppendingPathComponent:inkpadFilename];
    NSString        *svgPath = [[self drawingPath] stringByAppendingPathComponent:svgFilename];
    
    return [fm fileExistsAtPath:svgPath] || [fm fileExistsAtPath:inkpadPath];
}

- (NSString *) uniqueFilename
{
    return [self uniqueFilenameWithPrefix:NSLocalizedString(@"Drawing", @"Default drawing name prefix")
                                extension:WDDefaultDrawingExtension];
}

- (NSString *) cleanPrefix:(NSString *)prefix
{
    // if the last "word" of the prefix is an int, strip it off
    NSArray *components = [prefix componentsSeparatedByString:@" "];
    BOOL    hasNumericalSuffix = NO;
    
    if (components.count > 1) {
        NSString *lastComponent = [components lastObject];
        hasNumericalSuffix = YES;
        
        for (int i = 0; i < lastComponent.length; i++) {
            if (![[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[lastComponent characterAtIndex:i]]) {
                hasNumericalSuffix = NO;
                break;
            }
        }
    }
    
    if (hasNumericalSuffix) {
        NSString *newPrefix = @"";
        for (int i = 0; i < components.count - 1; i++) {
            newPrefix = [newPrefix stringByAppendingString:components[i]];
            if (i != components.count - 2) {
                newPrefix = [newPrefix stringByAppendingString:@" "];
            }
        }
        
        prefix = newPrefix;
    }
    
    return prefix;
}

- (NSString *) uniqueFilenameWithPrefix:(NSString *)prefix extension:(NSString *)extension
{
    if (![WDDrawingManager drawingExists:prefix]) {
        return [prefix stringByAppendingPathExtension:extension];
    }
    
    prefix = [self cleanPrefix:prefix];

    NSString    *unique = nil;
    int         uniqueIx = 1;
    
    do {
        unique = [NSString stringWithFormat:@"%@ %d.%@", prefix, uniqueIx, extension];
        uniqueIx++;
    
    } while ([WDDrawingManager drawingExists:unique]);
    
    return unique;
}

- (WDDocument *) installDrawing:(WDDrawing *)drawing withName:(NSString *)drawingName closeAfterSaving:(BOOL)shouldClose
{
    NSString *path = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:drawingName];
    NSURL *url = [NSURL fileURLWithPath:path];
    
    WDDocument *document = [[WDDocument alloc] initWithFileURL:url];
    document.drawing = drawing;
    [document saveToURL:url forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
        if (shouldClose) {
            [document closeWithCompletionHandler:nil];
        }
    }];

    return document;
}

- (BOOL) createNewDrawingWithImage:(UIImage *)image imageName:(NSString *)imageName drawingName:(NSString *)drawingName
{
    if (!image) {
        return nil;
    }
    
    image = [image downsampleWithMaxArea:4096*4096];
    
    WDDrawing *drawing = [[WDDrawing alloc] initWithImage:image imageName:imageName];
    return [self installDrawing:drawing withName:drawingName closeAfterSaving:YES] ? YES : NO;
}

- (BOOL) createNewDrawingWithImage:(UIImage *)image
{
    NSString *imageName = NSLocalizedString(@"Photo", @"Photo");
    NSString *drawingName = [self uniqueFilenameWithPrefix:imageName extension:WDDefaultDrawingExtension];
    
    return [self createNewDrawingWithImage:image imageName:imageName drawingName:drawingName];
}

- (BOOL) createNewDrawingWithImageAtURL:(NSURL *)imageURL
{
    UIImage *image = [UIImage imageWithContentsOfFile:imageURL.path];
    NSString *imageName = [[imageURL lastPathComponent] stringByDeletingPathExtension];
    NSString *drawingName = [self uniqueFilenameWithPrefix:imageName extension:WDDefaultDrawingExtension];
    
    return [self createNewDrawingWithImage:image imageName:imageName drawingName:drawingName];
}

- (dispatch_queue_t) importQueue
{
    static dispatch_queue_t importQueue;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        importQueue = dispatch_queue_create("com.taptrix.inkpad.import", DISPATCH_QUEUE_SERIAL);
    });
    
    return importQueue;
}

- (WDDocument *) duplicateDrawing:(WDDocument *)document
{ 
    NSString *unique = [self uniqueFilenameWithPrefix:[document.filename stringByDeletingPathExtension]
                                            extension:[document.filename pathExtension]];
    
    // the original drawing will save when it's freed
    
    return [self installDrawing:document.drawing withName:unique closeAfterSaving:NO];
}

- (void) importDrawingAtURL:(NSURL *)url errorBlock:(void (^)(void))errorBlock withCompletionHandler:(void (^)(WDDocument *document))completionBlock
{
    WDDocument *doc = [[WDDocument alloc] initWithFileURL:url];
    [doc openWithCompletionHandler:^(BOOL success) {
        dispatch_async([self importQueue], ^{
            if (success) {
                doc.fileTypeOverride = @"com.taptrix.inkpad";
                NSString *svgName = [[url lastPathComponent] stringByDeletingPathExtension];
                NSString *drawingName = [self uniqueFilenameWithPrefix:svgName extension:WDDefaultDrawingExtension];
                NSString *path = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:drawingName]; 
                NSURL *newUrl = [NSURL fileURLWithPath:path];
                [doc saveToURL:newUrl forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        if (completionBlock) {
                           completionBlock(doc);
                        }
                        
                        [doc closeWithCompletionHandler:nil];
                    });
                }];
            } else {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    if (errorBlock) {
                        errorBlock();
                    }
                    
                    if (completionBlock) {
                        completionBlock(nil);
                    }
                });
            }
        });
    }];
}

@end
