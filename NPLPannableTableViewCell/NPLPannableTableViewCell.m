//
//  NPLPannableTableViewCell.m
//  Toodo
//
//  Created by Nephilim on 13. 7. 12..
//  Copyright (c) 2013년 YakShavingLocus. All rights reserved.
//

#import "NPLPannableTableViewCell.h"

// constants related to panning
// TODO: change to property
#define PANNING_DURATION_FAST 0.1
#define PANNING_DURATION_NORMAL 0.2

@interface NPLPannableTableViewCell(Private)

// geture recognizer handler
- (IBAction) handleCellPanning:(NPLCancellablePanGestureRecognizer*)recognizer;
// panning
- (void) panCloseWithShadow:(BOOL)shadow removePrevPannedCell:(BOOL)removePrevPannedCell;
- (UIView *) shadowLayerWithBound:(CGRect)bound;
//- (UIView*) singletonShadowLayer;
- (void) dropShadowOnView:(UIView*)view;
- (void) removeShadow;

// tap(zoom)
// - (void) closeExpandedCell; //TODO: clearPreviosExpandedCell option

@end

@implementation NPLPannableTableViewCell

static CGFloat distanceThreshold;                       // panning distance

static NSMutableDictionary*prevPannedCellLocations = nil;      // register panned cell when it's opened,
static NSMutableDictionary*panningCellLocations = nil;         // register panning cell when user started to pan
                                                        // panning cell exist only on for each tableView set by users
@synthesize panningForegroundView, panningBackgroundView;
@synthesize openToPosX, closeToPosX;
@synthesize performBeforeOpening, performAfterClosing;
@synthesize tableView, groupId;

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

