#ifndef PMATH_H_
#define PMATH_H_

#include <stdint.h>
#include <math.h>

#define     fpcrtl_min(a, b)                ((a) < (b) ? (a) : (b))
#define     fpcrtl_max(a, b)                ((a) > (b) ? (a) : (b))

float       fpcrtl_power(float base, float exponent);

/* Currently the games only uses sign of an integer */
int         fpcrtl_signi(int x);

float       fpcrtl_csc(float x);

#define     fpcrtl_arctan2(y, x)            atan2(y, x)

float       __attribute__((overloadable))   fpcrtl_abs(float x);
double      __attribute__((overloadable))   fpcrtl_abs(double x);
int         __attribute__((overloadable))   fpcrtl_abs(int x);
int64_t     __attribute__((overloadable))   fpcrtl_abs(int64_t x);

#endif /* PMATH_H_ */
