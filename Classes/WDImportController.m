//
//  WDImportController.m
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

#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#import "UIImage+Additions.h"
#import "WDAppDelegate.h"
#import "WDBrowserController.h"
#import "WDImportController.h"
#import "UIBarButtonItem+Additions.h"

DBFILESThumbnailSize* fetchThumbnailSize = nil;
DBFILESThumbnailFormat* fetchThumbnailFormat = nil;

@interface WDImportController ()
- (WDImportController *)subdirectoryImportControllerForPath:(NSString *)subdirectoryPath;
- (NSArray *)toolbarItems;
- (UIImage *) iconForPathExtension:(NSString *)pathExtension;
- (void)failedLoadingMissingSubdirectory:(NSNotification *)notification;
- (NSString *) importButtonTitle;
@end

static NSString * const kDropboxThumbSizeLarge = @"large";
static NSString * const WDDropboxLastPathVisited = @"WDDropboxLastPathVisited";
static NSString * const WDDropboxSubdirectoryMissingNotification = @"WDDropboxSubdirectoryMissingNotification";

@implementation WDImportController

@synthesize remotePath = remotePath_;
@synthesize browser = browser_;

+ (NSSet *) supportedImageFormats
{
    static NSSet *imageFormats_ = nil;
    
    if (!imageFormats_) {
        NSArray *temp = [NSArray arrayWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"ImportFormats" withExtension:@"plist"]];
        imageFormats_ = [[NSSet alloc] initWithArray:temp];
    }
    
    return imageFormats_;
}

+ (BOOL) canImportType:(NSString *)extension
{
    NSString *lowercase = [extension lowercaseString];
    
    if ([lowercase isEqualToString:@"inkpad"]) {
        return YES;
    }
    
    if ([self isFontType:lowercase]) {
        return YES;
    }

    return [[WDImportController supportedImageFormats] containsObject:lowercase];
}

+ (BOOL) isFontType:(NSString *)extension
{
    return [[NSSet setWithObjects:@"ttf", @"otf", nil] containsObject:extension];
}

#pragma mark -

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil 
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self) {
		return nil;
		
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(failedLoadingMissingSubdirectory:) name:WDDropboxSubdirectoryMissingNotification object:nil];
	
	selectedItems_ = [[NSMutableSet<DBFILESFileMetadata*> alloc] init];
	itemsFailedImageLoading_ = [[NSMutableSet alloc] init];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *basePath = [[fm URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL] path];
	imageCacheDirectory_ = [basePath stringByAppendingString:@"/Dropbox_Icons/"];
	
	BOOL isDirectory = NO;
	if (![fm fileExistsAtPath:imageCacheDirectory_ isDirectory:&isDirectory] || !isDirectory) {
		[fm createDirectoryAtPath:imageCacheDirectory_ withIntermediateDirectories:YES attributes:nil error:NULL];
	}
	
    dropboxClient_ = [DBClientsManager authorizedClient];
    
	importButton_ = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Import", @"Import")
                                                     style:UIBarButtonItemStyleDone target:self
                                                    action:@selector(importSelectedItems:)];
	self.navigationItem.rightBarButtonItem = importButton_;
    importButton_.enabled = NO;
    
    self.toolbarItems = [self toolbarItems];
	
    self.preferredContentSize = CGSizeMake(320, 480);
    
    return self;
}

#pragma mark -

- (void) viewDidLoad
{
    [super viewDidLoad];

    [self.navigationController setToolbarHidden:NO];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Regarding paths:
    // - Dropbox requires the root path to be specified as "" (no slash),
    //   but all subfolders to be specified in the form "/foo/bar" (with an initial slash).
    // - What looks like the root path to us is actually the app folder on dropbox.

	// first pass - push last viewed directory, or default to app directory (which to our client is just the root).
	if (remotePath_ == nil) {
		self.remotePath = @"";
		isRoot_ = YES;
		
		NSString *lastPathVisited = [[NSUserDefaults standardUserDefaults] stringForKey:WDDropboxLastPathVisited];
        if ((! lastPathVisited) || lastPathVisited.length == 0) {
            // Use the root folder (which is really the app folder on dropbox).
			[activityIndicator_ startAnimating];
            [self fetchFolderContents:remotePath_];
		} else if (lastPathVisited.length > 1) {
            NSString *currentPath = @"/";
			NSArray *pathComponents = [lastPathVisited componentsSeparatedByString:@"/"];
			for (NSString *pathComponent in pathComponents) {				
				if (pathComponent.length == 0) { // first component is an empty string
					continue;
				}
				currentPath = [currentPath stringByAppendingPathComponent:pathComponent];
                
				WDImportController *subdirectoryImportController = [self subdirectoryImportControllerForPath:currentPath];
				[self.navigationController pushViewController:subdirectoryImportController animated:NO];
			}
		}

	// pushed or popped-to view controller
	} else {
		[activityIndicator_ startAnimating];
        [self fetchFolderContents:remotePath_];
	}
}

