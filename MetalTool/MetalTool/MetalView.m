//
//  MetalView.m
//  MetalTool
//
//  Created by niezhiqiang on 2021/7/5.
//

#import "MetalView.h"
#import "MTIContext+Rendering.h"
#import "MTIPrint.h"
#import "MTIMPSBoxBlurFilter.h"
#import "MTIMultilayerCompositingFilter.h"
#import "MTILayer.h"
#import "MTIColorMatrixFilter.h"
#import <MetalKit/MetalKit.h>
#import <VideoToolbox/VideoToolbox.h>

@interface MetalView () <MTKViewDelegate> {
    CGRect _bounds;
}

@property (nonatomic, weak) MTKView *renderView;
@property (nonatomic, strong) MTIContext *context;
@property (nonatomic, strong, nullable) MTIImage *image;
@property (nonatomic, strong, nullable) MTIImage *cacheImage;
@property (nonatomic) MTLClearColor clearColor;
@property (nonatomic) MTIDrawableRenderingResizingMode resizingMode;

@property (nonatomic, assign) BOOL enableQualityEnhancer;
@property (nonatomic, assign) float brightness;
@property (nonatomic, assign) float contrast;
@property (nonatomic, assign) float saturation;
@property (nonatomic, strong) MTISaturationFilter *saturationFilter;
@property (nonatomic, strong) MTIBrightnessFilter *brightnessFilter;
@property (nonatomic, strong) MTIContrastFilter *contrastFilter;

@property (nonatomic, assign) DisplayMode displayMode;
@property (nonatomic, assign) BOOL enableEdgeBlur;
@property (nonatomic, strong) MTIMPSBoxBlurFilter *boxBlurFilter;
@property (nonatomic, strong) MTIMultilayerCompositingFilter *layerFilter;

@property (nonatomic, assign) BOOL alphaEnable;

@end

@implementation MetalView

#pragma mark - LifeCycle
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupImageView];
    }
    return self;
}

- (void)setupImageView {
    if (@available(iOS 11.0, *)) {
        self.accessibilityIgnoresInvertColors = YES;
    }
    _resizingMode = MTIDrawableRenderingResizingModeAspect;
    NSError *error;
    _context = [[MTIContext alloc] initWithDevice:MTLCreateSystemDefaultDevice() error:&error];
    _context.viewSize = self.bounds.size;
    MTKView *renderView = [[MTKView alloc] initWithFrame:self.bounds device:_context.device];
    renderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    renderView.delegate = self;
    [self addSubview:renderView];
    _renderView = renderView;
    
    _renderView.paused = YES;
    _renderView.enableSetNeedsDisplay = YES;    
    self.opaque = YES;//提升渲染性能
}

- (void)updateContentScaleFactor {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.renderView.frame.size.width > 0 && self.renderView.frame.size.height > 0 && self.image && self.image.size.width > 0 && self.image.size.height > 0 && self.window.screen != nil) {
            CGSize imageSize = self.image.size;
            CGFloat widthScale = imageSize.width/self.renderView.bounds.size.width;
            CGFloat heightScale = imageSize.height/self.renderView.bounds.size.height;
            CGFloat nativeScale = self.window.screen.nativeScale;
            CGFloat scale = MIN(MAX(widthScale,heightScale),nativeScale);
            if (ABS(self.renderView.contentScaleFactor - scale) > 0.00001) {
                self.renderView.contentScaleFactor = scale;
            }
        }
    });
}

- (void)setImage:(MTIImage *)image {
    _image = image;
    [self updateContentScaleFactor];
    [_renderView draw];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.bounds.size.width != _bounds.size.width || self.bounds.size.height != _bounds.size.height) {
        _bounds = self.bounds;
        [self updateContentScaleFactor];
    }
}

- (void)resetBufferSize:(CVPixelBufferRef)pixelBuffer {
    int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    int height = (int)CVPixelBufferGetHeight(pixelBuffer);
    if (height != _context.videoWidth || width != _context.videoHeight) {
        _context.videoWidth = height;
        _context.videoHeight = width;
    }
}

#pragma mark - MTKViewDelegate
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}

- (void)drawInMTKView:(MTKView *)view {
    @autoreleasepool {
        if (_image) {
            NSAssert(_context != nil, @"Context is nil.");
            MTIDrawableRenderingRequest *request = [[MTIDrawableRenderingRequest alloc] init];
            request.drawableProvider = _renderView;
            request.resizingMode = _resizingMode;
            [_context renderImage:_image toDrawableWithRequest:request error:nil];
        }
    }
}

#pragma mark - Private
- (MTIImage *)enhancedImageQuality:(MTIImage *)inputImage {
    _saturationFilter.inputImage = inputImage;
    _brightnessFilter.inputImage = _saturationFilter.outputImage;
    _contrastFilter.inputImage = _brightnessFilter.outputImage;
    MTIImage *outputImage = _contrastFilter.outputImage;
    
    return outputImage;
}

