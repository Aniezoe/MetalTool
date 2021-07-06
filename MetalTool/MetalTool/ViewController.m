//
//  ViewController.m
//  MetalTool
//
//  Created by niezhiqiang on 2021/7/5.
//

#import "ViewController.h"
#import "MetalView.h"

@import AVFoundation;

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate> {
    dispatch_queue_t _cameraProcessingQueue;// 图像采集队列
    dispatch_queue_t _renderQueue;// 渲染队列
    dispatch_semaphore_t _frameCaptureSemaphore;// 图像采集队列信号量
}

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) MetalView *metalView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self.view addSubview:self.metalView];
    [self start];
}

- (void)start {
    if (![self.captureSession isRunning]) {
        [self.captureSession startRunning];
    }
}

- (void)stop {
    [self.captureSession stopRunning];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!_captureSession.isRunning) {
        return;
    }
    if (dispatch_semaphore_wait(_frameCaptureSemaphore, DISPATCH_TIME_NOW) != 0) {
        return;
    }
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    dispatch_sync(_renderQueue, ^{
        [self.metalView drawViewWithPixelBuffer:pixelBuffer];
    });
    dispatch_semaphore_signal(_frameCaptureSemaphore);
}

#pragma mark - Lazy
- (AVCaptureSession *)captureSession {
    if (!_captureSession) {
        _cameraProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0);
        _renderQueue = dispatch_queue_create("com.metalTool.renderQueue", DISPATCH_QUEUE_SERIAL);
        _frameCaptureSemaphore = dispatch_semaphore_create(1);
        
        _captureSession = [[AVCaptureSession alloc] init];
        [_captureSession beginConfiguration];
        _captureSession.sessionPreset = AVCaptureSessionPresetiFrame1280x720;
        AVCaptureDevice *inputCamera = nil;
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices) {
            if ([device position] == AVCaptureDevicePositionFront) {
                inputCamera = device;
            }
        }
        AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:inputCamera error:nil];
        if ([_captureSession canAddInput:input]) {
            [_captureSession addInput:input];
        }
        AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        [videoOutput setSampleBufferDelegate:self queue:_cameraProcessingQueue];
        if ([_captureSession canAddOutput:videoOutput]) {
            [_captureSession addOutput:videoOutput];
        }
        [_captureSession commitConfiguration];
    }
    return _captureSession;
}

- (MetalView *)metalView {
    if (!_metalView) {
        _metalView = [[MetalView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 300)];
//        // 画布底色
//        MTLClearColor color = {1,0,0,0};
//        [_metalView canvasColor:color];
        // 摄像头出来的图像默认横屏需要做个旋转镜像
        [_metalView rotateMode:RotateMode90Mirror];
//        // 画质增强
//        [_metalView enableQualityEnhancer:YES];
//        // 展示模式
//        [_metalView displayMode:DisplayModeScaleOut];
        // 高斯边缘模糊
        [_metalView enableEdgeBlur:YES];
    }
    return _metalView;
}

@end