- (void)viewWillDisappear:(BOOL)animated
{
	[[NSUserDefaults standardUserDefaults] setObject:remotePath_ forKey:WDDropboxLastPathVisited];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[selectedItems_ removeAllObjects];
    
    [super viewWillDisappear:animated];
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [dropboxItems_ count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{	
	DBFILESMetadata *dropboxItem = dropboxItems_[indexPath.row];
	UITableViewCell *cell = nil;
	
	if ([dropboxItem isKindOfClass:[DBFILESFolderMetadata class]]) {
		static NSString *kDirectoryCellIdentifier = @"kDirectoryCellIdentifier";
		cell = [tableView dequeueReusableCellWithIdentifier:kDirectoryCellIdentifier];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kDirectoryCellIdentifier];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.imageView.image = [UIImage imageNamed:@"dropbox_icon_directory.png"];
		}
	} else {
        DBFILESFileMetadata *dropboxFile = (DBFILESFileMetadata*)dropboxItem;
        
		static NSString *kItemCellIdentifier = @"kItemCellIdentifier";
		cell = [contentsTable_ dequeueReusableCellWithIdentifier:kItemCellIdentifier];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kItemCellIdentifier];
		}
		
        BOOL supportedFile = [WDImportController canImportType:dropboxItem.name.pathExtension];
		cell.textLabel.textColor = supportedFile ? [UIColor blackColor] : [UIColor grayColor];
		cell.userInteractionEnabled = supportedFile ? YES : NO;
		cell.imageView.image = [self iconForPathExtension:dropboxItem.name.pathExtension];
		
        // Load the thumbnail, if dropbox has one.
        if (! fetchThumbnailSize)
            fetchThumbnailSize = [[DBFILESThumbnailSize alloc] initWithW64h64];
        if (! fetchThumbnailFormat)
            fetchThumbnailFormat = [[DBFILESThumbnailFormat alloc] initWithPng];
        
        NSString    *cachedImagePath = [NSString stringWithFormat:@"%@/%@_%ld@2x.png",
                                        imageCacheDirectory_, dropboxFile.id_, (long)fetchThumbnailSize.tag];
        NSLog(@"Cached: %@", cachedImagePath);
        UIImage     *dropboxItemIcon = [UIImage imageWithContentsOfFile:cachedImagePath];
        BOOL        outOfDate = NO;
        
        if (dropboxItemIcon) {
            // TODO: Smaller thumbnails cause the text labels to be mis-aligned.
            // Probably the fix for this is to create a custom table cell,
            // with appropriate constraints on the UIImageView.
            cell.imageView.image = dropboxItemIcon;

            // we have a cached thumbnail, see if it's out of date relative to Dropbox
            NSFileManager *fm = [NSFileManager defaultManager];
            NSDictionary *attrs = [fm attributesOfItemAtPath:cachedImagePath error:NULL];
            NSDate *cachedDate = attrs[NSFileModificationDate];
            outOfDate = !cachedDate || [cachedDate compare:dropboxFile.serverModified] == NSOrderedAscending;
        }
        
        if (!dropboxItemIcon || outOfDate) {
            [[dropboxClient_.filesRoutes getThumbnailUrl:dropboxFile.id_
                                                  format:nil
                                                    size:fetchThumbnailSize
                                                    mode:nil
                                               overwrite:YES
                                             destination:[NSURL fileURLWithPath:cachedImagePath]]
             setResponseBlock:^(DBFILESFileMetadata * _Nullable result, DBFILESThumbnailError * _Nullable routeError, DBRequestError * _Nullable networkError, NSURL * _Nonnull destination) {
                if (routeError || networkError || ! result) {
                    // Silently ignore missing or failed thumbnails.
                } else {
                    UIImage *image = [UIImage imageWithContentsOfFile:cachedImagePath];
                    if (image) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self->contentsTable_ reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                        });
                    }
                }
            }];
        }
        
        // always need to update the cell checkmark since they're reused
        [cell setAccessoryType:[selectedItems_ containsObject:dropboxFile] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone];
	}

    cell.textLabel.text = dropboxItem.name;
	return cell;
}

