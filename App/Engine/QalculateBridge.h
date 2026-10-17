#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface QCalculationResult : NSObject
@property(nonatomic, copy) NSString *text;
@property(nonatomic, copy) NSString *latex;
@property(nonatomic, copy) NSString *inputLatex;
@property(nonatomic, copy) NSArray<NSString *> *warnings;
@property(nonatomic, copy, nullable) NSString *error;
@property(nonatomic) BOOL approximate;
@end
@interface QalculateBridge : NSObject
- (QCalculationResult *)evaluate:(NSString *)expression exact:(BOOL)exact degrees:(BOOL)degrees;
@end
NS_ASSUME_NONNULL_END
