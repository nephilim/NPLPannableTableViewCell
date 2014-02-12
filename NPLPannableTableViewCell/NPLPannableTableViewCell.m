//
//  NPLPannableTableViewCell.m
//  Toodo
//
//  Created by Nephilim on 13. 7. 12..
//  Copyright (c) 2013년 YakShavingLocus. All rights reserved.
//

#import "NPLPannableTableViewCell.h"

@interface NPLPannableTableViewCell(Private)

// geture recognizer handler
- (IBAction) handleCellPanning:(NPLCancellablePanGestureRecognizer*)recognizer;

// panning
- (void) panCloseWithShadow:(BOOL)shadow removePrevPannedCell:(BOOL)resetPreviousOpenCell;
- (UIView *) shadowLayerWithBound:(CGRect)bound;
//- (UIView*) singletonShadowLayer;
- (void) dropShadowOnView:(UIView*)view;
- (void) removeShadow;

// tap(zoom)
// - (void) closeExpandedCell; //TODO: clearPreviosExpandedCell option

@end

@implementation NPLPannableTableViewCell {
    CGFloat _normalDuration;
    CGFloat _fastDuration;
}

static CGFloat distanceThreshold;                       // panning distance

static NSMutableDictionary*prevPannedCellLocations = nil;      // register panned cell when it's opened,
static NSMutableDictionary*panningCellLocations = nil;         // register panning cell when user started to pan
                                                               // panning cell exist only on for each tableView set by
                                                               // users
@synthesize panningForegroundView, panningBackgroundView;
@synthesize openToPosX, closeToPosX;

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (instancetype)initWithFrame:(CGRect)frame
              reuseIdentifier:(NSString *)reuseIdentifier
                    tableView:(UITableView *)tableView
                      groupId:(NSString *)groupId
{
    self = [super initWithFrame:frame];
    if (self) {
        _reuseIndentifier = reuseIdentifier;
        _tableView = tableView;
        _groupId = (groupId == AUTOGENERATE_GROUP_ID)?
            [NPLPannableTableViewCell generateTableViewIdentifierFromTableView:tableView]:groupId;
    }
    return self;
}

// designated initialzer
// if groupId is set AUTOGENERATE_GROUP_ID,
// the group id is allocated on each table separately
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
                   foreground:(UIView *)foreground
                   background:(UIView *)background
                   openToPosX:(CGFloat)openToX
                  closeToPosX:(CGFloat)closeToX
                    tableView:(UITableView *)tableView
                      groupId:(NSString *)groupId {

    CGRect frame = self.bounds;
    self = [self initWithFrame:frame
               reuseIdentifier:reuseIdentifier
                     tableView:tableView
                       groupId:groupId];
    if (self) {
        [self setupWithForegroundView:foreground
                       backgroundView:background
                           openToPosX:openToX
                          closeToPosX:closeToX];
    }
    return self;
}

- (void)setupWithForegroundView:(UIView *)foreground
                 backgroundView:(UIView *)background
                     openToPosX:(CGFloat)openToX
                    closeToPosX:(CGFloat)closeToX
{
    self.panningForegroundView = foreground;
    self.panningBackgroundView = background;
    [self.contentView addSubview:background];
    [self.contentView addSubview:foreground];

    self.openToPosX = openToX;
    self.closeToPosX = closeToX;
//        self.tableView = tableView;
//        self.groupId = (groupId == AUTOGENERATE_GROUP_ID)?[NPLPannableTableViewCell
//                generateTableViewIdentifierFromTableView:tableView]:groupId;

    if (self.tableView.allowsSelection) {
        self.tableView.allowsSelection = NO;
        NSLog(@"Warning: TableView using pannable TableViewCell should not allow selection.");
        NSLog(@"Automatically changed the TableView not to allow selection.");
    }

    NPLCancellablePanGestureRecognizer *gestureRecognizer = [[NPLCancellablePanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handleCellPanning:)];
    [gestureRecognizer setDelegate:self];
    [self setGestureRecognizers:[NSArray arrayWithObjects:gestureRecognizer, nil]];
}

+ (NSString*)generateTableViewIdentifierFromTableView:(UITableView*)tableView
{
    NSValue* pointer= [NSValue valueWithPointer:(__bridge void *)tableView];
    return [NSString stringWithFormat:@"tbp-%@", pointer];
}

