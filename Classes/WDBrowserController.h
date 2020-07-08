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
#import "WDPageSizeController.h"
#import "WDSamplesController.h"

@interface WDBrowserController : UIDocumentBrowserViewController <UIDocumentBrowserViewControllerDelegate,
                                                                  UIPopoverPresentationControllerDelegate,
                                                                  WDPageSizeControllerDelegate,
                                                                  WDSamplesControllerDelegate,
                                                                  UINavigationControllerDelegate,
                                                                  UIImagePickerControllerDelegate>

- (void) presentDocumentAtURL:(NSURL*)documentURL;

+ (BOOL)canOpen:(NSURL*)url;

@end
