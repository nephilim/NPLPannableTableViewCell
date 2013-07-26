//
//  NPLCancellablePanGestureRecognizer.m
//  Toodo
//
//  Created by Nephilim on 13. 7. 20..
//  Copyright (c) 2013년 YakShavingLocus. All rights reserved.
//

#import "NPLCancellablePanGestureRecognizer.h"

@implementation NPLCancellablePanGestureRecognizer

- (void)cancel {
    self.enabled = NO;
    self.enabled = YES;
}

@end
