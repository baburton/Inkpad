//
//  WDDrawingManager.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//  Copyright (c) 2020 Ben Burton
//

#import <UIKit/UIKit.h>

@class WDDrawing;
@class WDDocument;

@interface WDDrawingManager : NSObject

+ (WDDrawingManager *) sharedInstance;

+ (NSString *) drawingPath;
+ (BOOL) drawingExists:(NSString *)drawing;

- (WDDocument *) createNewDrawingWithSize:(CGSize)size andUnits:(NSString *)units;
- (BOOL) createNewDrawingWithImageAtURL:(NSURL *)imageURL;
- (BOOL) createNewDrawingWithImage:(UIImage *)image;

// these import methods are asynchronous
- (void) importDrawingAtURL:(NSURL *)url errorBlock:(void (^)(void))errorBlock withCompletionHandler:(void (^)(WDDocument *))completionBlock;

- (NSData *) dataForFilename:(NSString *)name;

- (WDDocument *) duplicateDrawing:(WDDocument *)document;

- (NSString *) uniqueFilenameWithPrefix:(NSString *)prefix extension:(NSString *)extension;

@end

extern NSString *WDSVGFileExtension;
extern NSString *WDDrawingFileExtension;
extern NSString *WDDefaultDrawingExtension;

