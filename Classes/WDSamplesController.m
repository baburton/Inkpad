//
//  WDSamplesController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//  Copyright (c) 2020 Ben Burton
//

#import "WDSamplesController.h"
#import "WDDrawing.h"

@interface WDSamplesController ()
@property (nonatomic, copy)     NSArray             *sampleURLs;
@property (nonatomic, strong)   NSMutableSet        *selectedURLs;
@property (nonatomic, strong)   NSMutableDictionary *cachedThumbnails;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *importButton;
@end

#pragma mark -

@implementation WDSampleCell

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    UIView* selectedBackground = [[UIView alloc] initWithFrame:self.bounds];
    selectedBackground.backgroundColor = [UIColor lightGrayColor];
    self.selectedBackgroundView = selectedBackground;
}

@end

#pragma mark -

@implementation WDSamplesController

@synthesize cachedThumbnails;
@synthesize delegate;
@synthesize importButton;
@synthesize sampleURLs;
@synthesize selectedURLs;

#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.importButton = self.navigationItem.rightBarButtonItem;
    self.importButton.enabled = NO;
    
    self.selectedURLs = [NSMutableSet set];
    self.cachedThumbnails = [NSMutableDictionary dictionary];
    self.sampleURLs = [[NSBundle mainBundle] URLsForResourcesWithExtension:@"inkpad" subdirectory:@"Samples"];

    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.allowsMultipleSelection = YES;
}

#pragma mark -

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    WDSampleCell* cell = (WDSampleCell*)[collectionView dequeueReusableCellWithReuseIdentifier:@"sample" forIndexPath:indexPath];
  
    // add a slight shadow to the image view
    CALayer *caLayer = cell.image.layer;
    caLayer.shadowOpacity = 0.25;
    caLayer.shadowOffset = CGSizeMake(0,1);
    caLayer.shadowRadius = 2;
    
    NSURL *sampleURL = (self.sampleURLs)[indexPath.row];
    cell.text.text = sampleURL.lastPathComponent.stringByDeletingPathExtension;
    cell.image.image = [self thumbnailForURL:sampleURL];
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSURL *sampleURL = (self.sampleURLs)[indexPath.row];
    if (! [self.selectedURLs containsObject:sampleURL]) {
        [self.selectedURLs addObject:sampleURL];
    }

    [self updateImportButton];
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSURL *sampleURL = (self.sampleURLs)[indexPath.row];
    if ([self.selectedURLs containsObject:sampleURL]) {
        [self.selectedURLs removeObject:sampleURL];
    }

    [self updateImportButton];
}

- (void)updateImportButton
{
    if (self.selectedURLs.count < 1) {
        self.importButton.title = NSLocalizedString(@"Import", @"Import");
    } else {
        NSString *format = NSLocalizedString(@"Import %lu", @"Import %lu");
        self.importButton.title = [NSString stringWithFormat:format, (unsigned long)self.selectedURLs.count];
    }

    self.importButton.enabled = self.selectedURLs.count > 0 ? YES : NO;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.sampleURLs.count;
}

- (UIImage *) thumbnailForURL:(NSURL *)sampleURL
{
    UIImage *thumbnail = (self.cachedThumbnails)[sampleURL.path];
    
    if (!thumbnail) {
        NSData              *data = [NSData dataWithContentsOfURL:sampleURL]; 
        NSKeyedUnarchiver   *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        NSData              *thumbData = [unarchiver decodeObjectForKey:WDThumbnailKey];
        
        [unarchiver finishDecoding];
        
        thumbnail = [[UIImage alloc] initWithData:thumbData];
        (self.cachedThumbnails)[sampleURL.path] = thumbnail;
    } 
    
    return thumbnail;
}

#pragma mark -

- (IBAction)import:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        [self.delegate samplesController:self didSelectURLs:[self.selectedURLs allObjects]];
    }];
}

- (IBAction)importAll:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:^{
        [self.delegate samplesController:self didSelectURLs:self.sampleURLs];
    }];
}

@end
