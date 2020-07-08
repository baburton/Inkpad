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

@implementation WDAppDelegate

@synthesize window;

#pragma mark -
#pragma mark Application lifecycle

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

@end
