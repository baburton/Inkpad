//
//  WDBrowserController.h
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
#import <MessageUI/MFMailComposeViewController.h>
#if 0 // bab: no openclipart
#import "OCADownloader.h"
#endif
#import "WDHelpController.h"
#if 0 // bab: no dropbox
#import "WDImportController.h"
#endif
#import "WDSamplesController.h"

@class WDActivityManager;
@class WDDocument;
@class WDDrawing;
@class WDFontLibraryController;
@class WDPageSizeController;
@class WDThumbnailView;

@class DBUserClient;
@class WDActivityController;
@class WDBlockingView;
@class WDExportController;
@class OCAViewController;

@interface WDBrowserController : UICollectionViewController <UIPopoverPresentationControllerDelegate,
                                                             MFMailComposeViewControllerDelegate,
#if 0 // bab: no dropbox
                                                             WDImportControllerDelegate,
#endif
                                                             WDSamplesControllerDelegate,
                                                             UINavigationControllerDelegate,
#if 0 // bab: no openclipart
                                                             OCADownloaderDelegate,
#endif
                                                             UIImagePickerControllerDelegate>
{
    NSMutableArray          *toolbarItems_;
    UIBarButtonItem         *emailItem_;
    UIBarButtonItem         *dropboxExportItem_;
    UIActivityIndicatorView *activityIndicator_;
    UIBarButtonItem         *activityItem_;
    UIBarButtonItem         *deleteItem_;
    
    NSMutableSet            *selectedDrawings_;
    
    UIViewController        *popoverController_;
    WDPageSizeController    *pageSizeController_;
    WDExportController      *exportController_;
#if 0 // bab: no dropbox
	WDImportController		*importController_;
#endif
    UIImagePickerController *pickerController_;
    WDFontLibraryController *fontLibraryController_;
    WDSamplesController     *samplesController_;
    WDActivityController    *activityController_;
#if 0 // bab: no openclipart
    OCAViewController       *openClipArtController_;
#endif
    
    DBUserClient            *dbClient_;
    NSMutableSet            *filesBeingUploaded_;
    WDActivityManager       *activities_;

    WDBlockingView          *blockingView_;
    WDThumbnailView         *editingThumbnail_;
    
    BOOL                    everLoaded_;
    
    NSMutableSet            *downloaders_; // for downloading open clip art
}

- (void) startEditingDrawing:(WDDocument *)drawing;
- (void) unlinkDropbox:(id)sender;

@end
