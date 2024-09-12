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

    CVPixelBufferRelease(pixelBuffer); // Release Pixel Buffer

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
    
    visionImage.orientation =
      [self imageOrientationFromDeviceOrientation:self.currentOrientation cameraPosition:AVCaptureDevicePositionBack];
    
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
                
                NSLog(@"Face detected at %@", NSStringFromCGRect(frame));
            }

            NSError *jsonSerializationError;
        
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:faceDictionaries options:0 error:&jsonSerializationError];
        
            if (jsonSerializationError) {
                NSLog(@"Error serializing JSON: %@", jsonSerializationError);
                return;
            }
        
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
            UnitySendMessage("ar_face_manager", "ReceiveMessage", [jsonString UTF8String]);
        }];
}

- (UIImageOrientation)
  imageOrientationFromDeviceOrientation:(UIDeviceOrientation)deviceOrientation
                         cameraPosition:(AVCaptureDevicePosition)cameraPosition {
  switch (deviceOrientation) {
    case UIDeviceOrientationPortrait:
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationLeftMirrored
                                                            : UIImageOrientationPortrait;
    case UIDeviceOrientationLandscapeLeft:
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationDownMirrored
                                                            : UIImageOrientationRight;
    case UIDeviceOrientationPortraitUpsideDown:
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationRightMirrored
                                                            : UIImageOrientationDown;
    case UIDeviceOrientationLandscapeRight:
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationUpMirrored
                                                            : UIImageOrientationLeft;
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

