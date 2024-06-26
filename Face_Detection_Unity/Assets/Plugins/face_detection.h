#import <MLKitFaceDetection/MLKitFaceDetection.h>
#import <MLKitVision/MLKitVision.h>
#import <AVFoundation/AVFoundation.h>
#import <UnityAppController.h>

@interface FaceDetection : NSObject

+ (instancetype)sharedInstance;
- (void)initializeFaceDetector;
- (void)detectFaces:(const void*)imageData width:(int)width height:(int)height timestamp:(double)timestamp;

@end
