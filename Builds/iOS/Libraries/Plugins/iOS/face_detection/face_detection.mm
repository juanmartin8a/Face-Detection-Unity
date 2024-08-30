#import "face_detection.h"
#import "face_detection_utils.h"

@implementation FaceDetection {
    MLKFaceDetector *faceDetector;
    CIContext *ciContext;
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
        ciContext = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @(NO)}];
        [self initializeFaceDetector];
    }
    return self;
}

- (void)initializeFaceDetector {
    MLKFaceDetectorOptions *options = [[MLKFaceDetectorOptions alloc] init];
    options.performanceMode = MLKFaceDetectorPerformanceModeAccurate;
    options.contourMode = MLKFaceDetectorContourModeNone;
    options.landmarkMode = MLKFaceDetectorLandmarkModeNone;
    options.classificationMode = MLKFaceDetectorClassificationModeNone;
    options.minFaceSize = 0.15;

    faceDetector = [MLKFaceDetector faceDetectorWithOptions:options];
}

- (void)detectFaces:(const void*)imageBytes width:(int)width height:(int)height timestamp:(double)timestamp {

    NSDictionary *pixelAttributes = @{
                (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
                (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
            };

    size_t bytesPerRow = width * 4; // Assuming RGBA32 format

    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                                   width,
                                                   height,
                                                   kCVPixelFormatType_32BGRA,
                                                   (void*)imageBytes,
                                                   bytesPerRow,
                                                   NULL,
                                                   NULL,
                                                   (__bridge CFDictionaryRef)pixelAttributes,
                                                   &pixelBuffer);
    if (status != kCVReturnSuccess) {
        NSLog(@"Unable to create pixel buffer");
    }
    
    size_t sourceWidth = CVPixelBufferGetWidth(pixelBuffer);
    size_t sourceHeight = CVPixelBufferGetHeight(pixelBuffer);
    
    CGFloat screenWidth2 = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight2 = [UIScreen mainScreen].bounds.size.height;
    
    size_t widthAC = sourceWidth;
    size_t heightAC = (screenWidth2 / screenHeight2) * sourceWidth;
    size_t startingHeightCutPos = (sourceHeight - heightAC) / 2;

    CGRect cropRect = CGRectMake(0, startingHeightCutPos, widthAC, heightAC);

    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];

    ciImage = [ciImage imageByCroppingToRect:cropRect];

    CGFloat scale = 1080 / ciImage.extent.size.width;
    
    ciImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    
    ciImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeRotation(-M_PI_2)];
    
    UIImage *uiImage = nil;

    CGImageRef cgImage = [ciContext createCGImage:ciImage fromRect:[ciImage extent]];
    if (cgImage) {
        uiImage = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage); // Don't forget to release the CGImageRef
    }
    
    MLKVisionImage *visionImage = [[MLKVisionImage alloc] initWithImage:uiImage];
    
    visionImage.orientation =
      [self imageOrientationFromDeviceOrientation:UIDevice.currentDevice.orientation
                                   cameraPosition:AVCaptureDevicePositionBack];
    
    NSLog(@"Starting face detection");
    
    [faceDetector processImage:visionImage
                    completion:^(NSArray<MLKFace *> *faces,
                                 NSError *error) {
            if (error != nil) {
                NSLog(@"Face detection error: %@", error.localizedDescription);
                return;
            }
        
            NSLog(@"Face detection completed. Found %lu faces", faces.count);
            NSMutableArray *faceDictionaries = [NSMutableArray arrayWithCapacity:faces.count];

            for (MLKFace *face in faces) {
                [faceDictionaries addObject:[FaceDetectionUtils dictionaryFromMLKFace:face]];
                
                CGRect frame = face.frame;
                
                // UnitySendMessage("Drawer", "RecieveMessage", );
                NSLog(@"Face detected at %@", NSStringFromCGRect(frame));
//                NSLog(@"Face detected at %@ at time %f", NSStringFromCGRect(frame), CMTimeGetSeconds(presentationTime));
            }

//            NSError *jsonSerializationError;
//        
//            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:faceDictionaries options:0 error:&jsonSerializationError];
//        
//            if (jsonSerializationError) {
//                NSLog(@"Error serializing JSON: %@", jsonSerializationError);
//                return;
//            }
        
//            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
//            UnitySendMessage("ar_face_manager", "ReceiveMessage", [jsonString UTF8String]);
        }];
    
//    VNDetectFaceRectanglesRequest *faceDetectionRequest = [[VNDetectFaceRectanglesRequest alloc] initWithCompletionHandler:^(VNRequest *request, NSError * _Nullable error) {
//            if (error) {
//                NSLog(@"Face detection error: %@", error.localizedDescription);
//                return;
//            }
//                
//            NSLog(@"Detected faces: %lu", (unsigned long)request.results.count);
//
//            for (VNFaceObservation *observation in request.results) {
//                // Process resutls
//            }
//    }];
//    
//    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCIImage:ciImage options:@{}];
//    NSError *error = nil;
//    [handler performRequests:@[faceDetectionRequest] error:&error];
//
//    if (error) {
//        NSLog(@"Error performing vision request: %@", error.localizedDescription);
//    }
//    
//    NSLog(@"Face detection process ended");

    CVPixelBufferRelease(pixelBuffer);
}

- (UIImageOrientation)
  imageOrientationFromDeviceOrientation:(UIDeviceOrientation)deviceOrientation
                         cameraPosition:(AVCaptureDevicePosition)cameraPosition {
  switch (deviceOrientation) {
    case UIDeviceOrientationPortrait:
        NSLog(@"Portrait orientation");
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationLeftMirrored
                                                            : UIImageOrientationUp;

    case UIDeviceOrientationLandscapeLeft:
          NSLog(@"ll orientation");
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationDownMirrored
                                                            : UIImageOrientationRight;
    case UIDeviceOrientationPortraitUpsideDown:
          NSLog(@"ud orientation");
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationRightMirrored
                                                            : UIImageOrientationDown;
    case UIDeviceOrientationLandscapeRight:
          NSLog(@"lr orientation");
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationUpMirrored
                                                            : UIImageOrientationLeft;
    case UIDeviceOrientationUnknown:
          NSLog(@"u orientation");
    case UIDeviceOrientationFaceUp:
          NSLog(@"fu orientation");
    case UIDeviceOrientationFaceDown:
          NSLog(@"fd orientation");
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


