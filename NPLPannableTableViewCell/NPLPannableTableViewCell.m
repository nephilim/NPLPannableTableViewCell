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
- (void) closeExpandedCell; //TODO: clearPreviosExpandedCell option

@end

@implementation NPLPannableTableViewCell

static CGFloat distanceThreshold;                       // panning distance

static NSMutableDictionary* prevPannedCells = nil;      // register panned cell when it's opened,
                                                        // panned cell exist only on for each tableViewId set by users
static NSMutableDictionary* panningCells = nil;         // register panning cell when user started to pan
                                                        // panning cell exist only on for each tableViewId set by users

@synthesize panningForegroundView, panningBackgroundView;
@synthesize openToPosX, closeToPosX;
@synthesize performBeforeOpening, performAfterClosing;
@synthesize tableViewId;

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

// designated initialzer
- (id)initWithReuseIdentifier:(NSString*)reuseIdentifier
                   foreground:(UIView*)foreground
                   background:(UIView*)background
                   openToPosX:(CGFloat)openToX
                  closeToPosX:(CGFloat)closeToX
          tableViewIdentifier:(NSString*)tableViewIdentifier;
{
    
    NPLPannableTableViewCell* cell = [[NPLPannableTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                                     reuseIdentifier:reuseIdentifier];
    if (cell) {
        [cell.contentView addSubview:background];
        [cell.contentView addSubview:foreground];
        cell.panningForegroundView = foreground;
        cell.panningBackgroundView = background;
        cell.openToPosX = openToX;
        cell.closeToPosX = closeToX;
        cell.tableViewId = tableViewIdentifier;
        
        NPLCancellablePanGestureRecognizer* panGestureRecognizer = [[NPLCancellablePanGestureRecognizer alloc] initWithTarget:cell
                                                                                                                       action:@selector(handleCellPanning:)];
        [panGestureRecognizer setDelegate:cell];
        [cell setGestureRecognizers:[NSArray arrayWithObjects:panGestureRecognizer, nil]];
        cell.groupId = (groupId == AUTOGENERATE_GROUP_ID)?[NPLPannableTableViewCell
                generateTableViewIdentifierFromTableView:tableView]:groupId;

        if (tableView.allowsSelection) {
            tableView.allowsSelection = NO;
            NSLog(@"Warning: TableView using pannable TableViewCell should not allow selection.");
            NSLog(@"Automatically changed the TableView not to allow selection.");
        }

    }
    return cell;
}

+ (NSString*)generateTableViewIdentifierFromTableView:(UITableView*)tableView
{
    NSValue* pointer= [NSValue valueWithPointer:(__bridge void *)tableView];
    return [NSString stringWithFormat:@"%@", pointer];
}

- (void)setAsPrevPannedCell
{
    [NPLPannableTableViewCell setPrevPannedCell:self tableViewIdentifier:self.tableViewId];
}

- (void)setAsPanningCell
{
    [NPLPannableTableViewCell setPanningCell:self tableViewIdentifier:self.tableViewId];
}


#pragma mark - Panning Gesture Recognizer start condition

- (BOOL) gestureRecognizerShouldBegin:(UIGestureRecognizer*)gestureRecognizer {
    @synchronized(self.tableViewId){
        BOOL shouldStart = NO;
        NPLPannableTableViewCell* panningCell = [NPLPannableTableViewCell panningCellForTableViewIdentifier:self.tableViewId];
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

- (NPLPannableTableViewCell*)prevPannedCell {
    return [NPLPannableTableViewCell prevPannedCellForTableViewIdentifier:self.tableViewId];
}

- (IBAction) handleCellPanning:(NPLCancellablePanGestureRecognizer*)gestureRecognizer {
    
    // TODO: declare static vars per table
    static CGPoint panningStartPos;
    
    NPLPannableTableViewCell* panningCell = [NPLPannableTableViewCell panningCellForTableViewIdentifier:self.tableViewId];
    if (panningCell != nil && self != panningCell){
        [gestureRecognizer cancel];
        //NSLog(@"%d - cancelled", [self hash]);
        return;
    }
    
    CGPoint location = [gestureRecognizer locationInView:self];
    CGFloat panToX = 0.0;
    CGPoint velocity;
    
    NPLPannableTableViewCell* prevPannedCell = [NPLPannableTableViewCell prevPannedCellForTableViewIdentifier:self.tableViewId];
    
    switch ([gestureRecognizer state]) {
        case UIGestureRecognizerStateBegan:
            //NSLog(@"%d - pan began:", [self hash]);

            [self setAsPanningCell];
            
            // close previosly opened cell
            if(prevPannedCell != nil &&
               self != prevPannedCell) {
                [prevPannedCell panCloseWithShadow:NO removePrevPannedCell:YES];
            }
            
            // set panning start position
            panningStartPos.x = location.x;
            panningStartPos.y = location.y;
                        
            // shadowing
            [self dropShadowOnView:panningForegroundView];
            velocity = [gestureRecognizer velocityInView:self];
            break;
            
        case UIGestureRecognizerStateEnded:
            if(self == prevPannedCell) {
                
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
                    [self setAsPrevPannedCell]; // open
                    [self panOpen];
                } else {
                    [self panClose:NO];         // fail to open
                }
            }
            
            // unshadowing
            [self removeShadow];
            
            panningStartPos.x = 0;
            panningStartPos.y = 0;
            
            [panningCells removeObjectForKey:self.tableViewId]; 
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
            
            if(self == prevPannedCell) {
                // user tries to close
                /*
                 // skip not to blink
                 [self snapView:panningForegroundView
                 toX: -self.bounds.size.width +  panToX
                 duration:PANNING_DURATION_NORMAL
                 completion:NULL];
                 */
            } else if( self !=  prevPannedCell) {
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
+(NPLPannableTableViewCell*) prevPannedCellForTableViewIdentifier:(NSString*)tableViewId {
    if (!tableViewId) return nil;
    
    return (NPLPannableTableViewCell*)[prevPannedCells objectForKey:tableViewId];
}

+(void) setPrevPannedCell:(NPLPannableTableViewCell*)tableViewCell tableViewIdentifier:(NSString*)tableViewId {
    if(prevPannedCells) {
        [prevPannedCells setObject:tableViewCell forKey:tableViewId];
    } else {
        // create NSMutableDictionary for previously panned cell for tableview id
        prevPannedCells = [NSMutableDictionary dictionaryWithObject:tableViewCell forKey:tableViewId];
    }
}

// panning cell

+(NPLPannableTableViewCell*) panningCellForTableViewIdentifier:(NSString*)tableViewId {
    if (!tableViewId) return nil;
    
    return (NPLPannableTableViewCell*)[panningCells objectForKey:tableViewId];
}

+(void) setPanningCell:(NPLPannableTableViewCell*)tableViewCell tableViewIdentifier:(NSString*)tableViewId {
    if(panningCells) {
        [panningCells setObject:tableViewCell forKey:tableViewId];
    } else {
        // create NSMutableDictionary for panning cell for tableview id
        panningCells = [NSMutableDictionary dictionaryWithObject:tableViewCell forKey:tableViewId];
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
        [prevPannedCells removeObjectForKey:self.tableViewId];
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

@end