//- (NSIndexPath *)prevPannedIndexPath {
//    return [NPLPannableTableViewCell prevPannedIndexPathForTableView:self.tableView];
//}

- (void)setAsPrevPannedIndexPath
{
    NSIndexPath* indexPath = [self.tableView indexPathForCell:self];
    [NPLPannableTableViewCell setPrevPannedIndexPath:indexPath tableView:self.tableView forGroupId:self.groupId];
}

- (void)setAsPanningCell
{
    NSIndexPath* indexPath = [self.tableView indexPathForCell:self];
    [NPLPannableTableViewCell setPanningCellIndexPath:indexPath tableView:self.tableView forGroupId:self.groupId];
}

#pragma mark - Panning Gesture Recognizer start condition

- (BOOL) gestureRecognizerShouldBegin:(UIGestureRecognizer*)gestureRecognizer {
    @synchronized(self.tableView){
        BOOL shouldStart = NO;
        NPLPannableTableViewCell* panningCell = [NPLPannableTableViewCell panningCellForGroupId:self.groupId];
        if (panningCell == nil && [gestureRecognizer isKindOfClass:[NPLCancellablePanGestureRecognizer class]]) {
            
            NPLCancellablePanGestureRecognizer* panGestureRecognizer = (NPLCancellablePanGestureRecognizer*)gestureRecognizer;
            CGPoint translation = [panGestureRecognizer translationInView:self];
        
            if ( fabs(translation.x / (translation.y==0?0.01:translation.y)) > 1.2) {
                shouldStart = YES;      // will be unlocked in handleCellPanning:
            }
        }
        //NSLog(@"%d - ShouldBegin? %@", [self hash], shouldStart?@"YES":@"NO");
        return shouldStart;
    }
}

- (IBAction) handleCellPanning:(NPLCancellablePanGestureRecognizer*)gestureRecognizer {
    
    // TODO: declare static vars per table
    static CGPoint panningStartPos;
    static CGPoint cellStartPos;
    
    NPLPannableTableViewCell* panningCell = [self panningCellInGroup];

    if (panningCell != nil && self != panningCell){
        // prevent simultaneous panning gesture
        [gestureRecognizer cancel];
        return;
    }
    
    CGPoint location = [gestureRecognizer locationInView:self];
    CGFloat panToX = 0.0;
    CGPoint velocity;

    CellLocation *prevPannedCellLocation = [self prevPannedCellLocationInGroup];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:self];

    switch ([gestureRecognizer state]) {
        case UIGestureRecognizerStateBegan:
            [self setAsPanningCell];
            
            // close previously opened cell

            if( (prevPannedCellLocation != nil) &&
                (![prevPannedCellLocation isEqualWithTableView:_tableView indexPath:indexPath])) {
                NPLPannableTableViewCell *prevPannedCell = (NPLPannableTableViewCell*)
                        [prevPannedCellLocation.tableView cellForRowAtIndexPath:prevPannedCellLocation.indexPath];
                
                if(prevPannedCell) {
                    [prevPannedCell panCloseWithShadow:NO removePrevPannedCell:YES];
                } else {
                    // tableviewcell cannot be seen while it's above/below screen area
                    [self forgetPrevPannedCellLoationInGroup];
                }
            }
            
            // set panning start position
            panningStartPos.x = location.x;
            panningStartPos.y = location.y;
            cellStartPos = self.panningForegroundView.frame.origin;

            NSLog(@"cell start pos(x):%f" , cellStartPos.x);

            if (self.openingEffect) { self.openingEffect(panningForegroundView, panningBackgroundView); }
            // shadowing
            // [self dropShadowOnView:panningForegroundView];

            velocity = [gestureRecognizer velocityInView:self];
            break;
            
        case UIGestureRecognizerStateEnded:
            if([prevPannedCellLocation isEqualWithTableView:_tableView indexPath:indexPath]) {
                // user tries to close cell?
                if( [self isPanningCloseThresholdWithCurrentPos:location
                                                       startPos:panningStartPos] ) {
                    [self panCloseWithShadow:NO removePrevPannedCell:YES];            // close
                } else {
                    [self panOpenForeground];             // fail to close
                }
            } else {
                // user tries to open not-opened-yet cell
                if( [self isPanningOpenThresholdWithCurrentPos:location
                                                      startPos:panningStartPos] ) {
                    [self setAsPrevPannedIndexPath]; // open
                    [self panOpenForeground];
                } else {
                    [self panClose:NO];         // fail to open
                }
            }
            
            // unshadowing
            if (self.closingEffect) { self.closingEffect(panningForegroundView, panningBackgroundView); }
            //[self removeShadow];
            
//            panningStartPos.x = 0;
//            panningStartPos.y = 0;

            [self forgetPanningCellLocationInGroup];

            break;
            
        case UIGestureRecognizerStateChanged:
            //cancel if y position is way to far
            /*
             if( fabs(location.y - panningStartPos.y) > [self panThresholdDistY] ) {
             panningIndexPath = nil;
             panningCell = nil;
             [gestureRecognizer cancelsTouchesInView];
             [self snapView:panningForegroundView toX:0 duration:DEFAULT_PANNING_DURATION_NORMAL animated:YES];
             }
             */
            
            //get delta and move only when delta is enough.
            panToX = location.x - panningStartPos.x;
            
            //if(self == prevPannedCell) {
                // user tries to close
                /*
                 // skip not to blink
                 [self snapView:panningForegroundView
                 toX: -self.bounds.size.width +  panToX
                 duration:DEFAULT_PANNING_DURATION_NORMAL
                 completion:NULL];
                 */
            //} else
            //NSLog(@"to pos: %f", cellStartPos.x + panToX);
            //if( ![prevPannedCellLocation isEqualWithTableView:_tableView indexPath:indexPath]) {
                // user is trying to open

                /*
                [self panView:self.panningForegroundView
                          toX:panToX
                     duration:self.fastDuration
                   completion:NULL];
                 */
                [self panOpenForegroundToX:(cellStartPos.x + panToX)
                                  duration:self.fastDuration
                                   onStart:nil
                                onComplete:nil];

            //}
            break;
            
        default:
            NSLog(@"not handled state in switch %d", [gestureRecognizer state]);
            break;
    }
}

