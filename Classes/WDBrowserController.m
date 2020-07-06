//
//  WDBrowserController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//  Copyright (c) 2020 Ben Burton
//

#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#if 0 // bab: no openclipart
#import "OCAEntry.h"
#import "OCAViewController.h"
#endif
#import "NSData+Additions.h"
#import "WDActivity.h"
#import "WDActivityController.h"
#import "WDActivityManager.h"
#import "WDAppDelegate.h"
#import "WDBlockingView.h"
#import "WDBrowserController.h"
#import "WDCanvasController.h"
#import "WDDocument.h"
#import "WDDrawing.h"
#import "WDDrawingManager.h"
#import "WDFontLibraryController.h"
#import "WDFontManager.h"
#import "WDPageSizeController.h"
#import "UIBarButtonItem+Additions.h"

#define kEditingHighlightRadius     125

@implementation WDBrowserController

#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.delegate = self;
    self.allowsDocumentCreation = YES;
    self.allowsPickingMultipleItems = NO;
    self.browserUserInterfaceStyle = UIDocumentBrowserUserInterfaceStyleLight;
    if (@available(iOS 13.0, *)) {
        self.localizedCreateDocumentActionTitle = NSLocalizedString(@"Create Drawing", @"Create Drawing");
        self.defaultDocumentAspectRatio = 1.0;
    }
    
    // Set up additional buttons in the navigation bar.
    // These should be for global actions (not specific to any particular files).
    UIBarButtonItem *helpItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Help", @"Help")
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(showHelp:)];
    self.additionalLeadingNavigationBarButtonItems = @[helpItem];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - OpenClipArt

#if 0 // bab: no openclipart
- (void) takeDataFromDownloader:(OCADownloader *)downloader
{
    NSString *title = [downloader.info stringByAppendingPathExtension:@"svg"];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:title];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [downloader.data writeToFile:path atomically:YES];
        
        NSURL *pathURL = [[NSURL alloc] initFileURLWithPath:path isDirectory:NO];
        [[WDDrawingManager sharedInstance] importDrawingAtURL:pathURL
                                                   errorBlock:^{
                                                       [self showImportErrorMessage:downloader.info];
                                                       [[NSFileManager defaultManager] removeItemAtURL:pathURL error:nil];
                                                   }
                                        withCompletionHandler:^(WDDocument *document) {
                                            [[NSFileManager defaultManager] removeItemAtURL:pathURL error:nil];
                                        }];
    }
    
    [downloaders_ removeObject:downloader];
}

- (void) importOpenClipArt:(OCAViewController *)viewController
{
    OCAEntry *entry = viewController.selectedEntry;
    
    if (!downloaders_) {
        downloaders_ = [NSMutableSet set];
    }
    
    OCADownloader *downloader = [OCADownloader downloaderWithURL:entry.SVGURL delegate:self info:entry.title];
    [downloaders_ addObject:downloader];
    
    if (openClipArtController_.isVisible) {
        [self dismissPopover];
    }
}

- (void) showOpenClipArt:(id)sender
{
    if (openClipArtController_.isVisible) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    if (!openClipArtController_) {
        openClipArtController_ = [[OCAViewController alloc] initWithNibName:@"OpenClipArt" bundle:nil];
        [openClipArtController_ setImportTarget:self action:@selector(importOpenClipArt:)];
        [openClipArtController_ setActionTitle:NSLocalizedString(@"Import", @"Import")];
    }
    
    UINavigationController  *navController = [[UINavigationController alloc] initWithRootViewController:openClipArtController_];
    navController.navigationBar.translucent = NO; // Ensure content starts below the navigation bar
    navController.toolbarHidden = NO;
    
    popoverController_ = navController;
    popoverController_.modalPresentationStyle = UIModalPresentationPopover;
    popoverController_.popoverPresentationController.delegate = self;
    popoverController_.popoverPresentationController.barButtonItem = sender;
    popoverController_.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    [self presentViewController:popoverController_ animated:NO completion:nil];
}
#endif

#pragma mark - Camera

