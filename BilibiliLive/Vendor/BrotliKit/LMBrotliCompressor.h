//
//  LMBrotliCompressor.h
//  BrotliKit
//
//  Created by Micha Mazaheri on 4/5/18.
//  Copyright © 2018 Paw. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_SWIFT_NAME(BrotliCompressor)
@interface LMBrotliCompressor : NSObject

@property (class, nonatomic, assign, readonly) NSInteger defaultQuality;

/**
 Creates a newly created NSData, with the default compression quality.
 The input is compressed via the Brotli algorithm.
 
 @param input Input data.
 @return Return the newly created compressed data.
 */
+ (nullable NSData*)compressedDataWithData:(NSData* _Nonnull)input;

/**
 Creates a newly created NSData.
 The input is compressed via the Brotli algorithm.
 
 @param input Input data.
 @param quality Quality value, should be between LMBrotliQualityMin (0) and LMBrotliQualityMax (11).
 @return Return the newly created compressed data.
 */
+ (nullable NSData*)compressedDataWithData:(NSData* _Nonnull)input quality:(NSInteger)quality;

/**
 Creates a newly created NSData, with the default compression quality.
 The input is compressed via the Brotli algorithm.
 
 @param bytes Input bytes.
 @param length Input length (number of bytes).
 @return Return the newly created compressed data.
 */
+ (nullable NSData*)compressedDataWithBytes:(const void* _Nonnull)bytes length:(NSUInteger)length;

/**
 Creates a newly created NSData.
 The input is compressed via the Brotli algorithm.
 
 @param bytes Input bytes.
 @param length Input length (number of bytes).
 @param quality Quality value, should be between LMBrotliQualityMin (0) and LMBrotliQualityMax (11).
 @return Return the newly created compressed data.
 */
+ (nullable NSData*)compressedDataWithBytes:(const void* _Nonnull)bytes length:(NSUInteger)length quality:(NSInteger)quality;

/**
 Creates a newly created NSData.
 The input is decompressed via the Brotli algorithm.
 Will return nil (error) if the input was only partial.
 
@param input Input data.
 @return Return the newly created decompressed data.
 */
+ (nullable NSData*)decompressedDataWithData:(NSData* _Nonnull)input;

/**
 Creates a newly created NSData.
 The input is decompressed via the Brotli algorithm.
 
 @param input Input data.
 @param isPartialInput An optional pointer, set to true if the input was only partial.
 @return Return the newly created decompressed data.
 */
+ (nullable NSData*)decompressedDataWithData:(NSData* _Nonnull)input isPartialInput:(BOOL* _Nullable)isPartialInput;

/**
 Creates a newly created NSData.
 The input is decompressed via the Brotli algorithm.
 Will return nil (error) if the input was only partial.
 
 @param bytes Input bytes.
 @param length Input length (number of bytes).
 @return Return the newly created decompressed data.
 */
+ (nullable NSData*)decompressedDataWithBytes:(const void* _Nonnull)bytes length:(NSUInteger)length;

/**
 Creates a newly created NSData.
 The input is decompressed via the Brotli algorithm.
 
 @param bytes Input bytes.
 @param length Input length (number of bytes).
 @param isPartialInput An optional pointer, set to true if the input was only partial.
 @return Return the newly created decompressed data.
 */
+ (nullable NSData*)decompressedDataWithBytes:(const void* _Nonnull)bytes length:(NSUInteger)length isPartialInput:(BOOL* _Nullable)isPartialInput;

@end
