//
//  MJPhotoBrowser.m
//
//  Created by mj on 13-3-4.
//  Copyright (c) 2013年 itcast. All rights reserved.

#import <QuartzCore/QuartzCore.h>
#import "MJPhotoBrowser.h"
#import "MJPhoto.h"
#import "SDWebImageManager+MJ.h"
#import "MJPhotoView.h"
#import "MJPhotoToolbar.h"
#import "MBProgressHUD+Add.h"

#define kPadding 10
#define kPhotoViewTagOffset 1000
#define kPhotoViewIndex(photoView) ([photoView tag] - kPhotoViewTagOffset)

@interface MJPhotoBrowser () <MJPhotoViewDelegate>
{
    // 滚动的view
	UIScrollView *_photoScrollView;
    // 所有的图片view
	NSMutableSet *_visiblePhotoViews;
    NSMutableSet *_reusablePhotoViews;
    // 工具条
    MJPhotoToolbar *_toolbar;
    UIView *alertView;
    UIView *alertFirstView;
    
    // 一开始的状态栏
    BOOL _statusBarHiddenInited;
}
@end

@implementation MJPhotoBrowser

#pragma mark - Lifecycle
- (void)loadView
{
   // _statusBarHiddenInited = [UIApplication sharedApplication].isStatusBarHidden;
    // 隐藏状态栏
//    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    self.view = [[UIView alloc] init];
    self.view.frame = [UIScreen mainScreen].bounds;
	self.view.backgroundColor = [UIColor blackColor];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 1.创建UIScrollView
    [self createScrollView];
    
    // 2.创建工具条
    [self createToolbar];
    
    //3.创建保存
    [self createSaveView];
}

- (void)show
{
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    [window addSubview:self.view];
    [window.rootViewController addChildViewController:self];
//    window.rootViewController.automaticallyAdjustsScrollViewInsets = NO;
    
    if (_currentPhotoIndex == 0) {
        [self showPhotos];
    }
}

#pragma mark - 私有方法
#pragma mark 创建工具条
- (void)createToolbar
{
    CGFloat barHeight = 44;
    CGFloat barY = self.view.frame.size.height - barHeight;
    _toolbar = [[MJPhotoToolbar alloc] init];
    _toolbar.frame = CGRectMake(0, barY, self.view.frame.size.width, barHeight);
    _toolbar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _toolbar.photos = _photos;
    [self.view addSubview:_toolbar];
    
    [self updateTollbarState];
}

#pragma mark 创建保存按钮
- (void)createSaveView
{
    //1.1.1创建提示框
    alertFirstView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, self.view.width, ScreenSizeHeight-104)];
    alertFirstView.backgroundColor = [UIColor blackColor];
    alertFirstView.alpha = 0;
    
    alertView = [[UIView alloc]initWithFrame:CGRectMake(0,ScreenSizeHeight-104 , ScreenSizeWidth, 104)];
    alertView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    //===========创建保存图片按钮=========
    UIButton *savebtn = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, alertView.width, 49)];
    savebtn.backgroundColor = [UIColor whiteColor];
    [savebtn setTitle:@"保存图片" forState:UIControlStateNormal];
    [savebtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [savebtn addTarget:self action:@selector(savePic:) forControlEvents:UIControlEventTouchUpInside];
    [savebtn addTarget:self action:@selector(changeColor:) forControlEvents:UIControlEventTouchDown];
    [alertView addSubview:savebtn];
    //==============创建取消按钮===========
    UIButton *cancel = [[UIButton alloc]initWithFrame:CGRectMake(0,55 ,alertView.width ,49)];
    cancel.backgroundColor = [UIColor whiteColor];
    [cancel setTitle:@"取消" forState:UIControlStateNormal];
    [cancel setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    [cancel addTarget:self action:@selector(cancel:) forControlEvents:UIControlEventTouchUpInside];
    [cancel addTarget:self action:@selector(changeColor:) forControlEvents:UIControlEventTouchDown];
    [alertView addSubview:cancel];
    
    [self.view addSubview:alertFirstView];
    [self.view addSubview:alertView];
    alertView.alpha = 0;

    //创建单击手势
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(SingleTap:)];
    singleTap.numberOfTapsRequired = 1;
    [alertFirstView addGestureRecognizer:singleTap];
}

