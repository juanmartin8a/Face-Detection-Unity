#import "face_detection_utils.h"

@implementation FaceDetectionUtils 

+ (NSDictionary *)dictionaryFromMLKFace:(MLKFace *)face {
    return @{
        @"boundingBox": @{
            @"x": @(face.frame.origin.x),
            @"y": @(face.frame.origin.y),
            @"width": @(face.frame.size.width),
            @"height": @(face.frame.size.height)
        },
        @"headEulerAngleX": @(face.headEulerAngleX),
        @"headEulerAngleY": @(face.headEulerAngleY),
        @"headEulerAngleZ": @(face.headEulerAngleZ),
        @"trackingID": @(face.trackingID)
    };
}

@end
