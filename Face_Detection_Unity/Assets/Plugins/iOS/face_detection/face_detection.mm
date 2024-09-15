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
        _motionManager = [[CMMotionManager alloc] init];
        _currentOrientation = UIDeviceOrientationPortrait;
        [self startContinuousOrientationUpdates];
        ciContext = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @(NO)}];
        [self initializeFaceDetector];
    }
    return self;
}

- (void)initializeFaceDetector {
    MLKFaceDetectorOptions *options = [[MLKFaceDetectorOptions alloc] init];
    options.performanceMode = MLKFaceDetectorPerformanceModeFast;
    options.trackingEnabled = true;
    options.contourMode = MLKFaceDetectorContourModeNone;
    options.landmarkMode = MLKFaceDetectorLandmarkModeNone;
    options.classificationMode = MLKFaceDetectorClassificationModeNone;
    options.minFaceSize = 0.2;

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

    CVPixelBufferRelease(pixelBuffer);

    ciImage = [ciImage imageByCroppingToRect:cropRect];

    CGFloat scale = 1080 / ciImage.extent.size.width;
    
    ciImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    
    ciImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeRotation(-M_PI_2)];
    
    UIImage *uiImage = nil;

    CGImageRef cgImage = [ciContext createCGImage:ciImage fromRect:[ciImage extent]];
    if (cgImage) {
        uiImage = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage);
    }
    
    MLKVisionImage *visionImage = [[MLKVisionImage alloc] initWithImage:uiImage];
    
    visionImage.orientation = [self imageOrientationFromDeviceOrientation];
        
    [faceDetector processImage:visionImage
                    completion:^(NSArray<MLKFace *> *faces,
                                 NSError *error) {
            NSMutableArray *faceDictionaries = [NSMutableArray array];
            if (error != nil) {
                NSLog(@"Face detection error: %@", error.localizedDescription);
                NSDictionary *jsonDict = @{
                    @"imageHeight": @(uiImage.size.height),
                    @"imageWidth": @(uiImage.size.width),
                    @"faces": faceDictionaries
                };

                NSError *jsonSerializationError;

                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&jsonSerializationError];

                if (jsonSerializationError) {
                    NSLog(@"Error serializing JSON: %@", jsonSerializationError);
                    return;
                }

                NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

                UnitySendMessage("ar_face_manager", "ReceiveMessage", [jsonString UTF8String]);
                return;
            }
        
            for (MLKFace *face in faces) {
                [faceDictionaries addObject:[FaceDetectionUtils dictionaryFromMLKFace:face]];
                
                CGRect frame = face.frame;
            }
        
        NSDictionary *jsonDict = @{
            @"imageHeight": @(uiImage.size.height),
            @"imageWidth": @(uiImage.size.width),
            @"faces": faceDictionaries
        };

        NSError *jsonSerializationError;

        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&jsonSerializationError];

        if (jsonSerializationError) {
            NSLog(@"Error serializing JSON: %@", jsonSerializationError);
            return;
        }

        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

        UnitySendMessage("ar_face_manager", "ReceiveMessage", [jsonString UTF8String]);
    }];
    
    // Uncomment for apple vision method (no tracking)
    
//    CGImagePropertyOrientation orientation = [self cgImageOrientationFromDeviceOrientation];
//    
//    VNImageRequestHandler *imageRequestHandler = [[VNImageRequestHandler alloc] initWithCIImage:ciImage orientation:orientation options:@{}];
//
//    VNDetectFaceRectanglesRequest *faceDetectionRequest = [[VNDetectFaceRectanglesRequest alloc] initWithCompletionHandler:^(VNRequest *request, NSError * _Nullable error) {
//
//        NSMutableArray *faceDictionaries = [NSMutableArray array];
//        if (error != nil) {
//            NSLog(@"Face detection error: %@", error.localizedDescription);
//
//            NSDictionary *jsonDict = @{
//                @"imageHeight": @(ciImage.extent.size.height),
//                @"imageWidth": @(ciImage.extent.size.width),
//                @"faces": faceDictionaries
//            };
//
//            NSError *jsonSerializationError;
//
//            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&jsonSerializationError];
//
//            if (jsonSerializationError) {
//                NSLog(@"Error serializing JSON: %@", jsonSerializationError);
//                return;
//            }
//
//            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
//
//            UnitySendMessage("ar_face_manager", "ReceiveMessage", [jsonString UTF8String]);
//            return;
//        }
//
//        NSArray<VNFaceObservation *> *observations = request.results;
//
//        NSLog(@"Face detection completed. Found %lu faces", (unsigned long)observations.count);
//
//        for (VNFaceObservation *observation in observations) {
//
//            CGRect faceRect = [self convertRectFromNormalizedCoordinates:observation.boundingBox imageSize:ciImage.extent.size];
//
//            NSLog(@"Face detected at %@", NSStringFromCGRect(faceRect));
//
//            NSDictionary *faceDict = [self dictionaryFromVNFaceObservation:observation imageSize:ciImage.extent.size];
//
//            [faceDictionaries addObject:faceDict];
//        }
//
//        NSDictionary *jsonDict = @{
//            @"imageHeight": @(ciImage.extent.size.height),
//            @"imageWidth": @(ciImage.extent.size.width),
//            @"faces": faceDictionaries
//        };
//
//        NSError *jsonSerializationError;
//
//        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&jsonSerializationError];
//
//        if (jsonSerializationError) {
//            NSLog(@"Error serializing JSON: %@", jsonSerializationError);
//            return;
//        }
//
//        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
//
//        UnitySendMessage("ar_face_manager", "ReceiveMessage", [jsonString UTF8String]);
//    }];
//
//    NSError *performError = nil;
//    BOOL success = [imageRequestHandler performRequests:@[faceDetectionRequest] error:&performError];
//
//    if (!success) {
//        NSLog(@"Error performing face detection: %@", performError.localizedDescription);
//    }
}