// draw shadow on uiview

- (UIView *)shadowLayerWithBound:(CGRect)bound {
    UIView *topShadowView = [[UIView alloc] initWithFrame:bound];
    CAGradientLayer *topShadow = [CAGradientLayer layer];
    topShadow.frame = bound;
    topShadow.colors = [NSArray arrayWithObjects:(__bridge id)[[UIColor colorWithWhite:0.0 alpha:0.25f] CGColor],
                    (__bridge id)[[UIColor clearColor] CGColor], nil];
    [topShadowView.layer insertSublayer:topShadow atIndex:0];
    return topShadowView;
}

//- (UIView*) singletonShadowLayer {
//    static UIView *topShadowView;
//    if (!topShadowView) {
//        CGRect shadowRect = CGRectMake(self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, 6);
//        topShadowView = [self shadowLayerWithBound:shadowRect];
//    }
//    return topShadowView;
//}

-(void) dropShadowOnView:(UIView*)view {
    if (shadowView) [self removeShadow];
    CGRect shadowRect = CGRectMake(self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, 6);
    shadowView = [self shadowLayerWithBound:shadowRect];
    [view addSubview:shadowView];
}

- (void) removeShadow {
    [shadowView removeFromSuperview];
    shadowView = nil;
}

#pragma mark - Panning Gesture: pan the designated UIView of a tableViewCell (foreground view)

// previously panned cell

- (CellLocation *)prevPannedCellLocationInGroup {
    return [NPLPannableTableViewCell prevPannedCellLocationForGroupId:self.groupId];
}

- (void)forgetPrevPannedCellLoationInGroup {
    [prevPannedCellLocations removeObjectForKey:self.groupId];
}

+ (CellLocation *)prevPannedCellLocationForGroupId:(NSString *)groupId {
    if (!groupId) return nil;
    return (CellLocation*)[prevPannedCellLocations objectForKey:groupId];
}

+ (void)setPrevPannedIndexPath:(NSIndexPath *)indexPath
                     tableView:(UITableView *)tableView
                    forGroupId:(NSString *)groupId {
    CellLocation *cellLocation = [[CellLocation alloc] initWithNSIndexPath:indexPath tableView:tableView];
    if(prevPannedCellLocations) {
        [prevPannedCellLocations setObject:cellLocation forKey:groupId];
    } else {
        // create NSMutableDictionary for previously panned cell for tableview id
        prevPannedCellLocations = [NSMutableDictionary dictionaryWithObject:cellLocation forKey:groupId];
    }
}

