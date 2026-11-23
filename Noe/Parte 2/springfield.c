// Centro de distribucion Springfield (Parte 2): hilos + semaforos POSIX.
// Compilar: gcc -Wall -pthread springfield.c -o springfield
// Opcional (para probar rapido): gcc -DESCALA=20 ... divide todos los tiempos por 20.
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <semaphore.h>
#include <unistd.h>
#include <time.h>

#define TOTAL 300
#define MAX_COLA 15
#ifndef ESCALA
#define ESCALA 1
#endif

typedef struct {
    int id;
    int peso;
    int prioridad;  // 1 = alta, 0 = normal (se define al escanear)
    int costo;      // peso * 100 (se define al escanear)
} Paquete;

// Cola circular FIFO con capacidad 'cap'.
// espacio: lugares libres. items: paquetes disponibles (solo Zona 1 y Zona 2). mutex: exclusion mutua.
typedef struct {
    Paquete datos[MAX_COLA];
    int cabeza, cuenta, cap;
    sem_t espacio, items, mutex;
} Cola;

static Cola zona1, zona2, cola_prio, cola_norm;
static sem_t disponibles;     // paquetes totales en cola_prio + cola_norm
static sem_t m_cont;          // protege los contadores de abajo
static int c_generados, c_escaneados, c_clasificados, c_despachados;
static int consecutivos_prio; // prioritarios seguidos (se usa con los dos mutex de las colas tomados)

static void cola_init(Cola *c, int cap) {
    c->cabeza = c->cuenta = 0;
    c->cap = cap;
    sem_init(&c->espacio, 0, cap);
    sem_init(&c->items, 0, 0);
    sem_init(&c->mutex, 0, 1);
}

// Estas dos se llaman con el mutex de la cola ya tomado.
static void encolar(Cola *c, Paquete p) {
    c->datos[(c->cabeza + c->cuenta) % c->cap] = p;
    c->cuenta++;
}

static Paquete desencolar(Cola *c) {
    Paquete p = c->datos[c->cabeza];
    c->cabeza = (c->cabeza + 1) % c->cap;
    c->cuenta--;
    return p;
}

// Reserva el proximo numero de trabajo de una etapa: devuelve 1..TOTAL, o 0 si ya no queda nada.
static int reclamar(int *contador) {
    sem_wait(&m_cont);
    int n = (*contador < TOTAL) ? ++(*contador) : 0;
    sem_post(&m_cont);
    return n;
}

static void espera_ms(int min_ms, int max_ms, unsigned *semilla) {
    long ms = (min_ms + rand_r(semilla) % (max_ms - min_ms + 1)) / ESCALA;
    struct timespec t = { ms / 1000, (ms % 1000) * 1000000L };
    nanosleep(&t, NULL);   // usleep no garantiza soportar 1 segundo o mas
}

static void *receptor(void *arg) {
    int x = *(int *)arg;
    unsigned semilla = time(NULL) ^ (x * 7919);
    int id;
    while ((id = reclamar(&c_generados)) != 0) {      // el id sale del contador: unico y autoincremental
        espera_ms(1000, 2000, &semilla);
        Paquete p = { id, 1 + rand_r(&semilla) % 20, 0, 0 };
        sem_wait(&zona1.espacio);
        sem_wait(&zona1.mutex);
        encolar(&zona1, p);
        printf("Receptor %d generó paquete %d con peso %d\n", x, p.id, p.peso);
        sem_post(&zona1.mutex);
        sem_post(&zona1.items);
    }
    return NULL;
}

static void *escaner(void *arg) {
    int x = *(int *)arg;
    unsigned semilla = time(NULL) ^ (x * 104729);
    while (reclamar(&c_escaneados) != 0) {
        sem_wait(&zona1.items);
        sem_wait(&zona1.mutex);
        Paquete p = desencolar(&zona1);
        sem_post(&zona1.mutex);
        sem_post(&zona1.espacio);

        espera_ms(0, 3000, &semilla);
        p.prioridad = p.peso > 10;
        p.costo = p.peso * 100;

        sem_wait(&zona2.espacio);
        sem_wait(&zona2.mutex);
        encolar(&zona2, p);
        printf("Escáner %d procesó paquete %d\n", x, p.id);
        sem_post(&zona2.mutex);
        sem_post(&zona2.items);
    }
    return NULL;
}

static void *clasificador(void *arg) {
    int x = *(int *)arg;
    unsigned semilla = time(NULL) ^ (x * 1299709);
    while (reclamar(&c_clasificados) != 0) {
        sem_wait(&zona2.items);
        sem_wait(&zona2.mutex);
        Paquete p = desencolar(&zona2);
        sem_post(&zona2.mutex);
        sem_post(&zona2.espacio);

        espera_ms(0, 2000, &semilla);

        Cola *destino = p.prioridad ? &cola_prio : &cola_norm;
        sem_wait(&destino->espacio);
        sem_wait(&destino->mutex);
        encolar(destino, p);
        printf("Clasificador %d envió paquete %d a cola %s\n", x, p.id, p.prioridad ? "PRIORIDAD" : "NORMAL");
        sem_post(&destino->mutex);
        sem_post(&disponibles);
    }
    return NULL;
}

static void *despachador(void *arg) {
    int x = *(int *)arg;
    unsigned semilla = time(NULL) ^ (x * 15485863);
    while (reclamar(&c_despachados) != 0) {
        sem_wait(&disponibles);          // garantiza que hay al menos un paquete para mi
        espera_ms(0, 2000, &semilla);

        // Se toman los dos mutex (siempre en el mismo orden) para decidir con una vista consistente.
        sem_wait(&cola_prio.mutex);
        sem_wait(&cola_norm.mutex);
        Cola *origen;
        if (cola_prio.cuenta > 0 && !(consecutivos_prio >= 3 && cola_norm.cuenta > 0)) {
            origen = &cola_prio;
            consecutivos_prio++;
        } else {
            origen = &cola_norm;         // si prio esta vacia, norm tiene el paquete que reserve
            consecutivos_prio = 0;
        }
        Paquete p = desencolar(origen);
        printf("Despachador %d despachó paquete %d - peso %d - prioridad %s - costo %d\n",
               x, p.id, p.peso, p.prioridad ? "ALTA" : "NORMAL", p.costo);
        sem_post(&cola_norm.mutex);
        sem_post(&cola_prio.mutex);
        sem_post(&origen->espacio);
    }
    return NULL;
}

int main(void) {
    cola_init(&zona1, 15);
    cola_init(&zona2, 15);
    cola_init(&cola_prio, 10);
    cola_init(&cola_norm, 15);
    sem_init(&disponibles, 0, 0);
    sem_init(&m_cont, 0, 1);
    setvbuf(stdout, NULL, _IOLBF, 0);

    enum { R = 4, E = 4, C = 4, D = 3 };
    pthread_t hilos[R + E + C + D];
    int ids[R + E + C + D];
    void *(*rutinas[])(void *) = { receptor, escaner, clasificador, despachador };
    int cantidad[] = { R, E, C, D };

    int n = 0;
    for (int tipo = 0; tipo < 4; tipo++) {
        for (int i = 1; i <= cantidad[tipo]; i++, n++) {
            ids[n] = i;                  // numero de trabajador dentro de su tipo
            pthread_create(&hilos[n], NULL, rutinas[tipo], &ids[n]);
        }
    }
    for (int i = 0; i < n; i++)
        pthread_join(hilos[i], NULL);

    printf("Se despacharon los %d paquetes.\n", c_despachados);
    return 0;
}
