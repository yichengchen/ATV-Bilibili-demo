//
//  LMBrotliCompression.c
//  BrotliKit
//
//  Created by Micha Mazaheri on 4/5/18.
//  Copyright © 2018 Paw. All rights reserved.
//

#include "LMBrotliCompression.h"

#include <stdio.h>
#include <stdlib.h>

#include "decode.h"
#include "encode.h"

int16_t LMBrotliQualityDefault = BROTLI_DEFAULT_QUALITY;
int16_t LMBrotliQualityMin = BROTLI_MIN_QUALITY;
int16_t LMBrotliQualityMax = BROTLI_MAX_QUALITY;

CFDataRef LMCreateBrotliCompressedData(const void* bytes, CFIndex length, int16_t quality)
{
    if (bytes == NULL || length == 0) {
        return NULL;
    }
    
    // malloc the buffer
    const size_t maxOutputSize = BrotliEncoderMaxCompressedSize(length);
    UInt8* outputBuffer = malloc(maxOutputSize * sizeof(UInt8));
    
    // compress
    size_t outputSize = maxOutputSize;
    bool success = 0 != BrotliEncoderCompress((int)quality,
                                              BROTLI_DEFAULT_WINDOW,
                                              BROTLI_MODE_GENERIC,
                                              (size_t)length,
                                              (uint8_t*)bytes,
                                              &outputSize,
                                              (uint8_t*)outputBuffer);
    
    // if failure, free buffer and return nil
    if (!success) {
        if (outputBuffer != NULL) {
            free(outputBuffer);
            outputBuffer = NULL;
        }
        return NULL;
    }
    
    // copy output data to a new NSData
    CFDataRef outputData = CFDataCreate(kCFAllocatorDefault, outputBuffer, outputSize);
    
    // free output buffer
    free(outputBuffer);
    outputBuffer = NULL;
    
    return outputData;
}

CFDataRef LMCreateBrotliDecompressedData(const void* bytes, CFIndex length, bool* __isPartialInput)
{
    // Inspired by: https://github.com/karlvr/Brotli

    // init input stream
    size_t available_in = length;
    const UInt8 *next_in = bytes;
    
    // create the output buffer
    size_t outputBufferSize = 0;
    size_t outputBufferCapacity = 8192;
    UInt8* outputBuffer = (UInt8*)malloc(outputBufferCapacity * sizeof(UInt8));

    // create Brotli instance
    BrotliDecoderState *s = BrotliDecoderCreateInstance(NULL, NULL, NULL);
    BrotliDecoderResult result = BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT;
    size_t total_out = 0;
    
    // loop while the decoder wants more space to output
    while (result == BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT) {
        size_t available_out = outputBufferCapacity - outputBufferSize;
        UInt8* next_out = outputBuffer + outputBufferSize;
        
        // decompress
        result = BrotliDecoderDecompressStream(s, &available_in, &next_in, &available_out, &next_out, &total_out);
        outputBufferSize = outputBufferCapacity - available_out;
        
        // if too little space is left, double the capacity
        if (available_out < 8192) {
            outputBufferCapacity *= 2;
            outputBuffer = realloc(outputBuffer, outputBufferCapacity * sizeof(UInt8));
        }
    }
    
    // destroy Brotli decoder
    BrotliDecoderDestroyInstance(s);

    // if invalid state, return NULL
    if (result != BROTLI_DECODER_RESULT_SUCCESS && result != BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT) {
        free(outputBuffer);
        outputBuffer = NULL;
        return NULL;
    }
    
    // copy output data to a new NSData
    CFDataRef outputData = CFDataCreate(kCFAllocatorDefault, outputBuffer, outputBufferSize);
    
    // free output buffer
    free(outputBuffer);
    outputBuffer = NULL;
    
    if (__isPartialInput != NULL) {
        *__isPartialInput = (result == BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT);
    }
    
    return outputData;
}