// currently panning cell

- (NPLPannableTableViewCell *)panningCellInGroup {
    return [NPLPannableTableViewCell panningCellForGroupId:self.groupId];
}

- (void)forgetPanningCellLocationInGroup {
    [panningCellLocations removeObjectForKey:self.groupId];
}

+ (NPLPannableTableViewCell *)panningCellForGroupId:(NSString *)groupId {
    if (!groupId) return nil;

    CellLocation* cellLocation = [panningCellLocations objectForKey:groupId];
    return (NPLPannableTableViewCell*)[cellLocation.tableView cellForRowAtIndexPath:cellLocation.indexPath];
}

+ (void)setPanningCellIndexPath:(NSIndexPath *)indexPath
                      tableView:(UITableView *)tableView
                     forGroupId:(NSString *)groupId {
    CellLocation *cellLocation = [[CellLocation alloc] initWithNSIndexPath:indexPath
                                                                 tableView:tableView];
    if(panningCellLocations) {
        [panningCellLocations setObject:cellLocation forKey:groupId];
    } else {
        // create NSMutableDictionary for panning cell for tableview id
        panningCellLocations = [NSMutableDictionary dictionaryWithObject:cellLocation forKey:groupId];
    }
}

// panning threshold to open/close tableview cell foreground

- (CGFloat)panningDistanceThreshold {
    if (!distanceThreshold) {
        UIScreenMode *screenMode = [[UIScreen mainScreen] currentMode];
        distanceThreshold = screenMode.size.width / 10;
    }
    return distanceThreshold;
}

-(BOOL)isPanningOpenThresholdWithCurrentPos:(CGPoint)currentPos
                                   startPos:(CGPoint)startPos {
    return (startPos.x - currentPos.x > [self panningDistanceThreshold]);
}

-(BOOL)isPanningCloseThresholdWithCurrentPos:(CGPoint)currentPos
                                    startPos:(CGPoint)startPos {
    return (currentPos.x - startPos.x > [self panningDistanceThreshold]);
}

// TODO: delete
- (void)panOpen {
//    if(self.performBeforeOpening) {
//        self.performBeforeOpening(self);
//    }

    [self panOpenForegroundToX:(self.openToPosX - self.bounds.size.width)
                      duration:self.normalDuration];
}

- (void)panOpenForeground {
    [self panOpenForegroundToX:(self.openToPosX - CGRectGetWidth(self.bounds))
                      duration:self.normalDuration];
}

- (void)panOpenForegroundToX:(CGFloat)x
                    duration:(CGFloat)duration {
    [self panWithView:VIEW_LOCATION_FOREGROUND
                  toX:x
             duration:duration
              onStart:self.beforeOpenEventHandler
           onComplete:self.afterOpenEventHandler];
    [self panOpenForegroundToX:x
                      duration:duration
                       onStart:self.beforeOpenEventHandler
                    onComplete:self.afterOpenEventHandler];
}

- (void)panOpenForegroundToX:(CGFloat)x
                    duration:(CGFloat)duration
                     onStart:(void (^)(void))startHandler
                  onComplete:(void (^)(BOOL))completeHandler
{
    [self panWithView:VIEW_LOCATION_FOREGROUND
                  toX:x
             duration:duration
              onStart:startHandler
           onComplete:completeHandler];
}
# pragma mark pan close

-(void)panClose:(BOOL)removePrevPannedCell {

    [self panCloseWithShadow:NO removePrevPannedCell:removePrevPannedCell];

}

-(void)panCloseWithShadow:(BOOL)shadow removePrevPannedCell:(BOOL)resetPreviousOpenCell; {

    /*
    if(shadow) {
        [self dropShadowOnView:self.panningForegroundView];
    }
    [self panView:self.panningForegroundView
              toX:self.closeToPosX
         duration:self.normalDuration
       completion:^(BOOL finished) {
           if(shadow) { [self removeShadow]; }
//           if(self.performAfterClosing) {
//               self.performAfterClosing(self);
//           }
           self.afterCloseEventHandler?self.afterCloseEventHandler(finished):nil;
       }];
    */

    [self panWithView:VIEW_LOCATION_FOREGROUND
                toPos:CGPointMake(self.closeToPosX, 0)
             duration:self.normalDuration
                delay:0
       animationCurve:UIViewAnimationCurveEaseInOut
              onStart:^{
                  if(resetPreviousOpenCell) {
                      [prevPannedCellLocations removeObjectForKey:self.groupId];
                  }

                  self.beforeCloseEventHandler?self.beforeCloseEventHandler():nil;
//                  if(shadow) {
//                      [self dropShadowOnView:self.panningForegroundView];
//                  }
              }
           onComplete:^(BOOL finished){
//               if(shadow) { [self removeShadow]; }
               self.afterCloseEventHandler?self.afterCloseEventHandler(finished):nil;
           }];
}