- (MTIImage *)blurImage:(MTIImage *)inputImage {
    CGFloat width = _bounds.size.width;
    CGFloat heigth = _bounds.size.height;
    if (_context.rotateMode == RotateMode90 || _context.rotateMode == RotateMode270) {
        width = _bounds.size.height;
        heigth = _bounds.size.width;
    }
    
    CGFloat videoWidth = inputImage.size.width;
    CGFloat videoHeigth = inputImage.size.height;
    CGPoint layerPoint = CGPointMake(inputImage.size.width * 0.5, inputImage.size.height * 0.5);
    CGSize layerSize;
    CGFloat viewWHProportion = width/heigth;
    CGFloat videoWHProportion = videoWidth/videoHeigth;
    if (viewWHProportion >= videoWHProportion) {
        layerSize.width = videoWidth * heigth/(width/videoWHProportion);
        layerSize.height = videoHeigth * heigth/(width/videoWHProportion);
    } else {
        layerSize.width = videoWidth * width/(heigth*videoWHProportion);
        layerSize.height = videoHeigth * width/(heigth*videoWHProportion);
    }

    _boxBlurFilter.inputImage = inputImage;
    MTIImage *backgroundImage = [_boxBlurFilter.outputImage imageWithCachePolicy:MTIImageCachePolicyPersistent];
    
    MTILayer *layer = [[MTILayer alloc] initWithContent:inputImage layoutUnit:MTILayerLayoutUnitPixel position:layerPoint size:layerSize rotation:0 opacity:1 blendMode:MTIBlendModeNormal];
    NSArray *layers = @[layer];
    _layerFilter.inputBackgroundImage = backgroundImage;
    _layerFilter.layers = layers;
    MTIImage *outputImage = [_layerFilter.outputImage imageWithCachePolicy:MTIImageCachePolicyPersistent];
    
    return outputImage;
}

- (UIImage *)renderImageToUIImage:(MTIImage *)image {
    if (!self.context || !image) {
        return nil;
    }
    
    CGFloat videoWidth = image.size.width;
    CGFloat videoHeigth = image.size.height;
    CVPixelBufferRef pixelBuffer;
    CVReturn errorCode = CVPixelBufferCreate(kCFAllocatorDefault, videoWidth, videoHeigth, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)@{(id)kCVPixelBufferIOSurfacePropertiesKey: @{}, (id)kCVPixelBufferCGImageCompatibilityKey: @YES}, &pixelBuffer);
    if (errorCode != kCVReturnSuccess) {
        return nil;
    }
    
    NSError *error;
    [self.context renderImage:image toCVPixelBuffer:pixelBuffer error:&error];
    NSAssert(error == nil, @"renderImage to pixelbuffer error when snapShot!");

    CGImageRef imageRef = NULL;
    OSStatus returnCode = VTCreateCGImageFromCVPixelBuffer(pixelBuffer, NULL, &imageRef);
    if (returnCode != noErr) {
        return nil;
    }
    
    UIImage *screenImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CVPixelBufferRelease(pixelBuffer);
    return screenImage;
}

#pragma mark - Public
- (void)drawViewWithPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    [self resetBufferSize:pixelBuffer];
    MTIImage *inputImage = [[MTIImage alloc] initWithCVPixelBuffer:pixelBuffer alphaType:MTIAlphaTypeAlphaIsOne];
    MTIImage *outputImage = inputImage;
    if (_enableQualityEnhancer) {
        outputImage = [self enhancedImageQuality:outputImage];
    }
    if (_enableEdgeBlur) {
        outputImage = [self blurImage:outputImage];
    }
    _cacheImage = outputImage;
    self.image = outputImage;
}

- (void)canvasColor:(MTLClearColor)color {
    _renderView.clearColor = color;
}

- (void)rotateMode:(RotateMode)mode {
    _context.rotateMode = mode;
}

- (void)translateX:(float)x {
    _context.viewOffsetX = x * [UIScreen mainScreen].scale;
}

- (void)translateY:(float)y {
    _context.viewOffsetY = y * [UIScreen mainScreen].scale;
}

- (void)enableQualityEnhancer:(BOOL)enable {
    _enableQualityEnhancer = enable;
    _brightness = 0.05;
    _contrast = 1.16;
    _saturation = 1.2;
    if (_enableQualityEnhancer) {
        if (!_saturationFilter) {
            self.saturationFilter = [[MTISaturationFilter alloc] init];
            _saturationFilter.saturation = _saturation;
        }
        if (!_brightnessFilter) {
            self.brightnessFilter = [[MTIBrightnessFilter alloc] init];
            _brightnessFilter.brightness = _brightness;
        }
        if (!_contrastFilter) {
            self.contrastFilter = [[MTIContrastFilter alloc] init];
            _contrastFilter.contrast = _contrast;
        }
    }
}

- (void)displayMode:(DisplayMode)mode {
    _displayMode = mode;
    if (_enableEdgeBlur) {
        return;
    }
    switch (mode) {
        case DisplayModeScaleIn:
            _resizingMode = MTIDrawableRenderingResizingModeAspect;
            break;
        case DisplayModeScaleOut:
            _resizingMode = MTIDrawableRenderingResizingModeAspectFill;
            break;
        case DisplayModeScaleFull:
            _resizingMode = MTIDrawableRenderingResizingModeScale;
            break;
        default:
            _resizingMode = MTIDrawableRenderingResizingModeAspect;
            break;
    }
}

- (void)enableEdgeBlur:(BOOL)ennable {
    _enableEdgeBlur = ennable;
    if (_enableEdgeBlur) {
        _resizingMode = MTIDrawableRenderingResizingModeAspectFill;
        if (!_boxBlurFilter) {
            self.boxBlurFilter = [[MTIMPSBoxBlurFilter alloc] init];
            _boxBlurFilter.size = 100;
        }
        if (!_layerFilter) {
            self.layerFilter = [[MTIMultilayerCompositingFilter alloc] init];
        }
    } else {
        [self displayMode:_displayMode];
    }
}

- (void)enableAlpha:(BOOL)enable {
    _alphaEnable = enable;
    if (enable) {
        _context.blendEnable = YES;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        MTLClearColor color = {0,0,0,0};
        _renderView.clearColor = color;
    } else {
        _context.blendEnable = NO;
        self.backgroundColor = [UIColor blackColor];
        self.opaque = YES;
        MTLClearColor color = {0,0,0,1};
        _renderView.clearColor = color;
    }
}

- (UIImage *)snapShot {
    return [self renderImageToUIImage:_cacheImage];
}

@end
