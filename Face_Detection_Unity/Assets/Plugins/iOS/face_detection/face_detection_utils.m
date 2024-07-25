#import "face_detection_utils.h"

@implementation FaceDetectionUtils 

+ (NSDictionary *)dictionaryFromMLKFace:(MLKFace *)face {
    return @{
        @"trackingID": @(face.trackingID)
        @"rect": @{
            @"x": @(face.frame.origin.x),
            @"y": @(face.frame.origin.y),
            @"width": @(face.frame.size.width),
            @"height": @(face.frame.size.height)
        },
        @"headEulerAngles": @{
            @"x": @(face.headEulerAngleX),
            @"y": @(face.headEulerAngleY),
            @"z": @(face.headEulerAngleZ)
        },
    };
}

@end
