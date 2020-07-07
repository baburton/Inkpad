//
//  WDFontLibraryController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//  Copyright (c) 2020 Ben Burton
//

#import "WDCoreTextLabel.h"
#import "WDFontLibraryController.h"
#import "WDFontManager.h"

#define kCoreTextLabelWidth      300
#define kCoreTextLabelHeight     43
#define kCoreTextLabelTag        1

@interface WDFontLibraryController () <UIDocumentPickerDelegate>
@end

@implementation WDFontLibraryController

@synthesize selectedFonts;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.selectedFonts = [NSMutableSet set];
    
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    
    self.navigationController.toolbarHidden = NO;
    self.toolbarItems = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                          [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", @"Close") style:UIBarButtonItemStyleDone target:self action:@selector(close)],
                          [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fontAdded:) name:WDFontAddedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fontDeleted:) name:WDFontDeletedNotification object:nil];
}

- (void) close
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) fontAdded:(NSNotification *)aNotification
{
    NSString    *fontName = (aNotification.userInfo)[@"name"];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[[[WDFontManager sharedInstance] userFonts] indexOfObject:fontName] inSection:0];
    
    [self.tableView beginUpdates];
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [self.tableView endUpdates];
}

- (void) fontDeleted:(NSNotification *)aNotification
{
    NSNumber    *index = (aNotification.userInfo)[@"index"];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index.integerValue inSection:0];
    
    [self.tableView beginUpdates];
    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [self.tableView endUpdates];
}

- (IBAction)addFont:(id)sender {
    UIDocumentPickerViewController* picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.opentype-font", @"public.truetype-ttf-font"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
    NSMutableArray<NSURL*>* error = [NSMutableArray<NSURL*> new];
    
    for (NSURL* url in urls) {
        BOOL alreadyInstalled = NO;
        NSString *name = [[WDFontManager sharedInstance] installUserFont:url alreadyInstalled:&alreadyInstalled];
        if (!name)
            [error addObject:url];
    }
        
    if (error.count) {
        UIAlertController *alertView = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Could Not Import", @"Could Not Import")
                                                                           message:NSLocalizedString(@"I could not import one or more of the selected fonts.",
                                                                                                     @"I could not import one or more of the selected fonts.")
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        [alertView addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Close", @"Close") style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alertView animated:YES completion:nil];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    return [[[WDFontManager sharedInstance] userFonts] count];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        WDFontManager* fm = [WDFontManager sharedInstance];
        [fm deleteUserFontWithName:fm.userFonts[indexPath.row]];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    
    WDCoreTextLabel *label = [[WDCoreTextLabel alloc] initWithFrame:CGRectMake(10, 0, kCoreTextLabelWidth - 10, kCoreTextLabelHeight)];
    [cell.contentView addSubview:label];
    
    NSString *fontName = [[WDFontManager sharedInstance] userFonts][indexPath.row];
    
    CTFontRef fontRef = [[WDFontManager sharedInstance] newFontRefForFont:fontName withSize:22];
    [label setFontRef:fontRef];
    CFRelease(fontRef);
    
    [label setText:[[WDFontManager sharedInstance] displayNameForFont:fontName]];
    
    cell.accessoryType = [selectedFonts containsObject:fontName] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    return cell;
}

@end
