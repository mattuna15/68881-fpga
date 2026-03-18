#include <stdio.h>
#include <math.h>

volatile double input = 1.0;

int main(void)
{
    double x = input;
    double s = sin(x);
    printf("sin(%f) = %f\n", x, s);
    return 0;
}
