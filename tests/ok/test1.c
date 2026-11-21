#include <stdio.h>
int main() {
    int a = 2;
    int b = 3;
    int step = 1;
    int total = a + b;
    int diff = b - a;
    float x = 1.5;
    float y = 2.0;
    float prod = x * y;
    float ratio = y / x;
    char flag = 'A';
    printf("total=%d diff=%d\n", total, diff);
    printf("prod=%f ratio=%f\n", prod, ratio);
    if (total > diff) {
        printf("total bigger\n");
    }
    while (a < b) {
        a = a + step;
        printf("a=%d\n", a);
    }
    if (flag == 'A') {
        printf("flag ok\n");
    }
    return 0;
}