- (void) importFromImagePicker:(id)sender sourceType:(UIImagePickerControllerSourceType)sourceType
{
    if (pickerController_ && (pickerController_.sourceType == sourceType)) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    pickerController_ = [[UIImagePickerController alloc] init];
    pickerController_.sourceType = sourceType;
    pickerController_.delegate = self;
    
    popoverController_ = pickerController_;
    popoverController_.modalPresentationStyle = UIModalPresentationPopover;
    popoverController_.popoverPresentationController.delegate = self;
    popoverController_.popoverPresentationController.barButtonItem = sender;
    popoverController_.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    [self presentViewController:popoverController_ animated:NO completion:nil];
}

- (void) importFromAlbum:(id)sender
{
    [self importFromImagePicker:sender sourceType:UIImagePickerControllerSourceTypePhotoLibrary];
}

- (void) importFromCamera:(id)sender
{
    [self importFromImagePicker:sender sourceType:UIImagePickerControllerSourceTypeCamera];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self imagePickerControllerDidCancel:picker];
    [[WDDrawingManager sharedInstance] createNewDrawingWithImage:info[UIImagePickerControllerOriginalImage]];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [popoverController_ dismissViewControllerAnimated:YES completion:nil];
    popoverController_ = nil;
}

#pragma mark - Toolbar

- (NSArray *) defaultToolbarItems
{
    if (!toolbarItems_) {
        toolbarItems_ = [[NSMutableArray alloc] init];
        
        UIBarButtonItem *importItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Import", @"Import")
                                                                       style:UIBarButtonItemStylePlain target:self
                                                                      action:@selector(showDropboxImportPanel:)];
        UIBarButtonItem *samplesItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Samples", @"Samples")
                                                                        style:UIBarButtonItemStylePlain
                                                                       target:self
                                                                       action:@selector(showSamplesPanel:)];
        
        UIBarButtonItem *fontItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Fonts", @"Fonts")
                                                                     style:UIBarButtonItemStylePlain target:self
                                                                    action:@selector(showFontLibraryPanel:)];
        activityIndicator_ = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        UIBarButtonItem *spinnerItem = [[UIBarButtonItem alloc] initWithCustomView:activityIndicator_];
        
        activityItem_ = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Activity", @"Activity")
                                                         style:UIBarButtonItemStylePlain target:self
                                                        action:@selector(showActivityPanel:)];
        
        UIBarButtonItem *flexibleItem = [UIBarButtonItem flexibleItem];
        UIBarButtonItem *fixedItem = [UIBarButtonItem fixedItemWithWidth:10];
        
        [toolbarItems_ addObject:importItem];
        [toolbarItems_ addObject:fixedItem];
        [toolbarItems_ addObject:samplesItem];
        [toolbarItems_ addObject:fixedItem];
        [toolbarItems_ addObject:fontItem];
        [toolbarItems_ addObject:flexibleItem];
        
        [toolbarItems_ addObject:spinnerItem];
        [toolbarItems_ addObject:fixedItem];
        [toolbarItems_ addObject:fixedItem];
    }
    
    return toolbarItems_;
}

#pragma mark - Panels

- (void) showFontLibraryPanel:(id)sender
{
    if (fontLibraryController_) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    fontLibraryController_ = [[WDFontLibraryController alloc] initWithNibName:nil bundle:nil];

    UINavigationController  *navController = [[UINavigationController alloc] initWithRootViewController:fontLibraryController_];
    
    popoverController_ = navController;
    popoverController_.modalPresentationStyle = UIModalPresentationPopover;
    popoverController_.popoverPresentationController.delegate = self;
    popoverController_.popoverPresentationController.barButtonItem = sender;
    popoverController_.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    [self presentViewController:popoverController_ animated:NO completion:nil];
}

- (void) samplesController:(WDSamplesController *)controller didSelectURLs:(NSArray *)sampleURLs
{
    [self dismissPopover];
    
    [[WDDrawingManager sharedInstance] installSamples:sampleURLs];
}

