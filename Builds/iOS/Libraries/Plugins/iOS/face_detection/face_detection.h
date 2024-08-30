#import <MLKitFaceDetection/MLKitFaceDetection.h>
#import <MLKitVision/MLKitVision.h>
#import <AVFoundation/AVFoundation.h>
#import <UnityAppController.h>
#import <UIKit/UIKit.h>
// Uncomment line below to try apple vision framework for face detection
//#import <Vision/Vision.h>

@interface FaceDetection : NSObject

+ (instancetype)sharedInstance;
- (void)initializeFaceDetector;
- (void)detectFaces:(const void*)imageData width:(int)width height:(int)height timestamp:(double)timestamp;

@end
