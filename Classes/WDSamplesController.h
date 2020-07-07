//
//  WDSamplesController.h
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

@protocol WDSamplesControllerDelegate;

@interface WDSampleCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (weak, nonatomic) IBOutlet UILabel *text;

@end

@interface WDSamplesController : UICollectionViewController <UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, weak) id <WDSamplesControllerDelegate> delegate;

@end

@protocol WDSamplesControllerDelegate <NSObject>
- (void) samplesController:(WDSamplesController *)controller didSelectURLs:(NSArray *)sampleURLs;
@end