- (void) showSamplesPanel:(id)sender
{
    if (samplesController_) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    samplesController_ = [[WDSamplesController alloc] initWithNibName:nil bundle:nil];
    samplesController_.title = NSLocalizedString(@"Samples", @"Samples");
    samplesController_.delegate = self;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:samplesController_];
    
    popoverController_ = navController;
    popoverController_.modalPresentationStyle = UIModalPresentationPopover;
    popoverController_.popoverPresentationController.delegate = self;
    popoverController_.popoverPresentationController.barButtonItem = sender;
    popoverController_.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    [self presentViewController:popoverController_ animated:NO completion:nil];
}

- (void) showActivityPanel:(id)sender
{
    if (activityController_) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    activityController_ = [[WDActivityController alloc] initWithNibName:nil bundle:nil];
    activityController_.activityManager = activities_;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:activityController_];
    
    popoverController_ = navController;
    popoverController_.modalPresentationStyle = UIModalPresentationPopover;
    popoverController_.popoverPresentationController.delegate = self;
    popoverController_.popoverPresentationController.barButtonItem = sender;
    popoverController_.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    [self presentViewController:popoverController_ animated:NO completion:nil];
}

- (void) activityCountChanged:(NSNotification *)aNotification
{
    NSUInteger numActivities = activities_.count;
    
    if (numActivities) {
        [activityIndicator_ startAnimating];
    } else {
        [activityIndicator_ stopAnimating];
    }
    
    if (numActivities == 0) {
        if (activityController_) {
            [self dismissPopoverAnimated:YES];
        }
        
        [toolbarItems_ removeObject:activityItem_];
        
        if (!self.isEditing) {
            [self setToolbarItems:[NSArray arrayWithArray:[self defaultToolbarItems]] animated:YES];
        }
    } else if (![toolbarItems_ containsObject:activityItem_]) {
        [toolbarItems_ insertObject:activityItem_ atIndex:(toolbarItems_.count - 2)];
        
        if (!self.isEditing) {
            [self setToolbarItems:[NSArray arrayWithArray:[self defaultToolbarItems]] animated:YES];
        }
    }
}

- (void) showHelp:(id)sender
{
    WDHelpController *helpController = [[WDHelpController alloc] initWithNibName:nil bundle:nil];
    
    // Create a Navigation controller
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:helpController];
    navController.modalPresentationStyle = UIModalPresentationPageSheet;
    
    // show the navigation controller modally
    [self presentViewController:navController animated:YES completion:nil];
}

#pragma mark - Popovers

- (void) dismissPopoverAnimated:(BOOL)animated
{
    if (popoverController_) {
        [popoverController_ dismissViewControllerAnimated:animated completion:nil];
        popoverController_ = nil;
    }
    
    importController_ = nil;
    pickerController_ = nil;
    fontLibraryController_ = nil;
    samplesController_ = nil;
    activityController_ = nil;
}

- (void) dismissPopover
{
    [self dismissPopoverAnimated:NO];
}

- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController
{
    // In iOS 13 this method is deprecated in favour of presentationControllerDidDismiss:.
    // However, if the latter method is missing, this method will still be called.
    if (popoverPresentationController.presentedViewController == popoverController_) {
        popoverController_ = nil;
    }
    
    importController_ = nil;
    pickerController_ = nil;
    fontLibraryController_ = nil;
    samplesController_ = nil;
    activityController_ = nil;
}

- (void)didDismissModalView {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -

- (void) reallyShowDropboxImportPanel:(id)sender
{
	if (importController_) {
		[self dismissPopover];
		return;
	}
	
	[self dismissPopover];
	
	importController_ = [[WDImportController alloc] initWithNibName:@"Import" bundle:nil];
	importController_.title = @"Dropbox";
	importController_.browser = self;
	
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:importController_];
	
    popoverController_ = navController;
    popoverController_.modalPresentationStyle = UIModalPresentationPopover;
    popoverController_.popoverPresentationController.delegate = self;
    popoverController_.popoverPresentationController.barButtonItem = sender;
    popoverController_.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    [self presentViewController:popoverController_ animated:NO completion:nil];
}

- (void) showDropboxImportPanel:(id)sender
{
    if (![self dropboxIsLinked]) {
        WDAppDelegate *delegate = (WDAppDelegate *) [UIApplication sharedApplication].delegate;
        delegate.performAfterDropboxLoginBlock = ^{ [self reallyShowDropboxImportPanel:sender]; };
	} else {
        [self reallyShowDropboxImportPanel:sender];
    }
}