// designated initialzer
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
                   foreground:(UIView *)foreground
                   background:(UIView *)background
                   openToPosX:(CGFloat)openToX
                  closeToPosX:(CGFloat)closeToX
                    tableView:(UITableView *)tableView
                      groupId:(NSString *)groupId {
    
    NPLPannableTableViewCell* cell = [[NPLPannableTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                                     reuseIdentifier:reuseIdentifier];
    if (cell) {
        cell.panningForegroundView = foreground;
        cell.panningBackgroundView = background;
        [cell.contentView addSubview:background];
        [cell.contentView addSubview:foreground];

        cell.openToPosX = openToX;
        cell.closeToPosX = closeToX;
        cell.tableView = tableView;
        cell.groupId = (groupId == AUTOGENERATE_GROUP_ID)?[NPLPannableTableViewCell
                generateTableViewIdentifierFromTableView:tableView]:groupId;

        if (tableView.allowsSelection) {
            tableView.allowsSelection = NO;
            NSLog(@"Warning: TableView using pannable TableViewCell should not allow selection.");
            NSLog(@"Automatically changed the TableView not to allow selection.");
        }

        NPLCancellablePanGestureRecognizer *gestureRecognizer = [[NPLCancellablePanGestureRecognizer alloc]
                initWithTarget:cell
                        action:@selector(handleCellPanning:)];
        [gestureRecognizer setDelegate:cell];
        [cell setGestureRecognizers:[NSArray arrayWithObjects:gestureRecognizer, nil]];
    }
    return cell;
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
    NSIndexPath* indexPath = [tableView indexPathForCell:self];
    [NPLPannableTableViewCell setPrevPannedIndexPath:indexPath tableView:self.tableView forGroupId:self.groupId];
}

- (void)setAsPanningCell
{
    NSIndexPath* indexPath = [tableView indexPathForCell:self];
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
    NSIndexPath *indexPath = [tableView indexPathForCell:self];

    switch ([gestureRecognizer state]) {
        case UIGestureRecognizerStateBegan:
            [self setAsPanningCell];
            
            // close previously opened cell

            if( (prevPannedCellLocation != nil) &&
                (![prevPannedCellLocation isEqualWithTableView:tableView indexPath:indexPath])) {
                NPLPannableTableViewCell *prevPannedCell = (NPLPannableTableViewCell*)
                        [tableView cellForRowAtIndexPath:prevPannedCellLocation.indexPath];
                NSLog(@"prev panned cell %d (%@), is about to close", prevPannedCellLocation.indexPath.row
                        , prevPannedCell);

                if(prevPannedCell) {
                    [prevPannedCell panCloseWithShadow:NO removePrevPannedCell:YES];
                } else {
                    // tableviewcell cannot be seen while it's above/below screen area
                    NSLog(@"prev panned cell is out of sight.");
                    [self forgetPrevPannedCellLoationInGroup];

                }
            }
            
            // set panning start position
            panningStartPos.x = location.x;
            panningStartPos.y = location.y;
                        
            // shadowing
            [self dropShadowOnView:panningForegroundView];
            velocity = [gestureRecognizer velocityInView:self];
            break;
            
        case UIGestureRecognizerStateEnded:
            if([prevPannedCellLocation isEqualWithTableView:tableView indexPath:indexPath]) {
                // user tries to close cell?
                if( [self isPanningCloseThresholdWithCurrentPos:location
                                                       startPos:panningStartPos] ) {
                    [self panCloseWithShadow:NO removePrevPannedCell:YES];            // close
                } else {
                    [self panOpen];             // fail to close
                }
            } else {
                // user tries to open not-opened-yet cell
                if( [self isPanningOpenThresholdWithCurrentPos:location
                                                      startPos:panningStartPos] ) {
                    [self setAsPrevPannedIndexPath]; // open
                    [self panOpen];
                } else {
                    [self panClose:NO];         // fail to open
                }
            }
            
            // unshadowing
            [self removeShadow];
            
            panningStartPos.x = 0;
            panningStartPos.y = 0;

            [self forgetPanningCellLocationInGroup];

            break;
            
        case UIGestureRecognizerStateChanged:
            //cancel if y position is way to far
            /*
             if( fabs(location.y - panningStartPos.y) > [self panThresholdDistY] ) {
             panningIndexPath = nil;
             panningCell = nil;
             [gestureRecognizer cancelsTouchesInView];
             [self snapView:panningForegroundView toX:0 duration:PANNING_DURATION_NORMAL animated:YES];
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
                 duration:PANNING_DURATION_NORMAL
                 completion:NULL];
                 */
            //} else

            if( ![prevPannedCellLocation isEqualWithTableView:tableView indexPath:indexPath]) {
                // user is trying to open
                [self panView:self.panningForegroundView
                          toX:panToX
                     duration:PANNING_DURATION_FAST
                   completion:NULL];
            }
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
    topShadow.colors = [NSArray arrayWithObjects:(id)[[UIColor colorWithWhite:0.0 alpha:0.25f] CGColor], (id)[[UIColor clearColor] CGColor], nil];
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
    NSLog(@"prevPannedCell(%d) removed", [self prevPannedCellLocationInGroup].indexPath.row);
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

- (CGFloat) panningDistanceThreshold {
    if (!distanceThreshold) {
        UIScreenMode* screenMode =[[UIScreen mainScreen] currentMode];
        distanceThreshold = screenMode.size.width / 10;
    }
    return distanceThreshold;
}

-(BOOL)isPanningOpenThresholdWithCurrentPos:(CGPoint)currentPos startPos:(CGPoint)startPos {
    return (startPos.x - currentPos.x > [self panningDistanceThreshold]);
}

-(BOOL)isPanningCloseThresholdWithCurrentPos:(CGPoint)currentPos startPos:(CGPoint)startPos {
    return (currentPos.x - startPos.x > [self panningDistanceThreshold]);
}

-(void)panOpen {
    if(performBeforeOpening) {
        performBeforeOpening(self);
    }
    
    [self panView:self.panningForegroundView
              toX:(self.openToPosX - self.bounds.size.width)
         duration:PANNING_DURATION_NORMAL
       completion:NULL];
}

-(void)panClose:(BOOL)removePrevPannedCell {
    [self panCloseWithShadow:NO removePrevPannedCell:removePrevPannedCell];
}

-(void)panCloseWithShadow:(BOOL)shadow removePrevPannedCell:(BOOL)removePrevPannedCell; {
    if(removePrevPannedCell) {
        [prevPannedCellLocations removeObjectForKey:self.groupId];
    }
    
    if(shadow) {
        [self dropShadowOnView:self.panningForegroundView];
    }
    [self panView:self.panningForegroundView
              toX:self.closeToPosX
         duration:PANNING_DURATION_NORMAL
       completion:^(BOOL finished) {
           if(shadow) { [self removeShadow]; }
           if(performAfterClosing) {
               performAfterClosing(self);
           }
       }];
}

-(void)panView:(UIView *)view toX:(float)x duration:(float)sec completion:(void (^)(BOOL finished)) completionBlock {
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
        NSLog(@"prev panned cell at %d, %f", indexPath.row, (self.openToPosX - self.bounds.size.width));
        [self resetFrameOf:self.panningForegroundView
                       toX:(self.openToPosX - self.bounds.size.width)
                       toY:self.panningForegroundView.frame.origin.y];
    } else {
        [self resetFrameOf:self.panningForegroundView
                       toX:self.closeToPosX
                       toY:self.panningForegroundView.frame.origin.y];
    }
}

- (void)resetFrameOf:(UIView *)view toX:(CGFloat)x toY:(CGFloat)y {
    CGRect originalFrame = view.frame;
    if(!CGPointEqualToPoint(originalFrame.origin, CGPointMake(x,y))) {
        view.frame = CGRectMake(x, y, originalFrame.size.width, originalFrame.size.height);
    }
}

@end
