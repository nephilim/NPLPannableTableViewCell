//
//  NPLPannableTableViewCell.h
//  Toodo
//
//  Created by Nephilim on 13. 7. 12..
//  Copyright (c) 2013년 YakShavingLocus. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#import "Entity/CellLocation.h"
#import "Entity/NPLCancellablePanGestureRecognizer.h"

#define AUTOGENERATE_GROUP_ID nil

@interface NPLPannableTableViewCell : UITableViewCell <UIGestureRecognizerDelegate> {
    UIView *shadowView;
}

typedef void (^BlockWithPannableCell)(NPLPannableTableViewCell *);

@property(nonatomic, readwrite) UIView *panningForegroundView;
@property(nonatomic, readwrite) UIView *panningBackgroundView;
@property(copy, readwrite) BlockWithPannableCell performBeforeOpening;
@property(copy, readwrite) BlockWithPannableCell performAfterClosing;

@property CGFloat openToPosX;
@property CGFloat closeToPosX;

@property(nonatomic, readonly, weak) UITableView *tableView;
@property(nonatomic, readonly, strong) NSString *reuseIndentifier;
@property(nonatomic, readonly, strong) NSString *groupId;

+ (CellLocation *)prevPannedCellLocationForGroupId:(NSString *)groupId;

+ (void)setPrevPannedIndexPath:(NSIndexPath *)indexPath
                     tableView:(UITableView *)tableView
                    forGroupId:(NSString *)groupId;

+ (NPLPannableTableViewCell *)panningCellForGroupId:(NSString *)groupId;

+ (void)setPanningCellIndexPath:(NSIndexPath *)indexPath
                      tableView:(UITableView *)tableView
                     forGroupId:(NSString *)groupId;

+ (NSString *)generateTableViewIdentifierFromTableView:(UITableView *)tableView;

- (void)setAsPrevPannedIndexPath;

- (void)setAsPanningCell;

- (CGFloat)panningDistanceThreshold;

- (void)panOpen;

- (void)panClose:(BOOL)removePrevPannedCell;

- (void)panView:(UIView *)view
            toX:(float)x
       duration:(float)sec
     completion:(void (^)(BOOL finished))completionBlock;

- (BOOL)isPanningOpenThresholdWithCurrentPos:(CGPoint)currentPos startPos:(CGPoint)startPos;

- (BOOL)isPanningCloseThresholdWithCurrentPos:(CGPoint)currentPos startPos:(CGPoint)startPos;

- (instancetype)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier tableView:(UITableView *)tableView groupId:(NSString *)groupId;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
                   foreground:(UIView *)foreground
                   background:(UIView *)background
                   openToPosX:(CGFloat)openToX
                  closeToPosX:(CGFloat)closeToX
                    tableView:(UITableView *)tableViewId
                      groupId:(NSString *)groupId;            // table view id string for check previously panned cell

- (void)setupWithForegroundView:(UIView *)foreground backgroundView:(UIView *)background openToPosX:(CGFloat)openToX closeToPosX:(CGFloat)closeToX;

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;

- (void)resetToInitPositionAt:(NSIndexPath *)indexPath;
@end
