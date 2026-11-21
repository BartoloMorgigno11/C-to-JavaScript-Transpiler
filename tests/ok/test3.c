#include <stdio.h>
void log_status(int count) {
    printf("count=%d\n", count);
}
int main() {
    int limit = 0;
    int step = 1;
    float value = 0.0;
    float inc = 1.0;
    char option = 'n';
    printf("Enter limit value option\n");
    scanf("%d %f %c", &limit, &value, &option);
    while (limit > 0) {
        log_status(limit);
        limit = limit - step;
        value = value + inc;
        printf("state=%d %f\n", limit, value);
    }
    if (option == 'y') {
        printf("option y\n");
    } else {
        printf("option not y\n");
    }
    printf("final=%d %f %c\n", limit, value, option);
    return 0;
}