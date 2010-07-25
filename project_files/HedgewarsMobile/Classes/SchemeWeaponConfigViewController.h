//
//  SchemeWeaponConfigViewController.h
//  Hedgewars
//
//  Created by Vittorio on 13/06/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface SchemeWeaponConfigViewController : UITableViewController {
    NSArray *listOfSchemes;
    NSArray *listOfWeapons;
    
    NSIndexPath *lastIndexPath_sc;
    NSIndexPath *lastIndexPath_we;

    NSString *selectedScheme;
    NSString *selectedWeapon;
}

@property (nonatomic, retain) NSArray *listOfSchemes;
@property (nonatomic, retain) NSArray *listOfWeapons;
@property (nonatomic,retain) NSIndexPath *lastIndexPath_sc;
@property (nonatomic,retain) NSIndexPath *lastIndexPath_we;
@property (nonatomic,retain) NSString *selectedScheme;
@property (nonatomic,retain) NSString *selectedWeapon;

@end
