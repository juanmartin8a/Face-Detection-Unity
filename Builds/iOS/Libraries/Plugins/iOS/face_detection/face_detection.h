#import <MLKitFaceDetection/MLKitFaceDetection.h>
#import <MLKitVision/MLKitVision.h>
#import <AVFoundation/AVFoundation.h>
#import <UnityAppController.h>
#import <UIKit/UIKit.h>
#import <Vision/Vision.h>

@interface FaceDetection : NSObject

@property (nonatomic, strong) NSMutableArray<VNTrackObjectRequest *> *trackingRequests;
//@property (nonatomic, strong) VNSequenceRequestHandler *sequenceHandler;
//@property (nonatomic, strong) NSMutableArray<VNDetectedObjectObservation *> *trackedFaces;

+ (instancetype)sharedInstance;
- (void)initializeFaceDetector;
- (void)detectFaces:(const void*)imageData width:(int)width height:(int)height screenWidth:(int)screenWidth screenHeight:(int)screenHeight timestamp:(double)timestamp;

@end

