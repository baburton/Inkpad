//
//  WDImportController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Original implementation by Joe Ricioppo
//
//  Copyright (c) 2011-2013 Steve Sprang
//  Copyright (c) 2020 Ben Burton
//

#import <UIKit/UIKit.h>

@class DBFILESMetadata;
@class DBFILESFileMetadata;
@class DBUserClient;
@class WDBrowserController;

@interface WDImportController : UIViewController <UITableViewDataSource, UITableViewDelegate> {

	UIBarButtonItem                     *importButton_;
	IBOutlet UIActivityIndicatorView    *activityIndicator_;
	IBOutlet UITableView                *contentsTable_;
	NSArray<DBFILESMetadata*>           *dropboxItems_;
	NSMutableSet<DBFILESFileMetadata*>  *selectedItems_;
	NSMutableSet<NSString*>             *itemsFailedImageLoading_;
	BOOL                                isRoot_;
	NSString                            *imageCacheDirectory_;
	DBUserClient                        *dropboxClient_;
	NSFileManager                       *fileManager_;
	
}

@property (nonatomic, copy) NSString *remotePath;
@property (nonatomic, weak) WDBrowserController* browser;

+ (BOOL) isFontType:(NSString *)extension;
+ (BOOL) canImportType:(NSString *)extension;

@end
