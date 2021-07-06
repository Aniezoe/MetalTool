//
//  MTIContext.h
//  Pods
//
//  Created by YuAo on 25/06/2017.
//
//

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import "MTIKernel.h"
#import "MTIImagePromise.h"

NS_ASSUME_NONNULL_BEGIN

//旋转
typedef NS_OPTIONS(NSUInteger, RotateMode) {
    RotateModeNone         = 1 << 1, //正常
    RotateModeMirror       = 1 << 2, //镜像
    RotateMode90           = 1 << 3, //90or-270
    RotateMode180          = 1 << 4, //180
    RotateMode270          = 1 << 5, //270or-90
    
    RotateMode90Mirror     = RotateMode90 | RotateModeMirror, //90or-270 + 镜像
    RotateMode180Mirror    = RotateMode180 | RotateModeMirror, //180 + 镜像
    RotateMode270Mirror    = RotateMode270 | RotateModeMirror, //270or-90 + 镜像
};

@class MTICVMetalTextureCache;

FOUNDATION_EXPORT NSString * const MTIContextDefaultLabel;

@interface MTIContextOptions : NSObject <NSCopying>

@property (nonatomic,copy,nullable) NSDictionary<NSString *,id> *coreImageContextOptions;

@property (nonatomic) MTLPixelFormat workingPixelFormat;

@property (nonatomic) BOOL enablesRenderGraphOptimization;

/*! @brief A string to help identify this object */
@property (nonatomic, copy) NSString *label;

@end

FOUNDATION_EXPORT NSURL * _Nullable MTIDefaultLibraryURLForBundle(NSBundle *bundle);

@interface MTIContext : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)new NS_UNAVAILABLE;

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device error:(NSError **)error;

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device options:(MTIContextOptions *)options error:(NSError **)error NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) MTLPixelFormat workingPixelFormat;

@property (nonatomic, readonly) BOOL isRenderGraphOptimizationEnabled;

@property (nonatomic, copy, readonly) NSString *label;

@property (nonatomic, readonly) BOOL isMetalPerformanceShadersSupported;

@property (nonatomic, strong, readonly) id<MTLDevice> device;

@property (nonatomic, strong, readonly) id<MTLLibrary> defaultLibrary;

@property (nonatomic, strong, readonly) id<MTLCommandQueue> commandQueue;

@property (nonatomic, strong, readonly) MTKTextureLoader *textureLoader;

@property (nonatomic, strong, readonly) CIContext *coreImageContext;

@property (nonatomic, strong, readonly) MTICVMetalTextureCache *coreVideoTextureCache;

@property (nonatomic, class, readonly) BOOL defaultMetalDeviceSupportsMPS;

- (void)reclaimResources;

@property (nonatomic, readonly) NSUInteger idleResourceSize NS_AVAILABLE(10_13, 11_0);

@property (nonatomic, readonly) NSUInteger idleResourceCount;

@property (nonatomic) RotateMode rotateMode;
@property (nonatomic) int videoWidth;
@property (nonatomic) int videoHeight;
@property (nonatomic) CGSize viewSize;
@property (nonatomic) CGFloat viewOffsetX;//渲染偏移
@property (nonatomic) CGFloat viewOffsetY;
@property (nonatomic) BOOL blendEnable;//透明混合

@end


NS_ASSUME_NONNULL_END
