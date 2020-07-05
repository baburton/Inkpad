//
//  WDHelpController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//  Copyright (c) 2020 Ben Burton
//

#import "WDHelpController.h"
#import <WebKit/WebKit.h>

@implementation WDHelpController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }
    
    NSString *version = [[NSBundle mainBundle] infoDictionary][(NSString *)kCFBundleVersionKey];
    
    // don't need to localize the app name
    self.navigationItem.title = [NSString stringWithFormat:@"Inkpad %@", version];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithTitle:NSLocalizedString(@"Print", @"Print")
                                             style:UIBarButtonItemStylePlain
                                             target:self
                                             action:@selector(printContent:)];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                               initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                               target:self
                                               action:@selector(dismissView:)];
    return self;
}

- (NSURL *) helpURL
{
    NSString *resource = NSLocalizedString(@"index", @"Name of Help html file");
    NSString *path = [[NSBundle mainBundle] pathForResource:resource ofType:@"html" inDirectory:@"Help"];
    return [NSURL fileURLWithPath:path isDirectory:NO];
}

- (void)loadView
{
    WKWebViewConfiguration* config = [WKWebViewConfiguration new];
    config.preferences.javaScriptEnabled = NO;
    WKWebView* webView = [[WKWebView alloc] initWithFrame:[[UIScreen mainScreen] bounds] configuration:config];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view = webView;
    [webView loadRequest:[NSURLRequest requestWithURL:[self helpURL]]];
}

- (void)dismissView:(id)sender
{
    [self.parentViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)printContent:(id)sender
{
    UIPrintInteractionController *pic = [UIPrintInteractionController sharedPrintController];
    pic.delegate = self;
    
    UIPrintInfo *printInfo = [UIPrintInfo printInfo];
    printInfo.outputType = UIPrintInfoOutputGeneral;
    printInfo.jobName = NSLocalizedString(@"Inkpad Help", @"Inkpad Help");
    pic.printInfo = printInfo;

    UIViewPrintFormatter *viewFormatter = self.view.viewPrintFormatter;
    viewFormatter.startPage = 0;
    viewFormatter.perPageContentInsets = UIEdgeInsetsMake(36.0, 36.0, 36.0, 36.0);
    pic.printFormatter = viewFormatter;
    
    [pic presentFromBarButtonItem:sender animated:YES completionHandler:nil];
}

@end
