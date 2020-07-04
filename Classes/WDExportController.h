//
//  WDExportController.h
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

@class WDBrowserController;

enum {
    kWDExportViaEmailMode,
    kWDExportViaDropboxMode
};

typedef enum {
    kWDExportJPEG = 0,
    kWDExportPNG,
    kWDExportSVG,
    kWDExportPDF,
    kWDExportInkpad
} WDExportFormat;


@interface WDExportController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
    IBOutlet    UITableView     *formatTable_;
}

/**
 * The browser that manages this export controller.
 *
 * This must be set before \a mode.
 */
@property (nonatomic, weak) WDBrowserController* browser;

@property (nonatomic, assign) NSUInteger mode;
@property (nonatomic, assign) SEL action;
@property (nonatomic, readonly) NSArray *formats;

@end


extern NSString *WDEmailFormatDefault;
extern NSString *WDDropboxFormatDefault;
