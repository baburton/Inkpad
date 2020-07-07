//
//  WDPageSizeController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//  Copyright (c) 2020 Ben Burton
//

#import <UIKit/UIKit.h>

@protocol WDPageSizeControllerDelegate;

@interface WDPageSizeController : UITableViewController <UITableViewDelegate, UITableViewDataSource> {
    NSArray                 *configuration_;
    UITableViewCell         *customCell_;
}

@property (nonatomic, readonly) CGSize size;
@property (weak, nonatomic, readonly) NSString *units;
@property (weak, nonatomic) id<WDPageSizeControllerDelegate> delegate;

@end

@protocol WDPageSizeControllerDelegate <NSObject>
- (void) pageSizeControllerDidCancel:(WDPageSizeController *)controller;
- (void) pageSizeControllerDidCreate:(WDPageSizeController *)controller;
@end

extern NSString *WDPageOrientation;
extern NSString *WDPageSize;
