#include <stdio.h>
int inc(int value) {
    int one = 1;
    int result = value + one;
    return result;
}
float scale(float base, float factor) {
    float temp = base * factor;
    return temp;
}
void show(int amount, float measure, char tag) {
    printf("amount=%d measure=%f tag=%c\n", amount, measure, tag);
}
int main() {
    int v = 3;
    float f = 1.5;
    float factor = 2.0;
    char tag = 'Z';
    int raised = inc(v);
    float sized = scale(f, factor);
    show(raised, sized, tag);
    if (raised >= v) {
        printf("raised>=v\n");
    }
    return 0;
}