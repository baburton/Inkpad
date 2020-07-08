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

#import "WDAppDelegate.h"
#import "WDBrowserController.h"
#import "WDCanvasController.h"
#import "WDDocument.h"
#import "WDDrawing.h"
#import "WDFontLibraryController.h"
#import "WDFontManager.h"
#import "WDHelpController.h"
#import "UIBarButtonItem+Additions.h"
#import "UIImage+Additions.h"

@interface WDBrowserController () {
    void (^createImportHandler)(NSURL * _Nullable, UIDocumentBrowserImportMode);
}
@end

@implementation WDBrowserController

#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.delegate = self;
    self.allowsDocumentCreation = YES;
    self.allowsPickingMultipleItems = NO;
    self.browserUserInterfaceStyle = UIDocumentBrowserUserInterfaceStyleLight;
    // self.view.tintColor = [UIColor colorWithRed:86.0/255.0 green:156.0/255.0 blue:227.0/255.0 alpha:1.0];
    self.view.tintColor = [UIColor colorWithRed:77.0/255.0 green:140.0/255.0 blue:204.0/255.0 alpha:1.0];
    // self.view.tintColor = [UIColor colorWithRed:71.0/255.0 green:130.0/255.0 blue:189.0/255.0 alpha:1.0];
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

    UIBarButtonItem *fontsItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Fonts", @"Fonts")
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(showFontLibraryPanel:)];
    UIBarButtonItem *samplesItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Samples", @"Samples")
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(showSamplesPanel:)];
    UIBarButtonItem *albumItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"album_centered.png"]
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(importFromAlbum:)];
    /*
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        UIBarButtonItem *cameraItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCamera
                                                                                    target:self
                                                                                    action:@selector(importFromCamera:)];
        [rightBarButtonItems addObject:cameraItem];
    }
    */

    self.additionalTrailingNavigationBarButtonItems = @[fontsItem, samplesItem, albumItem];
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
    
    UIViewController* popoverController_ = navController;
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
    [self dismissPopover];
    
    UIImagePickerController* pickerController_ = [[UIImagePickerController alloc] init];
    pickerController_.sourceType = sourceType;
    pickerController_.delegate = self;
    pickerController_.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:pickerController_ animated:YES completion:nil];
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
    [picker dismissViewControllerAnimated:YES completion:^{
        UIImage* image = info[UIImagePickerControllerOriginalImage];
        if (! image)
            return;
                
        image = [image downsampleWithMaxArea:4096*4096];
        
        WDDrawing *drawing = [[WDDrawing alloc] initWithImage:image imageName:NSLocalizedString(@"Photo", @"Photo")];
        
        NSData* data = [drawing inkpadRepresentation];
        if (! data) {
            // TODO: Present error
            return;
        }
        
        // WARNING: We are using the same temporary filename every time.
        // However, we should not be doing this operation more than once at a time.
        NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:NSLocalizedString(@"Photo.inkpad", @"Default imported photo drawing name")];
        if (! [data writeToFile:tempFile atomically:YES]) {
            // TODO: Present error
            return;
        }
        
        [self revealDocumentAtURL:[NSURL fileURLWithPath:tempFile] importIfNeeded:YES completion:^(NSURL * _Nullable revealedDocumentURL, NSError * _Nullable error) {
            if (error) {
                // TODO: Present error.
                NSLog(@"ERROR: Could not import: %@", tempFile);
            }
        }];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Panels

- (void) showFontLibraryPanel:(id)sender
{
    [self dismissPopover];
    
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
    UINavigationController *nav = [storyBoard instantiateViewControllerWithIdentifier:@"fonts"];
    
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void) samplesController:(WDSamplesController *)controller didSelectURLs:(NSArray *)sampleURLs
{
    [self dismissPopover];
    
    for (NSURL* url in sampleURLs) {
        [self revealDocumentAtURL:url importIfNeeded:YES completion:^(NSURL * _Nullable revealedDocumentURL, NSError * _Nullable error) {
            if (error) {
                // TODO: Present error.
                NSLog(@"ERROR: Could not import: %@", url);
            }
        }];
    }
}

- (void) showSamplesPanel:(id)sender
{
    [self dismissPopover];
    
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
    UINavigationController *nav = [storyBoard instantiateViewControllerWithIdentifier:@"samples"];
    ((WDSamplesController*)nav.topViewController).delegate = self;
    
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
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
    if (self.presentedViewController)
        [self dismissViewControllerAnimated:animated completion:nil];
}

- (void) dismissPopover
{
    [self dismissPopoverAnimated:NO];
}

- (void)didDismissModalView {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Documents

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController
{
    // This only captures dismissals in iOS 13.
    // However, for iOS 12 and below, we cannot dismiss a form sheet
    // without pressing a button.
    if (createImportHandler) {
        createImportHandler(nil, UIDocumentBrowserImportModeNone);
        createImportHandler = nil;
    }
}

- (void)pageSizeControllerDidCreate:(WDPageSizeController *)controller
{
    if (createImportHandler) {
        WDDrawing* drawing = [[WDDrawing alloc] initWithSize:controller.size andUnits:controller.units];
        NSData* data = [drawing inkpadRepresentation];
        if (! data) {
            // TODO: Present error
            createImportHandler(nil, UIDocumentBrowserImportModeNone);
            createImportHandler = nil;
            return;
        }
        
        // WARNING: We are using the same temporary filename every time.
        // However, we should not be doing this operation more than once at a time.
        NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:NSLocalizedString(@"Drawing.inkpad", @"Default drawing name")];
        if (! [data writeToFile:tempFile atomically:YES]) {
            // TODO: Present error
            createImportHandler(nil, UIDocumentBrowserImportModeNone);
            createImportHandler = nil;
            return;
        }
        
        createImportHandler([NSURL fileURLWithPath:tempFile], UIDocumentBrowserImportModeMove);
        createImportHandler = nil;
    }
}

- (void)pageSizeControllerDidCancel:(WDPageSizeController *)controller
{
    if (createImportHandler) {
        createImportHandler(nil, UIDocumentBrowserImportModeNone);
        createImportHandler = nil;
    }
}

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didRequestDocumentCreationWithHandler:(void (^)(NSURL * _Nullable, UIDocumentBrowserImportMode))importHandler
{
    [self dismissPopover];
    
    createImportHandler = importHandler;
    
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
    UINavigationController *nav = [storyBoard instantiateViewControllerWithIdentifier:@"create"];
    WDPageSizeController* creator = (WDPageSizeController*)nav.topViewController;
    creator.delegate = self;
    
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    nav.presentationController.delegate = self;
    [self presentViewController:nav animated:YES completion:nil];
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
    // Open the imported document immediately, but only if we are not already
    // editing another drawing.
    if (! self.presentedViewController)
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

+ (BOOL)canOpen:(NSURL *)url
{
    // The original implementation (below) used UTIs.
    // However, [NSURL getResourceValue:] is only good for file URLs,
    // and I think it also bumps into issues with security-scoped URLs.
    // We want this to be lightweight, so just check the extension instead.
    NSString* ext = url.pathExtension.lowercaseString;
    return ([ext isEqualToString:@"inkpad"] ||
            [ext isEqualToString:@"svg"] ||
            [ext isEqualToString:@"svgz"]);
    
    /*
    NSString* type;
    if ([url getResourceValue:&type forKey:NSURLTypeIdentifierKey error:nil] && type) {
        if ([type isEqualToString:@"com.taptrix.inkpad"])
            return YES;
        if ([type isEqualToString:@"public.svg-image"])
            return YES;
        if ([type isEqualToString:@"public.svgz-image"])
            return YES;
        return NO;
    } else {
        // We could not determine the file type.
        return NO;
    }
    */
}

@end
