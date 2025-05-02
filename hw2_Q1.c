// montecarlo_pi_threaded.c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>

#define INTERVAL 10000

int num_threads;
int total_points = INTERVAL * INTERVAL;
int total_in_circle = 0;
pthread_mutex_t lock;

void* monte_carlo(void* arg) {
    int points = *((int*)arg);
    int local_in_circle = 0;
    unsigned int seed = (unsigned int)time(NULL) ^ (unsigned int)(size_t)pthread_self();

    for (int i = 0; i < points; i++) {
        double rand_x = (double)(rand_r(&seed) % (INTERVAL + 1)) / INTERVAL;
        double rand_y = (double)(rand_r(&seed) % (INTERVAL + 1)) / INTERVAL;
        double origin_dist = rand_x * rand_x + rand_y * rand_y;

        if (origin_dist <= 1.0)
            local_in_circle++;

        // Optional debugging output for first few points
        if (i < 5) {
            printf("x = %lf, y = %lf, in_circle = %d\n", rand_x, rand_y, local_in_circle);
        }
    }

    pthread_mutex_lock(&lock);
    total_in_circle += local_in_circle;
    pthread_mutex_unlock(&lock);
    return NULL;
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        printf("Usage: %s <num_threads>\n", argv[0]);
        return 1;
    }

    num_threads = atoi(argv[1]);
    pthread_t threads[num_threads];
    int points_per_thread = total_points / num_threads;

    pthread_mutex_init(&lock, NULL);

    for (int i = 0; i < num_threads; i++) {
        pthread_create(&threads[i], NULL, monte_carlo, &points_per_thread);
    }

    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }

    pthread_mutex_destroy(&lock);

    double pi = 4.0 * (double)total_in_circle / total_points;
    printf("\nFinal Estimation of Pi = %.6f\n", pi);
    return 0;
}