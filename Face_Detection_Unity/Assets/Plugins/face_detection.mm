#import "FaceDetection.h"

@implementation FaceDetection {
    MLKFaceDetector *faceDetector;
}

+ (instancetype)sharedInstance {
    static FaceDetection *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initPrivate];
    });
    return sharedInstance;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        [self initializeFaceDetector];
    }
    return self;
}

- (void)initializeFaceDetector {
    NSLog(@"salsa");
    MLKFaceDetectorOptions *options = [[MLKFaceDetectorOptions alloc] init];
    options.performanceMode = MLKFaceDetectorPerformanceModeAccurate;
    options.contourMode = MLKFaceDetectorContourModeAll;
    options.landmarkMode = MLKFaceDetectorLandmarkModeNone;
    options.classificationMode = MLKFaceDetectorClassificationModeNone;

    faceDetector = [MLKFaceDetector faceDetectorWithOptions:options];
}

- (void)detectFaces:(const void*)imageBytes width:(int)width height:(int)height timestamp:(double)timestamp {
    NSLog(@"sapo");
    
    CVPixelBufferRef pixelBuffer = NULL;
        CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, NULL, &pixelBuffer);
        
        if (status != kCVReturnSuccess) {
            NSLog(@"Failed to create CVPixelBuffer");
            return;
        }
    
        NSLog(@"CVPixelBuffer created successfully");
        
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
        memcpy(baseAddress, imageBytes, width * height * 4);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
        NSLog(@"Data copied to CVPixelBuffer");
        
        // Create CMSampleBuffer from CVPixelBuffer
        CMSampleBufferRef sampleBuffer = NULL;
        CMTime presentationTime = CMTimeMakeWithSeconds(timestamp, 1000000000);  // Using nanosecond precision
        
        CMSampleTimingInfo timingInfo = {
            .duration = kCMTimeInvalid,
            .presentationTimeStamp = presentationTime,
            .decodeTimeStamp = kCMTimeInvalid
        };
        CMVideoFormatDescriptionRef videoInfo = NULL;
        CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
        
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, videoInfo, &timingInfo, &sampleBuffer);
    if (sampleBuffer == NULL) {
        NSLog(@"Failed to create CMSampleBuffer from NSData");
        return;
    }
    NSLog(@"sapo 2");
    
    // MLKVisionImage *visionImage = [[MLKVisionImage alloc] initWithImage:image];
    // NSLog(@"sapo 3");
    
   MLKVisionImage *visionImage = [[MLKVisionImage alloc] initWithBuffer:sampleBuffer];
    NSLog(@"sapo 3");
    visionImage.orientation =
      [self imageOrientationFromDeviceOrientation:UIDevice.currentDevice.orientation
                                   cameraPosition:AVCaptureDevicePositionBack];
    
    NSLog(@"Starting face detection");
    
    [faceDetector processImage:visionImage
                    completion:^(NSArray<MLKFace *> *faces,
                                 NSError *error) {
            if (error != nil) {
                // Handle error
                NSLog(@"Face detection error: %@", error.localizedDescription);
                return;
            }
        
            NSLog(@"Face detection completed. Found %lu faces", faces.count);

            for (MLKFace *face in faces) {
                // Process each face
//                NSLog(@"Face detected with bounding box: %@", NSStringFromCGRect(face.frame));
                CGRect frame = face.frame;
                NSLog(@"Face detected at %@ at time %f", NSStringFromCGRect(frame), CMTimeGetSeconds(presentationTime));
            }
        }];
    
        NSLog(@"Face detection process initiated");
    
        CVPixelBufferRelease(pixelBuffer);
        CFRelease(videoInfo);
        CFRelease(sampleBuffer);
}

- (UIImageOrientation)
  imageOrientationFromDeviceOrientation:(UIDeviceOrientation)deviceOrientation
                         cameraPosition:(AVCaptureDevicePosition)cameraPosition {
  switch (deviceOrientation) {
    case UIDeviceOrientationPortrait:
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationLeftMirrored
                                                            : UIImageOrientationRight;

    case UIDeviceOrientationLandscapeLeft:
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationDownMirrored
                                                            : UIImageOrientationUp;
    case UIDeviceOrientationPortraitUpsideDown:
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationRightMirrored
                                                            : UIImageOrientationLeft;
    case UIDeviceOrientationLandscapeRight:
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationUpMirrored
                                                            : UIImageOrientationDown;
    case UIDeviceOrientationUnknown:
    case UIDeviceOrientationFaceUp:
    case UIDeviceOrientationFaceDown:
      return UIImageOrientationUp;
  }
}


@end

extern "C" {
    void InitializeFaceDetector() {
        [[FaceDetection sharedInstance] initializeFaceDetector];
    }


    void DetectFaces(const void* imageBytes, int width, int height, double timestamp) {
        [[FaceDetection sharedInstance] detectFaces:imageBytes width:width height:height timestamp:timestamp];
    }

}