- (void) importController:(WDImportController *)controller didSelectDropboxItems:(NSArray<DBFILESFileMetadata*> *)dropboxItems
{
    if (!dbClient_) {
        dbClient_ = [DBClientsManager authorizedClient];
    }

    NSString    *downloadsDirectory = [NSTemporaryDirectory() stringByAppendingString:@"Downloads/"];
    BOOL        isDirectory = NO;
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:downloadsDirectory isDirectory:&isDirectory] || !isDirectory) {
        [[NSFileManager defaultManager] createDirectoryAtPath:downloadsDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
	for (DBFILESFileMetadata *item in dropboxItems) {
        NSString *downloadPath = [downloadsDirectory stringByAppendingString:item.name];
        NSURL* downloadURL = [NSURL fileURLWithPath:downloadPath];
        
        // make sure we're not already downloading/importing this file
        if (!activities_.count || ![activities_ activityWithFilepath:downloadPath]) {
            // TODO: If/when we reintroduce progress tracking, we need to periodically call
            // [activities_ updateProgressForFilepath:destPath progress:progress].
            [[dbClient_.filesRoutes downloadUrl:item.id_ overwrite:YES destination:downloadURL] setResponseBlock:^(DBFILESFileMetadata * _Nullable result, DBFILESDownloadError * _Nullable routeError, DBRequestError * _Nullable networkError, NSURL * _Nonnull destination) {
                if (routeError || networkError || ! result) {
                    // This is asynchronous, and so the user might have called up a new
                    // popover since we started the upload.
                    [self dismissPopover];

                    [self->activities_ removeActivityWithFilepath:downloadPath];
                    [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:NULL];
                    
                    NSString *format = NSLocalizedString(@"There was a problem downloading “%@”. Check your network connection and try again.",
                                                         @"There was a problem downloading “%@”. Check your network connection and try again.");
                    UIAlertController *alertView = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Download Problem", @"Download Problem")
                                                                                       message:[NSString stringWithFormat:format, [downloadPath lastPathComponent]]
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                    [alertView addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK") style:UIAlertActionStyleCancel handler:nil]];
                    [self presentViewController:alertView animated:YES completion:nil];
                } else {
                    NSString    *extension = [[downloadPath pathExtension] lowercaseString];
                    NSString    *filename = [downloadPath lastPathComponent];
                    
                    // find the associated download activity
                    WDActivity  *downloadActivity = [self->activities_ activityWithFilepath:downloadPath];
                    
                    if ([extension isEqualToString:@"inkpad"] || [extension isEqualToString:@"svg"] || [extension isEqualToString:@"svgz"]) {
                        WDActivity *importActivity = [WDActivity activityWithFilePath:downloadPath type:WDActivityTypeImport];
                        [self->activities_ addActivity:importActivity];
                        
                        // this is asynchronous
                        [[WDDrawingManager sharedInstance] importDrawingAtURL:[NSURL fileURLWithPath:downloadPath]
                                                                   errorBlock:^{ [self showImportErrorMessage:filename]; }
                                                        withCompletionHandler:^(WDDocument *document) {
                                                            [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:NULL];
                                                            [self->activities_ removeActivity:importActivity];
                                                        }];
                    } else if ([WDImportController isFontType:extension]) {
                        BOOL alreadyInstalled;
                        NSString *importedFontName = [[WDFontManager sharedInstance] installUserFont:[NSURL fileURLWithPath:downloadPath]
                                                                                    alreadyInstalled:&alreadyInstalled];
                        if (!importedFontName) {
                            [self showImportErrorMessage:filename];
                        }
                        
                        [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:NULL];
                    } else if ([WDImportController canImportType:extension]) {
                        BOOL success = [[WDDrawingManager sharedInstance] createNewDrawingWithImageAtURL:[NSURL fileURLWithPath:downloadPath]];
                        if (!success) {
                            [self showImportErrorMessage:filename];
                        }
                        
                        [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:NULL];
                    }
                    
                    // remove the download activity. do this last so the activity count doesn't drop to 0
                    [self->activities_ removeActivity:downloadActivity];
                }
            }];
            [activities_ addActivity:[WDActivity activityWithFilePath:downloadPath type:WDActivityTypeDownload]];
        }
	}
	
	[self dismissPopover];
}

#pragma mark -

- (void) showImportErrorMessage:(NSString *)filename
{
    NSString *format = NSLocalizedString(@"Inkpad could not import “%@”. It may be corrupt or in a format that's not supported.",
                                         @"Inkpad could not import “%@”. It may be corrupt or in a format that's not supported.");
    UIAlertController *alertView = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Import Problem", @"Import Problem")
                                                                       message:[NSString stringWithFormat:format, filename]
                                                                preferredStyle:UIAlertControllerStyleAlert];
    [alertView addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertView animated:YES completion:nil];
}

- (void) showImportMemoryWarningMessage:(NSString *)filename
{
    NSString *format = NSLocalizedString(@"Inkpad could not import “%@”. There is not enough available memory.",
                                         @"Inkpad could not import “%@”. There is not enough available memory.");
    UIAlertController *alertView = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Import Problem", @"Import Problem")
                                                                       message:[NSString stringWithFormat:format, filename]
                                                                preferredStyle:UIAlertControllerStyleAlert];
    [alertView addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertView animated:YES completion:nil];
}

