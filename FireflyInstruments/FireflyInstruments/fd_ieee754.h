//
//  fd_ieee754.h
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/14/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

#ifndef fd_ieee754_h
#define fd_ieee754_h

#include <stdlib.h>

float fd_ieee754_float_from_half(uint16_t bit_pattern);
uint16_t fd_ieee754_half_from_float(float value);

#endif /* fd_ieee754_h */
