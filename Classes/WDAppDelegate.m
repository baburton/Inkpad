//
//  WDAppDelegate.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//  Copyright (c) 2020 Ben Burton
//

#import "WDAppDelegate.h"
#import "WDBrowserController.h"
#import "WDCanvasController.h"
#import "WDColor.h"
#import "WDDrawing.h"
#import "WDFontManager.h"
#import "WDGradient.h"
#import "WDInspectableProperties.h"

NSString* keyCreatedICloudFolder = @"CreatedICloudFolder";

@implementation WDAppDelegate

@synthesize window;

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey,id> *)launchOptions
{
    [self setupDocuments];
    
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey,id> *)launchOptions
{
    // Load the fonts at startup. Dispatch this call at the end of the main queue;
    // It will then dispatch the real work on another queue after the app launches.
    dispatch_async(dispatch_get_main_queue(), ^{
        [WDFontManager sharedInstance];
    });
    
    [self clearTempDirectory];
    
    [self setupDefaults];
    
    if (launchOptions) {
        NSURL *url = launchOptions[UIApplicationLaunchOptionsURLKey];
        
        if (url) {
            // So:
            // - Calling [self validFile:url] is failing. I expect this is because we
            //   need to treat url as a security-scoped URL (and currently we do not).
            // - However: we shouldn't be reading potentially large files at this point
            //   in the app lifecycle anyway. So instead just check the file type for now.
            // return [self validFile:url];
            return [WDBrowserController canOpen:url];
        }
    }
    
    return YES;
}

- (BOOL) validFile:(NSURL *)url
{
    WDDrawing *drawing = nil;
    
    @try {
        NSData *data = [NSData dataWithContentsOfURL:url];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        drawing = [unarchiver decodeObjectForKey:WDDrawingKey];
        [unarchiver finishDecoding];
    } @catch (NSException *exception) {
    } @finally {
    }
    
    return (drawing ? YES : NO);
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    WDBrowserController *browser = (WDBrowserController *)self.window.rootViewController;
    [browser revealDocumentAtURL:url importIfNeeded:YES completion:^(NSURL * _Nullable revealedDocumentURL, NSError * _Nullable error) {
        if (error) {
            UIAlertController *alertView = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Could Not Open", @"Could Not Open")
                                                                               message:NSLocalizedString(@"Inkpad could not open the requested drawing.",
                                                                                                         @"Inkpad could not open the requested drawing.")
                                                                        preferredStyle:UIAlertControllerStyleAlert];
            [alertView addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Close", @"Close") style:UIAlertActionStyleCancel handler:nil]];
            [self.window.rootViewController presentViewController:alertView animated:YES completion:nil];
        } else {
            [browser presentDocumentAtURL:revealedDocumentURL];
        }
    }];
    return YES;
}

- (void) clearTempDirectory
{
    NSFileManager   *fm = [NSFileManager defaultManager];
    NSURL           *tmpURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSArray         *files = [fm contentsOfDirectoryAtURL:tmpURL includingPropertiesForKeys:[NSArray array] options:0 error:NULL];
    
    for (NSURL *url in files) {
        [fm removeItemAtURL:url error:nil];
    }
}

- (void) setupDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *defaultPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Defaults.plist"];
    [defaults registerDefaults:[NSDictionary dictionaryWithContentsOfFile:defaultPath]];
    
    // Install valid defaults for various colors/gradients if necessary. These can't be encoded in the Defaults.plist.
    if (![defaults objectForKey:WDStrokeColorProperty]) {
        NSData *value = [NSKeyedArchiver archivedDataWithRootObject:[WDColor blackColor]];
        [defaults setObject:value forKey:WDStrokeColorProperty];
    }
    
    if (![defaults objectForKey:WDFillProperty]) {
        NSData *value = [NSKeyedArchiver archivedDataWithRootObject:[WDColor whiteColor]];
        [defaults setObject:value forKey:WDFillProperty];
    }
    
    if (![defaults objectForKey:WDFillColorProperty]) {
        NSData *value = [NSKeyedArchiver archivedDataWithRootObject:[WDColor whiteColor]];
        [defaults setObject:value forKey:WDFillColorProperty];
    }
    
    if (![defaults objectForKey:WDFillGradientProperty]) {
        NSData *value = [NSKeyedArchiver archivedDataWithRootObject:[WDGradient defaultGradient]];
        [defaults setObject:value forKey:WDFillGradientProperty];
    }
    
    if (![defaults objectForKey:WDStrokeDashPatternProperty]) {
        NSArray *dashes = @[];
        [defaults setObject:dashes forKey:WDStrokeDashPatternProperty];
    }
    
    if (![defaults objectForKey:WDShadowColorProperty]) {
        NSData *value = [NSKeyedArchiver archivedDataWithRootObject:[WDColor colorWithRed:0 green:0 blue:0 alpha:0.333f]];
        [defaults setObject:value forKey:WDShadowColorProperty];
    }
}

- (void) setupDocuments
{
    // Create the iCloud folder if we can, and (even if it was already present) fill it with samples if it's empty.
    // This is because it seems that the Files app won't show the app folder at all until it has something in it.
    //
    // Only do this once: if the user then deletes or empties the iCloud folder, we won't try to put it back.
    if (! [[NSUserDefaults standardUserDefaults] boolForKey:keyCreatedICloudFolder]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:keyCreatedICloudFolder];

        NSFileManager* fm = [NSFileManager defaultManager];
        NSURL* iCloudDocs = [[fm URLForUbiquityContainerIdentifier:nil] URLByAppendingPathComponent:@"Documents"];
        if (iCloudDocs) {
            if (! [fm fileExistsAtPath:iCloudDocs.path]) {
                [fm createDirectoryAtURL:iCloudDocs withIntermediateDirectories:YES attributes:nil error:nil];
            }
            
            if ([fm fileExistsAtPath:iCloudDocs.path]) {
                __block BOOL hasError = NO;
                NSDirectoryEnumerator* e = [fm enumeratorAtURL:iCloudDocs includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL * _Nonnull url, NSError * _Nonnull error) {
                    hasError = YES;
                    return NO; // Stop enumeration
                }];
                if (e) {
                    id first = e.nextObject;
                    if ((! hasError) && (! first)) {
                        // The folder is empty (possibly except for hidden files).
                        // Fill it with the sample drawings.
                        NSArray<NSURL*>* samples = [[NSBundle mainBundle] URLsForResourcesWithExtension:@"inkpad" subdirectory:@"Samples"];
                        for (NSURL* url in samples) {
                            // This method will not overwrite an existing file.
                            [fm copyItemAtURL:url toURL:[iCloudDocs URLByAppendingPathComponent:url.lastPathComponent] error:nil];
                        }
                    }
                }
            }
        }
    }
}

@end
