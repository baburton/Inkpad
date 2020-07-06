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
#import "WDSamplesController.h"

@class WDDocument;
@class WDDrawing;
@class WDFontLibraryController;
@class WDPageSizeController;

@class DBUserClient;
@class WDBlockingView;
@class OCAViewController;

@interface WDBrowserController : UIDocumentBrowserViewController <UIDocumentBrowserViewControllerDelegate,
                                                                  UIPopoverPresentationControllerDelegate,
                                                                  MFMailComposeViewControllerDelegate,
                                                                  WDSamplesControllerDelegate,
                                                                  UINavigationControllerDelegate,
#if 0 // bab: no openclipart
                                                                  OCADownloaderDelegate,
#endif
                                                                  UIImagePickerControllerDelegate>
{
    NSMutableArray          *toolbarItems_;
    
    UIViewController        *popoverController_;
    WDPageSizeController    *pageSizeController_;
    UIImagePickerController *pickerController_;
    WDFontLibraryController *fontLibraryController_;
    WDSamplesController     *samplesController_;
#if 0 // bab: no openclipart
    OCAViewController       *openClipArtController_;
    NSMutableSet            *downloaders_; // for downloading open clip art
#endif
    
    DBUserClient            *dbClient_;
}

- (void) dismissPopover;

- (void) presentDocumentAtURL:(NSURL*)documentURL;

@end
