//
//  ThumbnailProvider.m
//  Inkpad Thumbnails
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2020 Ben Burton
//

#import "ThumbnailProvider.h"
#import "WDSVGThumbnailExtractor.h"
#import <UIKit/UIKit.h>

NSString *inkpadErrorDomain = @"org.benburton.inkpad.ErrorDomain";

typedef enum : NSUInteger {
    InkpadThumbnailNoURLData = 101,
    InkpadThumbnailNoKeyedData = 102,
    InkpadThumbnailNoImage = 103,
    InkpadThumbnailZeroAreaImage = 104,
    InkpadThumbnailZeroAreaRequest = 105,
    SVGThumbnailNoURLData = 201,
    SVGThumbnailParseError = 202,
} InkpadErrorCode;

// Constants that are duplicated from the main Inkpad sources
// (to avoid having to link other Inkpad sources into the thumbnail extension):
NSString *WDThumbnailKey = @"WDThumbnailKey";

@implementation ThumbnailProvider

- (void)provideThumbnailForFileRequest:(QLFileThumbnailRequest *)request completionHandler:(void (^)(QLThumbnailReply * _Nullable, NSError * _Nullable))handler {
    NSData* thumbData = nil;
    
    if ([request.fileURL.pathExtension caseInsensitiveCompare:@"svg"] == NSOrderedSame) {
        NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithContentsOfURL:request.fileURL];
        if (! xmlParser) {
            handler(nil, [NSError errorWithDomain:inkpadErrorDomain code:SVGThumbnailNoURLData userInfo:nil]);
            return;
        }
        
        WDSVGThumbnailExtractor *extractor = [[WDSVGThumbnailExtractor alloc] init];
        xmlParser.delegate = extractor;
        if ([xmlParser parse]) {
            handler(nil, [NSError errorWithDomain:inkpadErrorDomain code:SVGThumbnailParseError userInfo:nil]);
            return;
        }
        
        thumbData = extractor.thumbnail;
    } else {
        // Assume that what we're given is an inkpad file.
        NSData *data = [NSData dataWithContentsOfURL:request.fileURL];
        if (! data) {
            handler(nil, [NSError errorWithDomain:inkpadErrorDomain code:InkpadThumbnailNoURLData userInfo:nil]);
            return;
        }
        
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        thumbData = [unarchiver decodeObjectForKey:WDThumbnailKey];
        [unarchiver finishDecoding];
    }

    if (! thumbData) {
        handler(nil, [NSError errorWithDomain:inkpadErrorDomain code:InkpadThumbnailNoKeyedData userInfo:nil]);
        return;
    }

    UIImage* thumb = [[UIImage alloc] initWithData:thumbData scale:request.scale];
    if (! thumb) {
        handler(nil, [NSError errorWithDomain:inkpadErrorDomain code:InkpadThumbnailNoImage userInfo:nil]);
        return;
    }
    if (thumb.size.width <= 0 || thumb.size.height <= 0) {
        handler(nil, [NSError errorWithDomain:inkpadErrorDomain code:InkpadThumbnailZeroAreaImage userInfo:nil]);
        return;
    }
    if (request.maximumSize.width <= 0 || request.maximumSize.height <= 0) {
        handler(nil, [NSError errorWithDomain:inkpadErrorDomain code:InkpadThumbnailZeroAreaRequest userInfo:nil]);
        return;
    }
    
    CGRect drawIn;
    if (thumb.size.width * request.maximumSize.height <= thumb.size.height * request.maximumSize.width) {
        // Thumbnail may be too tall
        drawIn.size.height = request.maximumSize.height;
        drawIn.origin.y = 0;

        drawIn.size.width = thumb.size.width * request.maximumSize.height / thumb.size.height;
        drawIn.origin.x = (request.maximumSize.width - drawIn.size.width) / 2;
    } else {
        // Thumbnail may be too wide
        drawIn.size.width = request.maximumSize.width;
        drawIn.origin.x = 0;

        drawIn.size.height = thumb.size.height * request.maximumSize.width / thumb.size.width;
        drawIn.origin.y = (request.maximumSize.height - drawIn.size.height) / 2;
    }

    handler([QLThumbnailReply replyWithContextSize:request.maximumSize currentContextDrawingBlock:^BOOL {
        [thumb drawInRect:drawIn];
        return YES;
    }], nil);
}

@end
