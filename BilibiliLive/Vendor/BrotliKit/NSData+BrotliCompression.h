//
//  NSData+BrotliCompression.h
//  BrotliKit
//
//  Created by Micha Mazaheri on 4/5/18.
//  Copyright © 2018 Paw. All rights reserved.
//

@import Foundation;

@interface NSData (BrotliCompression)

- (nullable NSData*)compressBrotli;
- (nullable NSData*)decompressBrotli;

@end