#pragma mark - alertAction
- (void)cancel:(UIButton *)btn
{
    [btn setBackgroundColor:[UIColor whiteColor]];
    [UIView animateWithDuration:0.5 animations:^{
        [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
        alertFirstView.alpha = 0;
        alertView.alpha = 0;
    } completion:^(BOOL finished) {
    }];
}

- (void)savePic:(UIButton *)btn
{
    [btn setBackgroundColor:[UIColor whiteColor]];
    MJPhoto *photo = _photos[_currentPhotoIndex];
    [self savePhoto:photo.url];
    [UIView animateWithDuration:0.5 animations:^{
        [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
        alertFirstView.alpha = 0;
        alertView.alpha = 0;
    } completion:^(BOOL finished) {
    }];
}

- (void)changeColor:(UIButton *)btn
{
    [btn setBackgroundColor:[UIColor colorWithRed:0.87 green:0.88 blue:0.88 alpha:1.00]];
}

//如果点击的是图片，并且按住的时间超过1s，执行handleLongTouch函数，处理图片的保存操作。
- (void)saveSheet:(UILongPressGestureRecognizer *)longPress
{
    if (longPress.state == UIGestureRecognizerStateBegan)
    {
        [UIView animateWithDuration:0.8 animations:^{
            [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
            alertView.alpha = 1;
            alertFirstView.alpha = 0.5;
        } completion:^(BOOL finished) {
        }];
    }
}
- (void)savePhoto:(NSURL *)url
{
    NSData* data = [NSData dataWithContentsOfURL:url];
    UIImage *img = [UIImage imageWithData:data];
    
    if (img != nil)
    {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.labelText = @"正在保存";
        hud.dimBackground = YES;
        UIImageWriteToSavedPhotosAlbum(img, self, @selector(image:didFinishSavingWithError:contextInfo:), (__bridge void *)(hud));
    }
}

// 保存图片到相册完成
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    MBProgressHUD *hud = (__bridge MBProgressHUD *)contextInfo;
    hud.customView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
    hud.mode = MBProgressHUDModeCustomView;
    hud.labelText = @"保存成功";
    [hud hide:YES afterDelay:1.5];
}

#pragma mark 创建UIScrollView
- (void)createScrollView
{
    CGRect frame = self.view.bounds;
    frame.origin.x -= kPadding;
    frame.size.width += (2 * kPadding);
	_photoScrollView = [[UIScrollView alloc] initWithFrame:frame];
	_photoScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_photoScrollView.pagingEnabled = YES;
	_photoScrollView.delegate = self;
	_photoScrollView.showsHorizontalScrollIndicator = NO;
	_photoScrollView.showsVerticalScrollIndicator = NO;
	_photoScrollView.backgroundColor = [UIColor clearColor];
    _photoScrollView.contentSize = CGSizeMake(frame.size.width * _photos.count, 0);
	[self.view addSubview:_photoScrollView];
    _photoScrollView.contentOffset = CGPointMake(_currentPhotoIndex * frame.size.width, 0);
    //创建长按的手势，用于保存图至相册
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(saveSheet:)];
    [_photoScrollView addGestureRecognizer:longPress];
    

}

- (void)SingleTap:(UITapGestureRecognizer *)singleGuester
{
    if (alertView.alpha == 1)
    {
        [UIView animateWithDuration:0.5 animations:^{
            [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
            alertView.alpha = 0;
            alertFirstView.alpha = 0;
        } completion:^(BOOL finished) {
        }];
    }
}

- (void)setPhotos:(NSArray *)photos
{
    _photos = photos;
    
    if (photos.count > 1) {
        _visiblePhotoViews = [NSMutableSet set];
        _reusablePhotoViews = [NSMutableSet set];
    }
    
    for (int i = 0; i<_photos.count; i++) {
        MJPhoto *photo = _photos[i];
        photo.index = i;
        photo.firstShow = i == _currentPhotoIndex;
    }
}

#pragma mark 设置选中的图片
- (void)setCurrentPhotoIndex:(NSUInteger)currentPhotoIndex
{
    _currentPhotoIndex = currentPhotoIndex;
    
    for (int i = 0; i<_photos.count; i++) {
        MJPhoto *photo = _photos[i];
        photo.firstShow = i == currentPhotoIndex;
    }
    
    if ([self isViewLoaded]) {
        _photoScrollView.contentOffset = CGPointMake(_currentPhotoIndex * _photoScrollView.frame.size.width, 0);
        
        // 显示所有的相片
        [self showPhotos];
    }
}

#pragma mark - MJPhotoView代理
- (void)photoViewSingleTap:(MJPhotoView *)photoView
{
    [UIApplication sharedApplication].statusBarHidden = _statusBarHiddenInited;
    self.view.backgroundColor = [UIColor clearColor];
    // 移除工具条
    [_toolbar removeFromSuperview];
}

- (void)photoViewDidEndZoom:(MJPhotoView *)photoView
{
    [self.view removeFromSuperview];
    [self removeFromParentViewController];
}

- (void)photoViewImageFinishLoad:(MJPhotoView *)photoView
{
    _toolbar.currentPhotoIndex = _currentPhotoIndex;
}

#pragma mark 显示照片
- (void)showPhotos
{
    // 只有一张图片
    if (_photos.count == 1) {
        [self showPhotoViewAtIndex:0];
        return;
    }
    
    CGRect visibleBounds = _photoScrollView.bounds;
	NSInteger firstIndex = (NSInteger)floorf((CGRectGetMinX(visibleBounds)+kPadding*2) / CGRectGetWidth(visibleBounds));
	NSInteger lastIndex  = (NSInteger)floorf((CGRectGetMaxX(visibleBounds)-kPadding*2-1) / CGRectGetWidth(visibleBounds));
    if (firstIndex < 0) firstIndex = 0;
    if (firstIndex >= _photos.count) firstIndex = _photos.count - 1;
    if (lastIndex < 0) lastIndex = 0;
    if (lastIndex >= _photos.count) lastIndex = _photos.count - 1;
	
	// 回收不再显示的ImageView
    NSInteger photoViewIndex;
	for (MJPhotoView *photoView in _visiblePhotoViews) {
        photoViewIndex = kPhotoViewIndex(photoView);
		if (photoViewIndex < firstIndex || photoViewIndex > lastIndex) {
			[_reusablePhotoViews addObject:photoView];
			[photoView removeFromSuperview];
		}
	}
    
	[_visiblePhotoViews minusSet:_reusablePhotoViews];
    while (_reusablePhotoViews.count > 2) {
        [_reusablePhotoViews removeObject:[_reusablePhotoViews anyObject]];
    }
	
	for (NSUInteger index = firstIndex; index <= lastIndex; index++) {
		if (![self isShowingPhotoViewAtIndex:index]) {
			[self showPhotoViewAtIndex:index];
		}
	}
}

#pragma mark 显示一个图片view
- (void)showPhotoViewAtIndex:(NSInteger )index
{
    MJPhotoView *photoView = [self dequeueReusablePhotoView];
    if (!photoView) { // 添加新的图片view
        photoView = [[MJPhotoView alloc] init];
        photoView.photoViewDelegate = self;
    }
    
    // 调整当期页的frame
    CGRect bounds = _photoScrollView.bounds;
    CGRect photoViewFrame = bounds;
    photoViewFrame.size.width -= (2 * kPadding);
    photoViewFrame.origin.x = (bounds.size.width * index) + kPadding;
    photoView.tag = kPhotoViewTagOffset + index;
    
    MJPhoto *photo = _photos[index];
    photoView.frame = photoViewFrame;
    photoView.photo = photo;
    
    [_visiblePhotoViews addObject:photoView];
    [_photoScrollView addSubview:photoView];
    
    [self loadImageNearIndex:index];
}

#pragma mark 加载index附近的图片
- (void)loadImageNearIndex:(NSInteger )index
{
    if (index > 0) {
        MJPhoto *photo = _photos[index - 1];
        [SDWebImageManager downloadWithURL:photo.url];
    }
    
    if (index < _photos.count - 1) {
        MJPhoto *photo = _photos[index + 1];
        [SDWebImageManager downloadWithURL:photo.url];
    }
}

#pragma mark index这页是否正在显示
- (BOOL)isShowingPhotoViewAtIndex:(NSUInteger)index {
	for (MJPhotoView *photoView in _visiblePhotoViews) {
		if (kPhotoViewIndex(photoView) == index) {
           return YES;
        }
    }
	return  NO;
}

#pragma mark 循环利用某个view
- (MJPhotoView *)dequeueReusablePhotoView
{
    MJPhotoView *photoView = [_reusablePhotoViews anyObject];
	if (photoView) {
		[_reusablePhotoViews removeObject:photoView];
	}
	return photoView;
}

#pragma mark 更新toolbar状态
- (void)updateTollbarState
{
    _currentPhotoIndex = _photoScrollView.contentOffset.x / _photoScrollView.frame.size.width;
    _toolbar.currentPhotoIndex = _currentPhotoIndex;
}

#pragma mark - UIScrollView Delegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	[self showPhotos];
    [self updateTollbarState];
}
@end