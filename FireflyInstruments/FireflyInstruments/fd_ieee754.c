//
//  fd_ieee754.c
//  FireflyInstruments
//
//  Created by Denis Bohm on 7/14/16.
//  Copyright © 2016 Firefly Design LLC. All rights reserved.
//

#include "fd_ieee754.h"

#include <stdint.h>

typedef struct {
    union {
        __fp16 half;
        uint16_t uint16;
    };
} fd_ieee754_half_uint16_t;

float fd_ieee754_float_from_half(uint16_t bit_pattern) {
    fd_ieee754_half_uint16_t half_uint16 = { .uint16 = bit_pattern };
    return half_uint16.half;
}

uint16_t fd_ieee754_half_from_float(float value) {
    fd_ieee754_half_uint16_t half_uint16 = { .half = value };
    return half_uint16.uint16;
}