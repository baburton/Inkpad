//
//  WDAppDelegate.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//  Copyright (c) 2020 Ben Burton
//

#import <UIKit/UIKit.h>
#if 0 // bab: no dropbox
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#endif

@interface WDAppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, copy) void (^performAfterDropboxLoginBlock)(void);

#if 0 // bab: no dropbox
- (void) unlinkDropbox;
#endif

@end

#if 0 // bab: no dropbox
extern NSString *WDDropboxWasUnlinkedNotification;
#endif
