//
//  LPHotZoneController.m
//  LovePlayNews
//
//  Created by tanyang on 16/9/4.
//  Copyright © 2016年 tany. All rights reserved.
//

#import "LPHotZoneController.h"
#import "LPGameZoneOperation.h"
#import "LPLoadingView.h"
#import "LPZonePostCellNode.h"
#import "LPHotZoneSectionView.h"
#import "LPLoadFailedView.h"
#import "SDCycleScrollView.h"
#import "UIImage+Color.h"
#import "LPDiscuzDetailController.h"

@interface LPHotZoneController ()<ASTableDelegate, ASTableDataSource, SDCycleScrollViewDelegate>

// UI
@property (nonatomic, strong) ASTableNode *tableNode;

// Data
@property (nonatomic, strong) NSArray *focusList;
@property (nonatomic, strong) NSArray *forumList;
@property (nonatomic, strong) NSArray *threadList;

@property (nonatomic, assign) NSInteger curIndexPage;
@property (nonatomic, assign) BOOL haveMore;

@end

static NSString * headerId = @"LPHotZoneSectionView";

@implementation LPHotZoneController

#pragma mark - life cycle

- (instancetype)init
{
    if (self = [super initWithNode:[ASDisplayNode new]]) {
        [self addTableNode];
    }
    return self;
}

- (void)addTableNode
{
    _tableNode = [[ASTableNode alloc] initWithStyle:UITableViewStyleGrouped];
    _tableNode.backgroundColor = [UIColor whiteColor];
    _tableNode.delegate = self;
    _tableNode.dataSource = self;
    [self.node addSubnode:_tableNode];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    _tableNode.frame = self.node.bounds;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self configureTableView];
    
    [self loadData];
}

- (void)configureTableView
{
    if (_extendedTabBarInset) {
        _tableNode.view.contentInset = UIEdgeInsetsMake(0, 0, 49, 0);
        _tableNode.view.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 49, 0);
    }
    _tableNode.view.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableNode.view.tableFooterView = [[UIView alloc]init];
    UINib *nib = [UINib nibWithNibName:headerId bundle:nil];
    [_tableNode.view registerNib:nib forHeaderFooterViewReuseIdentifier:headerId];
}

- (void)addCycleScrollView
{
    SDCycleScrollView *cycleScrollView = [SDCycleScrollView cycleScrollViewWithFrame:CGRectMake(0, 0, kScreenWidth, 105) delegate:self placeholderImage:nil];
    cycleScrollView.pageControlAliment = SDCycleScrollViewPageContolAlimentRight;
    cycleScrollView.currentPageDotColor = [UIColor whiteColor];
    cycleScrollView.placeholderImage = [UIImage imageWithColor:RGB_255(245, 245, 245)];
    
    NSMutableArray *imageURLs = [NSMutableArray array];
    for (LPZoneFocus *focus in _focusList) {
        [imageURLs addObject:focus.img];
    }
    cycleScrollView.imageURLStringsGroup = [imageURLs copy];
    _tableNode.view.tableHeaderView = cycleScrollView;
}

#pragma mark - loadData

- (void)loadData
{
    [self loadMoreDataWithContext:nil];
}

- (void)loadMoreDataWithContext:(ASBatchContext *)context
{
    if (context) {
        [context beginBatchFetching];
    }else {
        _curIndexPage = 1;
        _haveMore = YES;
        [LPLoadingView showLoadingInView:self.view];
    }
    
    LPHttpRequest *hotZoneRequest = [LPGameZoneOperation requestHotZoneWithPageIndex:_curIndexPage];
    [hotZoneRequest loadWithSuccessBlock:^(LPHttpRequest *request) {
        LPHotZoneModel *hotZoneModel = request.responseObject.data;
        NSArray *threadList = hotZoneModel.threadList;
        if (context) {
            if (threadList.count > 0) {
                NSMutableArray *indexPaths = [NSMutableArray array];
                for (NSInteger row = _threadList.count; row<_threadList.count+threadList.count; ++row) {
                    [indexPaths addObject:[NSIndexPath indexPathForRow:row inSection:0]];
                }
                _threadList = [_threadList arrayByAddingObjectsFromArray:threadList];
                [_tableNode.view insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
                _curIndexPage++;
                _haveMore = YES;
            }else {
                _haveMore = NO;
            }
            [context completeBatchFetching:YES];
        }else {
            _focusList = hotZoneModel.focusList;
            _forumList = hotZoneModel.forumList;
            _threadList = hotZoneModel.threadList;
            [self addCycleScrollView];
            [_tableNode.view reloadData];
            ++_curIndexPage;
            _haveMore = YES;
            [LPLoadingView hideLoadingForView:self.view];
        }
    } failureBlock:^(id<TYRequestProtocol> request, NSError *error) {
        [LPLoadingView hideLoadingForView:self.view];
        if (context) {
            [context completeBatchFetching:YES];
        }else {
            __weak typeof(self) weakSelf = self;
            [LPLoadFailedView showLoadFailedInView:self.view retryHandle:^{
                [weakSelf loadData];
            }];
        }
    }];
    
}

#pragma mark - ASTableDataSource

- (BOOL)shouldBatchFetchForTableView:(ASTableView *)tableView
{
    return _threadList.count && _haveMore;
}

- (void)tableView:(ASTableView *)tableView willBeginBatchFetchWithContext:(ASBatchContext *)context
{
    [self loadMoreDataWithContext:context];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _threadList.count;
}

- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
    LPZoneThread *post = _threadList[indexPath.row];
    ASCellNode *(^cellNodeBlock)() = ^ASCellNode *() {
        LPZonePostCellNode *cellNode = [[LPZonePostCellNode alloc] initWithPost:post];
        return cellNode;
    };
    return cellNodeBlock;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        LPHotZoneSectionView *sectionView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:headerId];
        return sectionView;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        return 40;
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 0.1;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    LPZoneThread *post = _threadList[indexPath.row];
    LPDiscuzDetailController *discuzDetailVC = [[LPDiscuzDetailController alloc]init];
    discuzDetailVC.tid = post.tid;
    [self.navigationController pushViewController:discuzDetailVC animated:YES];
}

#pragma mark - SDCycleScrollViewDelegate

- (void)cycleScrollView:(SDCycleScrollView *)cycleScrollView didSelectItemAtIndex:(NSInteger)index
{
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
