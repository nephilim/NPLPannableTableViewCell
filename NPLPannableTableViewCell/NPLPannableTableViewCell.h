//
//  NPLPannableTableViewCell.h
//
//  Created by Nephilim on 13. 7. 12..
//  Copyright (c) 2013 YakShavingLocus. All rights reserved.
//

#define AUTOGENERATE_GROUP_ID           nil
#define DEFAULT_PANNING_DURATION_FAST   0.05
#define DEFAULT_PANNING_DURATION_NORMAL 0.1

#include <AvailabilityMacros.h>

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#import "Entity/CellLocation.h"
#import "Entity/NPLCancellablePanGestureRecognizer.h"

typedef enum _ViewLocation {
    VIEW_LOCATION_FOREGROUND,
    VIEW_LOCATION_BACKGROUND
} ViewLocation;

typedef enum _OpeningDirection {
    OPENING_DIRECTION_NONE,
    OPENING_DIRECTION_LEFT,
    OPENING_DIRECTION_RIGHT,
    OPENING_DIRECTION_UP,
    OPENING_DIRECTION_DOWN
} NPLCellOpeningDirection;

@interface NPLPannableTableViewCell : UITableViewCell <UIGestureRecognizerDelegate> {
    UIView *shadowView;
}

typedef void (^BlockWithPannableCell)(NPLPannableTableViewCell *);

@property(nonatomic, readwrite) UIView *panningForegroundView;
@property(nonatomic, readwrite) UIView *panningBackgroundView;

@property(copy) BlockWithPannableCell performBeforeOpening DEPRECATED_ATTRIBUTE;
@property(copy) BlockWithPannableCell performAfterClosing DEPRECATED_ATTRIBUTE;

@property CGPoint openToPos;
@property CGPoint closeToPos;
@property (readonly) NPLCellOpeningDirection openingDirection;

@property (readonly) CGFloat normalDuration;
@property (readonly) CGFloat fastDuration;

#pragma mark - attribute related to table view behavior

@property(nonatomic, readonly, weak) UITableView *tableView;
@property(nonatomic, readonly, strong) NSString *reuseIndentifier;
@property(nonatomic, readonly, strong) NSString *groupId;

#pragma mark - getters for panning event handler

@property(copy, readonly) void (^beforeOpenEventHandler)(void);
@property(copy, readonly) void (^afterOpenEventHandler)(BOOL);
@property(copy, readonly) void (^beforeCloseEventHandler)(void);
@property(copy, readonly) void (^afterCloseEventHandler)(BOOL);

@property(copy, readwrite) void (^openingEffect)(UIView* foreground, UIView* background);
@property(copy, readwrite) void (^closingEffect)(UIView* foreground, UIView* background);

#pragma mark - comprehensive setter for event handler

- (void)setDefaultEventHandlersOnBeforeOpen:(void (^)())beforeOpenHandler
                                onAfterOpen:(void (^)(BOOL finished))afterOpenHandler
                              onBeforeClose:(void (^)())beforeCloseHandler
                               onAfterClose:(void (^)(BOOL finished))afterCloseHandler;

#pragma mark - panning method definition

+ (CellLocation *)prevPannedCellLocationForGroupId:(NSString *)groupId;

+ (void)setPrevPannedIndexPath:(NSIndexPath *)indexPath
                     tableView:(UITableView *)tableView
                    forGroupId:(NSString *)groupId;

+ (NPLPannableTableViewCell *)panningCellForGroupId:(NSString *)groupId;

+ (void)setPanningCellIndexPath:(NSIndexPath *)indexPath
                      tableView:(UITableView *)tableView
                     forGroupId:(NSString *)groupId;

- (NPLCellOpeningDirection)directionWithStartPos:(CGPoint)startPos
                                   EndPos:(CGPoint)endPos;

+ (NSString *)generateTableViewIdentifierFromTableView:(UITableView *)tableView;

- (void)setAsPrevPannedIndexPath;
- (void)setAsPanningCell;
- (CGFloat)panningDistanceThreshold;

# pragma mark panning open/close

# pragma mark pan open

- (void)panOpen DEPRECATED_ATTRIBUTE;

- (void)panOpenForeground;

- (void)panOpenForegroundTo:(CGPoint)pos
                   duration:(CGFloat)duration;

- (void)panOpenForegroundTo:(CGPoint)pos
                   duration:(CGFloat)duration
                    onStart:(void (^)(void))startHandler
                 onComplete:(void (^)(BOOL))completeHandler;
# pragma mark pan close

- (void)panClose:(BOOL)removePrevPannedCell;

# pragma mark fundamental behaviors for panning
- (void)panWithView:(ViewLocation)viewLocation
              toPos:(CGPoint)pos
           duration:(CGFloat)duration
            onStart:(void (^)(void))startHandler
         onComplete:(void (^)(BOOL))completeHandler;

- (void)panWithView:(ViewLocation)viewLocation from:(CGPoint)fromPos to:(CGPoint)toPos duration:(CGFloat)duration onStart:(void (^)(void))startHandler onComplete:(void (^)(BOOL))completeHandler;

- (void)translateWithView:(ViewLocation)viewLocation fromPos:(CGPoint)fromPos toPos:(CGPoint)toPos duration:(CGFloat)duration delay:(CGFloat)delay animationCurve:(UIViewAnimationCurve)curve onStart:(void (^)(void))startHandler onComplete:(void (^)(BOOL))completeHandler;

- (void)panView:(UIView *)view
            toX:(float)x
       duration:(float)sec
     completion:(void (^)(BOOL finished))completionBlock    DEPRECATED_ATTRIBUTE;

- (BOOL)isPanningOpenThresholdWithCurrentPos:(CGPoint)currentPos
                                    startPos:(CGPoint)startPos;

- (BOOL)isPanningCloseThresholdWithCurrentPos:(CGPoint)currentPos
                                     startPos:(CGPoint)startPos;

- (CGFloat)distanceByDirection:(NPLCellOpeningDirection)direction
                       fromPos:(CGPoint)fromPos
                         toPos:(CGPoint)toPos;

- (CGPoint)calibrateWithOriginalPos:(CGPoint)original
                    panningStartPos:(CGPoint)panningStartPos
                      panningEndPos:(CGPoint)panningEndPos;

- (instancetype)initWithFrame:(CGRect)frame
              reuseIdentifier:(NSString *)reuseIdentifier
                    tableView:(UITableView *)tableView
                      groupId:(NSString *)groupId;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
                   foreground:(UIView *)foreground
                   background:(UIView *)background
                    openToPos:(CGPoint)openToPos
                   closeToPos:(CGPoint)closeToPos
                    tableView:(UITableView *)tableViewId
                      groupId:(NSString *)groupId;            // table view id string for close previously panned cell

- (void)setForegroundView:(UIView *)foreground
           backgroundView:(UIView *)background
                   openTo:(CGPoint)openToPos
                  closeTo:(CGPoint)closeToPos;          // foreground view will be initially located to close

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;

- (void)resetToInitPositionAt:(NSIndexPath *)indexPath;


@end