#pragma mark -
#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	DBFILESMetadata *selectedItem = dropboxItems_[indexPath.row];

	if ([selectedItem isKindOfClass:[DBFILESFolderMetadata class]]) {
        NSString* nextPath = (self.remotePath.length == 0 ? @"/" : self.remotePath);
        nextPath = [nextPath stringByAppendingPathComponent:selectedItem.name];
        
        WDImportController *subdirectoryImportController = [self subdirectoryImportControllerForPath:nextPath];
		[self.navigationController pushViewController:subdirectoryImportController animated:YES];
	} else if ([selectedItem isKindOfClass:[DBFILESFileMetadata class]]) {
        DBFILESFileMetadata *selectedFile = (DBFILESFileMetadata*)selectedItem;

        if (![selectedItems_ containsObject:selectedFile]) {
			[selectedItems_ addObject:selectedFile];
			[[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
		} else {
			[selectedItems_ removeObject:selectedFile];
			[[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryNone];
		}
	}
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	[importButton_ setTitle:[self importButtonTitle]];
	[importButton_ setEnabled:selectedItems_.count > 0 ? YES : NO];
}

#pragma mark -
#pragma mark Notifications

- (void)failedLoadingMissingSubdirectory:(NSNotification *)notification
{
	if (!isRoot_) {
		return;
	}
    
	[self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark -

- (void) fetchFolderContents:(NSString*)dropboxPath
{
    [[dropboxClient_.filesRoutes listFolder:dropboxPath] setResponseBlock:^(DBFILESListFolderResult *response, DBFILESListFolderError *routeError, DBRequestError *networkError) {
        if (routeError || networkError || ! response) {
            if (networkError && networkError.tag == DBRequestErrorAuth) {
                // We have already checked for a valid login.
                // However: if the user is logged in but the app folder is missing,
                // we get an authentication error here.
                NSLog(@"Dropbox authentication error: relinking");
                
                UIBarButtonItem* importFrom = self.popoverPresentationController.barButtonItem;
                [self->browser_ dismissPopover];
                
                // Unlink dropbox.
                // Do this directly through the dropbox API to avoid a confirmation box.
                [DBClientsManager unlinkAndResetClients];
                [[NSNotificationCenter defaultCenter] postNotificationName:WDDropboxWasUnlinkedNotification object:self];
                
                // Reopen the import panel, which should prompt to relink with dropbox again.
                [self->browser_ showDropboxImportPanel:importFrom];
                return;
            }
            if (dropboxPath.length > 0 /* not the root */) {
                NSString *lastVisitedPath = [[NSUserDefaults standardUserDefaults] valueForKey:WDDropboxLastPathVisited];
                if ([dropboxPath isEqualToString:lastVisitedPath]) {
                    // We tried to open the subfolder that we were in last time, but something broke.
                    // Just pop back to the app folder (which to us looks like the root).
                    [[NSNotificationCenter defaultCenter] postNotificationName:WDDropboxSubdirectoryMissingNotification object:nil];
                    return;
                }
            }
            // TODO: We should really show some kind of error condition to the user.
            [self->activityIndicator_ stopAnimating];

            if (routeError)
                NSLog(@"Dropbox folder load encountered route error: %@", routeError);
            if (networkError)
                NSLog(@"Dropbox folder load encountered network error: %@", networkError);
            if (! (routeError || networkError))
                NSLog(@"Dropbox folder load returned no response");
        } else {
            [self fetchFolderContentsResponse:response];
        }
    }];
}

- (void) fetchFolderContentsResponse:(DBFILESListFolderResult*)response
{
    if ([response.hasMore boolValue]) {
        [[dropboxClient_.filesRoutes listFolderContinue:response.cursor] setResponseBlock:^(DBFILESListFolderResult *response, DBFILESListFolderContinueError *routeError, DBRequestError *networkError) {
            if (routeError || networkError || ! response) {
                // TODO: We should really show some kind of error condition to the user.
                [self->activityIndicator_ stopAnimating];

                if (routeError)
                    NSLog(@"Dropbox folder load encountered route error: %@", routeError);
                if (networkError)
                    NSLog(@"Dropbox folder load encountered network error: %@", networkError);
                if (! (routeError || networkError))
                    NSLog(@"Dropbox folder load returned no response");
            } else {
                [self fetchFolderContentsResponse:response];
            }
        }];
    } else {
        [activityIndicator_ stopAnimating];
        
        dropboxItems_ = [response.entries sortedArrayUsingComparator:^NSComparisonResult(DBFILESMetadata*  _Nonnull obj1, DBFILESMetadata*  _Nonnull obj2) {
            if ([obj1 isKindOfClass:DBFILESFolderMetadata.class] && [obj2 isKindOfClass:DBFILESFileMetadata.class])
                return NSOrderedAscending;
            if ([obj1 isKindOfClass:DBFILESFileMetadata.class] && [obj2 isKindOfClass:DBFILESFolderMetadata.class])
                return NSOrderedDescending;
            return [obj1.name localizedCaseInsensitiveCompare:obj2.name];
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->contentsTable_ reloadData];
        });
    }
}

- (void) importSelectedItems:(id)sender
{
    [browser_ importController:self didSelectDropboxItems:[selectedItems_ allObjects]];
}

- (void) unlinkDropbox:(id)sender
{
    [browser_ unlinkDropbox:sender];
}

#pragma mark -

- (WDImportController *)subdirectoryImportControllerForPath:(NSString *)subdirectoryPath
{
	WDImportController *subdirectoryImportController = [[WDImportController alloc] initWithNibName:@"Import" bundle:nil];
	subdirectoryImportController.remotePath = subdirectoryPath;
	subdirectoryImportController.title = [subdirectoryPath lastPathComponent];
	subdirectoryImportController.browser = self.browser;

	return subdirectoryImportController;
}

- (NSArray *)toolbarItems
{
    UIBarButtonItem *flexibleSpaceItem = [UIBarButtonItem flexibleItem];
    UIBarButtonItem *unlinkButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Unlink Dropbox", @"Unlink Dropbox") style:UIBarButtonItemStylePlain target:self action:@selector(unlinkDropbox:)];

    NSArray *toolbarItems = @[flexibleSpaceItem, unlinkButtonItem];


    return toolbarItems;
}

- (NSString *) importButtonTitle
{
    NSString *title = nil;
    if (selectedItems_.count < 1) {
        title = NSLocalizedString(@"Import", @"Import");
    } else {
        NSString *format = NSLocalizedString(@"Import %lu", @"Import %lu");
        title = [NSString stringWithFormat:format, (unsigned long)selectedItems_.count];
    }
    return title;
}

- (UIImage *) iconForPathExtension:(NSString *)pathExtension
{
	if ([pathExtension caseInsensitiveCompare:@"inkpad"] == NSOrderedSame) {
		return [UIImage imageNamed:@"dropbox_icon_inkpad.png"];
	} else if ([WDImportController isFontType:[pathExtension lowercaseString]]) {
		return [UIImage imageNamed:@"dropbox_icon_font.png"];
	} else if ([pathExtension caseInsensitiveCompare:@"svg"] == NSOrderedSame) {
		return [UIImage imageNamed:@"dropbox_icon_svg.png"];
	} else if ([pathExtension caseInsensitiveCompare:@"svgz"] == NSOrderedSame) {
		return [UIImage imageNamed:@"dropbox_icon_svg.png"];
	} else if ([WDImportController canImportType:pathExtension]) {
		return [UIImage imageNamed:@"dropbox_icon_generic.png"];
	} else {
		return [UIImage imageNamed:@"dropbox_icon_unsupported.png"];
	}
}

#pragma mark -

- (void)dealloc 
{	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
