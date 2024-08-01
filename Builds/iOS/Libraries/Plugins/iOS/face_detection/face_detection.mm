#import "face_detection.h"
#import "face_detection_utils.h"

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
    options.performanceMode = MLKFaceDetectorPerformanceModeFast;
    options.contourMode = MLKFaceDetectorContourModeAll;
    options.landmarkMode = MLKFaceDetectorLandmarkModeNone;
    options.classificationMode = MLKFaceDetectorClassificationModeNone;
    options.minFaceSize = 0.15;

    faceDetector = [MLKFaceDetector faceDetectorWithOptions:options];
}

- (void)detectFaces:(const void*)imageBytes width:(int)width height:(int)height timestamp:(double)timestamp {
    NSLog(@"sapo");

    NSDictionary *pixelAttributes = @{(NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}};

    size_t bytesPerRow = width * 4; // Assuming RGBA32 format
    NSLog(@"Bytes per row (Expected in Objective-C): %zu", bytesPerRow);

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
    [self saveImageFromSampleBuffer:sampleBuffer width:width height:height];
    
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
            NSMutableArray *faceDictionaries = [NSMutableArray arrayWithCapacity:faces.count];

            for (MLKFace *face in faces) {
                [faceDictionaries addObject:[FaceDetectionUtils dictionaryFromMLKFace:face]];
                // Process each face
//                NSLog(@"Face detected with bounding box: %@", NSStringFromCGRect(face.frame));
                CGRect frame = face.frame;
                
                // UnitySendMessage("Drawer", "RecieveMessage", );
                NSLog(@"Face detected at %@ at time %f", NSStringFromCGRect(frame), CMTimeGetSeconds(presentationTime));
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
    
        NSLog(@"Face detection process ended");

    
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

- (void)saveImageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer width:(int)width height:(int)height {
    NSLog(@"Attempting to save image...");
    
    if (sampleBuffer == NULL) {
        NSLog(@"Error: sampleBuffer is NULL");
        return;
    }
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (imageBuffer == NULL) {
        NSLog(@"Error: Unable to get image buffer from sample buffer");
        return;
    }
    
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];
    if (ciImage == nil) {
        NSLog(@"Error: Unable to create CIImage from image buffer");
        return;
    }
    
    CIContext *temporaryContext = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [temporaryContext createCGImage:ciImage fromRect:CGRectMake(0, 0, width, height)];
    if (cgImage == NULL) {
        NSLog(@"Error: Unable to create CGImage from CIImage");
        return;
    }
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    if (image == nil) {
        NSLog(@"Error: Unable to create UIImage from CGImage");
        return;
    }
    
    NSData *imageData = UIImagePNGRepresentation(image);
    if (imageData == nil) {
        NSLog(@"Error: Unable to create PNG representation of UIImage");
        return;
    }
    
    NSString *documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;

    // New code starts here
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
    NSString *dateString = [formatter stringFromDate:[NSDate date]];
    
    NSString *fileName = [NSString stringWithFormat:@"ObjCFrame_%@.png", dateString];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fileName];
    
    NSError *error = nil;
    BOOL success = [imageData writeToFile:filePath options:NSDataWritingAtomic error:&error];
    
    if (success) {
        NSLog(@"Successfully saved image: %@", filePath);
    } else {
        NSLog(@"Failed to save image. Error: %@", error.localizedDescription);
    }
}

- (void)saveImageFromPixelBuffer:(CVPixelBufferRef)pixelBuffer width:(int)width height:(int)height {
    NSLog(@"Attempting to save image...");
    
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    if (ciImage == nil) {
        NSLog(@"Error: Unable to create CIImage from image buffer");
        return;
    }
    
    CIContext *temporaryContext = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [temporaryContext createCGImage:ciImage fromRect:CGRectMake(0, 0, width, height)];
    if (cgImage == NULL) {
        NSLog(@"Error: Unable to create CGImage from CIImage");
        return;
    }
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    if (image == nil) {
        NSLog(@"Error: Unable to create UIImage from CGImage");
        return;
    }
    
    NSData *imageData = UIImagePNGRepresentation(image);
    if (imageData == nil) {
        NSLog(@"Error: Unable to create PNG representation of UIImage");
        return;
    }
    
    NSString *documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;

    // New code starts here
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
    NSString *dateString = [formatter stringFromDate:[NSDate date]];
    
    NSString *fileName = [NSString stringWithFormat:@"ObjCFrame_pixel_%@.png", dateString];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fileName];
    
    NSError *error = nil;
    BOOL success = [imageData writeToFile:filePath options:NSDataWritingAtomic error:&error];
    
    if (success) {
        NSLog(@"Successfully saved image pixel: %@", filePath);
    } else {
        NSLog(@"Failed to save pixel image. Error: %@", error.localizedDescription);
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