- (void)panWithView:(ViewLocation)viewLocation
                toX:(CGFloat)x
           duration:(CGFloat)duration
            onStart:(void (^)(void))startHandler
         onComplete:(void (^)(BOOL))completeHandler
{
    [self panWithView:viewLocation
                toPos:CGPointMake(x, 0)
             duration:duration
                delay:0
       animationCurve:UIViewAnimationCurveEaseOut
              onStart:startHandler
           onComplete:completeHandler];
}


- (void)panWithView:(ViewLocation)viewLocation
              toPos:(CGPoint)pos
           duration:(CGFloat)duration
              delay:(CGFloat)delay
     animationCurve:(UIViewAnimationCurve)curve
            onStart:(void (^)(void))startHandler
         onComplete:(void (^)(BOOL))completeHandler
{
    UIView* targetView;
    switch(viewLocation) {
        case VIEW_LOCATION_FOREGROUND:
            targetView =  self.panningForegroundView;
            break;
        case VIEW_LOCATION_BACKGROUND:
            targetView = self.panningBackgroundView;
    }

    if (startHandler) { startHandler(); }

    [UIView animateWithDuration:duration
                          delay:delay
                        options:curve
                     animations:^{      // TODO: animation define
                         [targetView setTransform:CGAffineTransformMakeTranslation(pos.x, pos.y)];}
                     completion:completeHandler];
}

#pragma  mark

-(void)panView:(UIView *)view
           toX:(float)x
      duration:(float)sec
    completion:(void (^)(BOOL finished)) completionBlock {
    [UIView animateWithDuration:sec
                          delay:0
                        options:UIViewAnimationCurveEaseOut
                     animations:^{
                         [view setTransform:CGAffineTransformMakeTranslation(x, 0)];}
                     completion:completionBlock];
}

- (void)resetToInitPositionAt:(NSIndexPath *)indexPath {
    CellLocation *prevPannedCellLocation = [NPLPannableTableViewCell prevPannedCellLocationForGroupId:self.groupId];
    if ([prevPannedCellLocation isEqualWithTableView:self.tableView
                                           indexPath:indexPath]) {
        /*
        [self panView:self.panningForegroundView
                  toX:(self.openToPosX - self.bounds.size.width)
             duration:0
           completion:nil];
           */
        [self panOpenForegroundToX:self.openToPosX - CGRectGetWidth(self.bounds)
                          duration:0
                           onStart:nil
                        onComplete:nil];
    } else {
        /*
        [self panView:self.panningForegroundView
                  toX:self.closeToPosX
             duration:0
           completion:nil];
           */
        [self panOpenForegroundToX:self.closeToPosX
                          duration:0
                           onStart:nil
                        onComplete:nil];
    }
}

#pragma mark - panning attributes: speed
- (CGFloat)normalDuration
{
    return (_normalDuration > 0)?_normalDuration: DEFAULT_PANNING_DURATION_NORMAL;
}

- (CGFloat)fastDuration
{
    return (_fastDuration > 0)?_fastDuration: DEFAULT_PANNING_DURATION_FAST;
}


- (void)setPanningSpeedWithDuration:(CGFloat)normalDuration
                             onFast:(CGFloat)fastDuration
{
    _normalDuration = normalDuration;
    _fastDuration = fastDuration;
}

#pragma mark - event handlers

- (void)setDefaultEventHandlersOnBeforeOpen:(void (^)())beforeOpenHandler
                                onAfterOpen:(void (^)(BOOL))afterOpenHandler
                              onBeforeClose:(void (^)())beforeCloseHandler
                               onAfterClose:(void (^)(BOOL))afterCloseHandler {
    _beforeOpenEventHandler = beforeOpenHandler;
    _afterOpenEventHandler = afterOpenHandler;
    _beforeCloseEventHandler = beforeCloseHandler;
    _afterCloseEventHandler = afterCloseHandler;
}
@end
