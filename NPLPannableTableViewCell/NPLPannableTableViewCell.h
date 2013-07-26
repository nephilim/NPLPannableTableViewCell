//
//  NPLPannableTableViewCell.h
//  Toodo
//
//  Created by Nephilim on 13. 7. 12..
//  Copyright (c) 2013년 YakShavingLocus. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#import "NPLCancellablePanGestureRecognizer.h"

@interface NPLPannableTableViewCell : UITableViewCell<UIGestureRecognizerDelegate> {
    UIView* shadowView;
}

typedef void (^BlockWithPannableCell)(NPLPannableTableViewCell*);

@property (nonatomic, readwrite) UIView* panningForegroundView;
@property (nonatomic, readwrite) UIView* panningBackgroundView;
@property (copy, readwrite) BlockWithPannableCell performBeforeOpening;
@property (copy, readwrite) BlockWithPannableCell performAfterClosing;

@property CGFloat openToPosX;
@property CGFloat closeToPosX;

@property NSString* tableViewId;

+(NPLPannableTableViewCell*)prevPannedCellForTableViewIdentifier:(NSString*)tableViewId;
+(void)setPrevPannedCell:(NPLPannableTableViewCell*)tableViewCell
     tableViewIdentifier:(NSString*)tableViewId;

+(NPLPannableTableViewCell*)panningCellForTableViewIdentifier:(NSString*)tableViewId;
+(void)setPanningCell:(NPLPannableTableViewCell*)tableViewCell
  tableViewIdentifier:(NSString*)tableViewId;

+(NSString*)generateTableViewIdentifierFromTableView:(UITableView*)tableView;

-(NPLPannableTableViewCell*)prevPannedCell;
-(void)setAsPrevPannedCell;
-(void)setAsPanningCell;
-(CGFloat)panningDistanceThreshold;

-(void)panOpen;
-(void)panClose:(BOOL)removePrevPannedCell;
-(void)panView:(UIView *)view
           toX:(float)x
      duration:(float)sec
    completion:(void (^)(BOOL finished)) completionBlock;

-(BOOL)isPanningOpenThresholdWithCurrentPos:(CGPoint)currentPos startPos:(CGPoint)startPos;
-(BOOL)isPanningCloseThresholdWithCurrentPos:(CGPoint)currentPos startPos:(CGPoint)startPos;

-(id)initWithReuseIdentifier:(NSString*)reuseIdentifier         // reuse identifier
                  foreground:(UIView*)foreground                // foreground view of the cell
                  background:(UIView*)background                // background view revealed when the cell is opened
                  openToPosX:(CGFloat)openToX                   // x position of the right end in cell when it opened
                 closeToPosX:(CGFloat)closeToX                  // x position of the left end in cell when it closed
         tableViewIdentifier:(NSString*)tableViewId;            // table view id string for check previously panned cell

-(BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;

@end
