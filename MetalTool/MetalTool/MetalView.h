//
//  MetalView.h
//  MetalTool
//
//  Created by niezhiqiang on 2021/7/5.
//

#import "MTIDrawableRendering.h"
#import "MTIImage.h"
#import "MTIContext.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DisplayMode) {
    DisplayModeScaleIn,
    DisplayModeScaleOut,
    DisplayModeScaleFull,
};

@interface MetalView : UIView

- (void)drawViewWithPixelBuffer:(CVPixelBufferRef)pixelBuffer;// 绘制
- (void)canvasColor:(MTLClearColor)color;// 画布底色
- (void)rotateMode:(RotateMode)mode;// 旋转
- (void)translateX:(float)x;// 水平平移
- (void)translateY:(float)y;// 垂直平移
- (void)enableQualityEnhancer:(BOOL)enable;// 画质增强
- (void)displayMode:(DisplayMode)mode;// 展示模式
- (void)enableEdgeBlur:(BOOL)ennable;// 高斯边缘模糊
- (void)enableAlpha:(BOOL)enable;// 开启透明通道渲染，默认不开启，资源消耗大，当明确CVPixelBufferRef带透明通道的时候再开启

- (UIImage *)snapShot;// 截图

@end

NS_ASSUME_NONNULL_END
