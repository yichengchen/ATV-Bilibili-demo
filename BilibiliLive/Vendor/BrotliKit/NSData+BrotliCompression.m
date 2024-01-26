//
//  NSData+BrotliCompression.m
//  BrotliKit
//
//  Created by Micha Mazaheri on 4/5/18.
//  Copyright © 2018 Paw. All rights reserved.
//

#import "NSData+BrotliCompression.h"
#import "LMBrotliCompressor.h"

@implementation NSData (BrotliCompression)

- (NSData *)compressBrotli
{
    return [LMBrotliCompressor compressedDataWithData:self];
}

- (NSData *)decompressBrotli
{
    return [LMBrotliCompressor decompressedDataWithData:self];
}

@end