#pragma mark -

- (void) unlinkDropbox:(id)sender
{
    // Dismiss popovers, since the unlink process presents its own alert.
    [self dismissPopoverAnimated:NO];
    
    [(WDAppDelegate*)[UIApplication sharedApplication].delegate unlinkDropbox];
}

- (void) dropboxUnlinked:(NSNotification *)aNotification
{
    [self dismissPopoverAnimated:YES];
    dbClient_ = nil;
}

- (BOOL) dropboxIsLinked
{
    if ([DBClientsManager authorizedClient].isAuthorized) {
        return YES;
    } else {
        [self dismissPopover];
        
        [DBClientsManager authorizeFromController:[UIApplication sharedApplication]
                                       controller:self
                                          openURL:^(NSURL * _Nonnull url) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                if (! success) {
                    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Could not link with Dropbox",
                                                                                                             @"Could not link with Dropbox")
                                                                                   message:NSLocalizedString(@"I was not able to link Inkpad with Dropbox.",
                                                                                                             @"I was not able to link Inkpad with Dropbox.")
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Close", @"Close") style:UIAlertActionStyleCancel handler:nil]];
                    [self presentViewController:alert animated:YES completion:nil];
                }
            }];
        }];
        return NO;
    }
}

#pragma mark - Documents

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didRequestDocumentCreationWithHandler:(void (^)(NSURL * _Nullable, UIDocumentBrowserImportMode))importHandler
{
    [self dismissPopover];
    
    // TODO: Implement. Create in temporary location, then call importHandler with import mode ImportMode.move; to cancel pass nil, ImportMode.none.
    
    pageSizeController_ = [[WDPageSizeController alloc] initWithNibName:nil bundle:nil];
    UINavigationController  *navController = [[UINavigationController alloc] initWithRootViewController:pageSizeController_];
    
    pageSizeController_.target = self;
    pageSizeController_.action = @selector(createNewDrawing:);
    
    popoverController_ = navController;
    popoverController_.modalPresentationStyle = UIModalPresentationPopover;
    popoverController_.popoverPresentationController.delegate = self;
    //popoverController_.popoverPresentationController.barButtonItem = sender;
    popoverController_.popoverPresentationController.barButtonItem = self.additionalLeadingNavigationBarButtonItems.firstObject;
    popoverController_.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    [self presentViewController:popoverController_ animated:NO completion:nil];
}

