#import <MLKitFaceDetection/MLKitFaceDetection.h>
#import <MLKitVision/MLKitVision.h>
#import <AVFoundation/AVFoundation.h>
#import <UnityAppController.h>
#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
// Uncomment for apple vision
// #import <Vision/Vision.h>

@interface FaceDetection : NSObject

@property (nonatomic, strong, readonly) CMMotionManager *motionManager;
@property (nonatomic, assign, readonly) UIDeviceOrientation currentOrientation;

+ (instancetype)sharedInstance;
- (void)initializeFaceDetector;
- (void)detectFaces:(const void*)imageData width:(int)width height:(int)height timestamp:(double)timestamp;

@end
