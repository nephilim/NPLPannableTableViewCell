//
// Created by Nephilim on 13. 7. 29..
// Copyright (c) 2013 Dongwook Lee. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import "CellLocation.h"

@implementation CellLocation

@synthesize indexPath = _indexPath;
@synthesize tableView = _tableView;

- (id)initWithNSIndexPath:(NSIndexPath *)indexPath
                tableView:(UITableView *)tableView {
    self = [super init];
    if (self != nil) {
        _indexPath = indexPath;
        _tableView = tableView;
    }
    return self;
}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"tableView: %@, indexPath: %@", _tableView, _indexPath];
    [description appendString:@">"];
    return description;
}

- (BOOL)isEqualWithTableView:(UITableView *)tableView
                   indexPath:(NSIndexPath *)indexPath {
    BOOL result = NO;
    if (self.tableView == tableView &&
        [self.indexPath isEqual:indexPath]) {
        result = YES;
    }
    return result;
}
@end