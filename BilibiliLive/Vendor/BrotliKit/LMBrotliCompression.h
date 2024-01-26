//
//  LMBrotliCompression.h
//  BrotliKit
//
//  Created by Micha Mazaheri on 4/5/18.
//  Copyright © 2018 Paw. All rights reserved.
//

#ifndef LMBrotliCompression_h
#define LMBrotliCompression_h

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFData.h>

CF_EXPORT int16_t LMBrotliQualityDefault;
CF_EXPORT int16_t LMBrotliQualityMin;
CF_EXPORT int16_t LMBrotliQualityMax;

/**
 Creates a newly created CFData.
 The input is compressed via the Brotli algorithm.

 @param bytes Input bytes.
 @param length Input length (number of bytes).
 @param quality Quality value, should be between LMBrotliQualityMin (0) and LMBrotliQualityMax (11).
 @return Return the newly created compressed data.
 */
CF_EXPORT CFDataRef LMCreateBrotliCompressedData(const void* bytes, CFIndex length, int16_t quality);

/**
 Creates a newly created CFData.
 The input is decompressed via the Brotli algorithm.
 
 @param bytes Input bytes.
 @param length Input length (number of bytes).
 @param isPartialInput An optional pointer, set to true if the input was only partial.
 @return Return the newly created decompressed data.
 */
CF_EXPORT CFDataRef LMCreateBrotliDecompressedData(const void* bytes, CFIndex length, bool* isPartialInput);

#endif /* LMBrotliCompression_h */
