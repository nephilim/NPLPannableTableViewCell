//
// Created by Nephilim on 13. 7. 29..
// Copyright (c) 2013 Dongwook Lee. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface CellLocation : NSObject

@property (nonatomic, readonly) NSIndexPath * indexPath;
@property (nonatomic, readonly) UITableView * tableView;

- (id)initWithNSIndexPath:(NSIndexPath *)indexPath
                tableView:(UITableView *)tableView;
@end