// Uncomment for apple vision method
//- (CGImagePropertyOrientation)cgImageOrientationFromDeviceOrientation {
//    switch (self.currentOrientation) {
//        case UIDeviceOrientationPortrait:
//            return kCGImagePropertyOrientationUp;
//        case UIDeviceOrientationLandscapeLeft:
//            return kCGImagePropertyOrientationRight;
//        case UIDeviceOrientationPortraitUpsideDown:
//            return kCGImagePropertyOrientationDown;
//        case UIDeviceOrientationLandscapeRight:
//            return kCGImagePropertyOrientationLeft;
//        default:
//            return kCGImagePropertyOrientationRight;
//    }
//}
//
// Uncomment for apple vision method
//- (CGRect)convertRectFromNormalizedCoordinates:(CGRect)normalizedRect imageSize:(CGSize)imageSize {
//    CGFloat x = normalizedRect.origin.x * imageSize.width;
//    CGFloat y = (1 - normalizedRect.origin.y - normalizedRect.size.height) * imageSize.height;
//    CGFloat width = normalizedRect.size.width * imageSize.width;
//    CGFloat height = normalizedRect.size.height * imageSize.height;
//    return CGRectMake(x, y, width, height);
//}
//
// Uncomment for apple vision method
//- (NSDictionary *)dictionaryFromVNFaceObservation:(VNFaceObservation *)observation imageSize:(CGSize)imageSize {
//
//    CGRect faceRect = [self convertRectFromNormalizedCoordinates:observation.boundingBox imageSize:imageSize];
//
//    return @{
//        @"trackingId": @-1,
//        @"rect": @{
//            @"x": @(faceRect.origin.x),
//            @"y": @(faceRect.origin.y),
//            @"width": @(faceRect.size.width),
//            @"height": @(faceRect.size.height)
//        },
//        @"headEulerAngles": @{
//            @"x": @0,
//            @"y": @0,
//            @"z": @0
//        }
//    };
//}

- (UIImageOrientation)imageOrientationFromDeviceOrientation {
  switch (self.currentOrientation) {
    case UIDeviceOrientationPortrait:
      return UIImageOrientationUp;
    case UIDeviceOrientationLandscapeLeft:
      return UIImageOrientationRight;
    case UIDeviceOrientationPortraitUpsideDown:
      return UIImageOrientationDown;
    case UIDeviceOrientationLandscapeRight:
      return UIImageOrientationLeft;
          
    default:
      return UIImageOrientationUp;
  }
}

- (void)startContinuousOrientationUpdates {
    if (self.motionManager.isAccelerometerAvailable) {
        self.motionManager.accelerometerUpdateInterval = 1.0 / 10.0;
        
        __weak __typeof__(self) weakSelf = self;
        [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue]
                                                withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
            if (error) {
                NSLog(@"Error: %@", error);
                return;
            }
            
            [weakSelf updateDeviceOrientationWithAccelerometerData:accelerometerData];
        }];
    } else {
        NSLog(@"Accelerometer is not available.");
    }
}

- (void)updateDeviceOrientationWithAccelerometerData:(CMAccelerometerData *)accelerometerData {
    CMAcceleration acceleration = accelerometerData.acceleration;
    UIDeviceOrientation newOrientation = self.currentOrientation;

    if (acceleration.x >= 0.75) {
        newOrientation = UIDeviceOrientationLandscapeLeft;
    } else if (acceleration.x <= -0.75) {
        newOrientation = UIDeviceOrientationLandscapeRight;
    } else if (acceleration.y <= -0.75) {
        newOrientation = UIDeviceOrientationPortrait;
    } else if (acceleration.y >= 0.75) {
        newOrientation = UIDeviceOrientationPortraitUpsideDown;
    } else {
        newOrientation = UIDeviceOrientationPortrait; // Flat or undetermined
    }
    
    if (newOrientation != self.currentOrientation) {
        _currentOrientation = newOrientation;
        NSLog(@"Updated Orientation: %ld", (long)self.currentOrientation);
    }
}

- (void)stopContinuousOrientationUpdates {
    [self.motionManager stopAccelerometerUpdates];
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
