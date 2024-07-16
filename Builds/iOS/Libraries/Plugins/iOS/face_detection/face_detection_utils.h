#import <Foundation/Foundation.h>
#import <MLKitFaceDetection/MLKitFaceDetection.h>

@interface FaceDetectionUtils : NSObject

+ (NSDictionary *)dictionaryFromMLKFace:(MLKFace *)face;

@end

