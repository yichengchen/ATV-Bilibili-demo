//
//  LMBrotliCompressor.m
//  BrotliKit
//
//  Created by Micha Mazaheri on 4/5/18.
//  Copyright © 2018 Paw. All rights reserved.
//

#import "LMBrotliCompressor.h"

#import "LMBrotliCompression.h"

@implementation LMBrotliCompressor

+ (NSInteger)defaultQuality
{
    return LMBrotliQualityDefault;
}

+ (NSData*)compressedDataWithData:(NSData*)input
{
    return [self compressedDataWithData:input quality:self.defaultQuality];
}

+ (NSData*)compressedDataWithData:(NSData*)input quality:(NSInteger)quality
{
    return [self compressedDataWithBytes:input.bytes length:input.length quality:quality];
}

+ (NSData*)compressedDataWithBytes:(const void*)bytes length:(NSUInteger)length
{
    return [self compressedDataWithBytes:bytes length:length quality:self.defaultQuality];
}

+ (NSData*)compressedDataWithBytes:(const void*)bytes length:(NSUInteger)length quality:(NSInteger)quality
{
    return CFBridgingRelease(LMCreateBrotliCompressedData(bytes, length, quality));
}

+ (NSData*)decompressedDataWithData:(NSData*)input
{
    return [self decompressedDataWithBytes:input.bytes length:input.length];
}

+ (NSData*)decompressedDataWithData:(NSData*)input isPartialInput:(BOOL*)__isPartialInput
{
    return [self decompressedDataWithBytes:input.bytes length:input.length isPartialInput:__isPartialInput];
}

+ (NSData*)decompressedDataWithBytes:(const void*)bytes length:(NSUInteger)length
{
    bool isPartialInput;
    CFDataRef result = LMCreateBrotliDecompressedData(bytes, length, &isPartialInput);
    if (isPartialInput) {
        CFRelease(result);
        result = NULL;
        return nil;
    }
    return CFBridgingRelease(result);
}

+ (NSData*)decompressedDataWithBytes:(const void*)bytes length:(NSUInteger)length isPartialInput:(BOOL*)__isPartialInput
{
    return CFBridgingRelease(LMCreateBrotliDecompressedData(bytes, length, (bool*)__isPartialInput));
}

@end