// TODO: Delete
- (void) createNewDrawing:(id)sender
{
    [self dismissPopover];
    
    WDDocument *document = [[WDDrawingManager sharedInstance] createNewDrawingWithSize:pageSizeController_.size
                                                                              andUnits:pageSizeController_.units];
    [document closeWithCompletionHandler:^(BOOL success) {
        if (success) {
            
        } else {
            // TODO: Present error.
        }
    }];
}

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didPickDocumentURLs:(NSArray<NSURL *> *)documentURLs
{
    // Method for iOS 11.
    
    // We do not support picking multiple items.
    if (documentURLs.count > 0)
        [self presentDocumentAtURL:documentURLs.firstObject];
}

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)documentURLs
{
    // Method for iOS 12 and above.
    
    // We do not support picking multiple items.
    if (documentURLs.count > 0)
        [self presentDocumentAtURL:documentURLs.firstObject];
}

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didImportDocumentAtURL:(NSURL *)sourceURL toDestinationURL:(NSURL *)destinationURL
{
    [self presentDocumentAtURL:destinationURL];
}

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller failedToImportDocumentAtURL:(NSURL *)documentURL error:(NSError *)error
{
    // TODO: Present error.
}

- (void)presentDocumentAtURL:(NSURL *)documentURL
{
    if (! [documentURL startAccessingSecurityScopedResource]) {
        // TODO: Present error.
        return;
    }

    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
    UINavigationController *nav = [storyBoard instantiateViewControllerWithIdentifier:@"document"];
    WDCanvasController* canvas = (WDCanvasController*)nav.topViewController;
    
    WDDocument *document = [[WDDocument alloc] initWithFileURL:documentURL];
    [document openWithCompletionHandler:nil];
    canvas.document = document;
    
    [documentURL stopAccessingSecurityScopedResource];
    
    if (! canvas.document) {
        // TODO: Present error.
        return;
    }
    
    [self presentViewController:nav animated:YES completion:nil];
}

@end

#if 0
// Code snippets to bring back:

// ---------------------------

// Further initialisation code:
activities_ = [[WDActivityManager alloc] init];

[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(dropboxUnlinked:)
                                             name:WDDropboxWasUnlinkedNotification
                                           object:nil];

[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(activityCountChanged:)
                                             name:WDActivityAddedNotification
                                           object:nil];

[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(activityCountChanged:)
                                             name:WDActivityRemovedNotification
                                           object:nil];

NSMutableArray *rightBarButtonItems = [NSMutableArray array];

// create an album import button
UIBarButtonItem *albumItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"album_centered.png"]
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(importFromAlbum:)];
[rightBarButtonItems addObject:albumItem];

// add a camera import item if we have a camera (I think this will always be true from now on)
if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
    UIBarButtonItem *cameraItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCamera
                                                                                target:self
                                                                                action:@selector(importFromCamera:)];
    [rightBarButtonItems addObject:cameraItem];
}

self.navigationItem.rightBarButtonItems = rightBarButtonItems;
self.toolbarItems = [self defaultToolbarItems];

// ---------------------------

// Exporting to different formats:
formats_ = @[@"JPEG", @"PNG", @"SVG", @"SVGZ", @"PDF", @"Inkpad"];

[[WDDrawingManager sharedInstance] openDocumentWithName:filename withCompletionHandler:^(WDDocument *document) {
    @autoreleasepool {
        WDDrawing *drawing = document.drawing;
        // TODO use document contentForType
        NSData *data = nil;
        NSString *extension = nil;
        NSString *mimeType = nil;
        if ([format isEqualToString:@"Inkpad"]) {
            data = [[WDDrawingManager sharedInstance] dataForFilename:filename];
            extension = WDDrawingFileExtension;
            mimeType = @"application/x-inkpad";
        } else if ([format isEqualToString:@"SVG"]) {
            data = [drawing SVGRepresentation];
            extension = @"svg";
            mimeType = @"image/svg+xml";
        } else if ([format isEqualToString:@"SVGZ"]) {
            data = [[drawing SVGRepresentation] compress];
            extension = @"svgz";
            mimeType = @"image/svg+xml";
        } else if ([format isEqualToString:@"PNG"]) {
            data = UIImagePNGRepresentation([drawing image]);
            extension = @"png";
            mimeType = @"image/png";
        } else if ([format isEqualToString:@"JPEG"]) {
            data = UIImageJPEGRepresentation([drawing image], 0.9);
            extension = @"jpeg";
            mimeType = @"image/jpeg";
        } else if ([format isEqualToString:@"PDF"]) {
            data = [drawing PDFRepresentation];
            extension = @"pdf";
            mimeType = @"image/pdf";
        }
    }
}];
#endif
