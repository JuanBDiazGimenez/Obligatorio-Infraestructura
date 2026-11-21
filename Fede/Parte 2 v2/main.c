#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <pthread.h>
#include <semaphore.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define RECEPTORES 4
#define ESCANERES 4
#define CLASIFICADORES 4
#define DESPACHADORES 3
#define TOTAL_PAQUETES 300
#define CAPACIDAD_ZONA 15
#define CAPACIDAD_PRIORIDAD 10
#define CAPACIDAD_NORMAL 15

/* Las pruebas pueden reducir la unidad; la ejecución normal usa segundos. */
#ifndef UNIDAD_MS
#define UNIDAD_MS 1000
#endif
#ifndef SEMILLA
#define SEMILLA ((unsigned int)time(NULL))
#endif

#ifdef TRAZAS
#define TRAZA(...) printf(__VA_ARGS__)
#else
#define TRAZA(...) ((void)0)
#endif

typedef struct {
    int id;
    int peso;
    int prioridad;
    int costo;
} Paquete;

typedef struct {
    Paquete datos[CAPACIDAD_ZONA];
    int capacidad;
    int entrada;
    int salida;
    int cantidad;
    const char *nombre;
} Cola;

typedef struct {
    Cola cola;
    sem_t espacios;
    sem_t elementos;
    sem_t mutex;
    int cerrada;
} Zona;

typedef struct {
    int id;
    unsigned int semilla;
} Trabajador;

static Zona zona1, zona2;
static Cola prioridad, normal;
static sem_t espacios_prioridad, espacios_normal, disponibles_finales;
static sem_t mutex_finales, mutex_recepcion, mutex_despachados;
static int finales_cerradas;
static int prioritarios_consecutivos;
static int asignados;
static int despachados;

static void fallar(const char *operacion) {
    perror(operacion);
    exit(EXIT_FAILURE);
}

static void esperar(sem_t *semaforo) {
    while (sem_wait(semaforo) == -1) {
        if (errno != EINTR) fallar("sem_wait");
    }
}

static void avisar(sem_t *semaforo) {
    if (sem_post(semaforo) == -1) fallar("sem_post");
}

static void iniciar_semaforo(sem_t *semaforo, unsigned int valor) {
    if (sem_init(semaforo, 0, valor) == -1) fallar("sem_init");
}

static void destruir_semaforo(sem_t *semaforo) {
    if (sem_destroy(semaforo) == -1) fallar("sem_destroy");
}

static int aleatorio(Trabajador *trabajador, int minimo, int maximo) {
    return minimo + (int)(rand_r(&trabajador->semilla) %
                         (unsigned int)(maximo - minimo + 1));
}

static void demorar(Trabajador *trabajador, int minimo, int maximo) {
    int milisegundos = aleatorio(trabajador, minimo, maximo) * UNIDAD_MS;
    struct timespec tiempo = {milisegundos / 1000,
                              (milisegundos % 1000) * 1000000L};
    while (nanosleep(&tiempo, &tiempo) == -1) {
        if (errno != EINTR) fallar("nanosleep");
    }
}

static void iniciar_cola(Cola *cola, int capacidad, const char *nombre) {
    *cola = (Cola){.capacidad = capacidad, .nombre = nombre};
}

/* Estas dos operaciones se llaman con espacio/elemento reservado y exclusión. */
static void insertar(Cola *cola, Paquete paquete) {
    cola->datos[cola->entrada] = paquete;
    cola->entrada = (cola->entrada + 1) % cola->capacidad;
    cola->cantidad++;
    TRAZA("TRAZA ENTRA %s %d %d\n", cola->nombre, paquete.id, cola->cantidad);
}

static Paquete extraer(Cola *cola) {
    Paquete paquete = cola->datos[cola->salida];
    cola->salida = (cola->salida + 1) % cola->capacidad;
    cola->cantidad--;
    TRAZA("TRAZA SALE %s %d %d\n", cola->nombre, paquete.id, cola->cantidad);
    return paquete;
}

static void iniciar_zona(Zona *zona, const char *nombre) {
    iniciar_cola(&zona->cola, CAPACIDAD_ZONA, nombre);
    iniciar_semaforo(&zona->espacios, CAPACIDAD_ZONA);
    iniciar_semaforo(&zona->elementos, 0);
    iniciar_semaforo(&zona->mutex, 1);
}

static void depositar(Zona *zona, Paquete paquete) {
    esperar(&zona->espacios);
    esperar(&zona->mutex);
    insertar(&zona->cola, paquete);
    avisar(&zona->elementos);
    avisar(&zona->mutex);
}

static int retirar(Zona *zona, Paquete *paquete) {
    esperar(&zona->elementos);
    esperar(&zona->mutex);
    if (zona->cerrada && zona->cola.cantidad == 0) {
        avisar(&zona->mutex);
        return 0;
    }
    *paquete = extraer(&zona->cola);
    avisar(&zona->mutex);
    avisar(&zona->espacios);
    return 1;
}

/* main cierra una zona solo después del join de TODOS sus productores. */
static void cerrar_zona(Zona *zona, int consumidores) {
    esperar(&zona->mutex);
    zona->cerrada = 1;
    avisar(&zona->mutex);
    for (int i = 0; i < consumidores; i++) avisar(&zona->elementos);
}

static void destruir_zona(Zona *zona) {
    destruir_semaforo(&zona->espacios);
    destruir_semaforo(&zona->elementos);
    destruir_semaforo(&zona->mutex);
}

static void *receptor(void *argumento) {
    Trabajador *trabajador = argumento;
    while (1) {
        esperar(&mutex_recepcion);
        if (asignados == TOTAL_PAQUETES) {
            avisar(&mutex_recepcion);
            return NULL;
        }
        int id = ++asignados;
        avisar(&mutex_recepcion);

        demorar(trabajador, 1, 2);
        Paquete paquete = {.id = id, .peso = aleatorio(trabajador, 1, 20)};
        printf("Receptor %d generó paquete %d con peso %d\n",
               trabajador->id, paquete.id, paquete.peso);
        depositar(&zona1, paquete);
    }
}

static void *escaner(void *argumento) {
    Trabajador *trabajador = argumento;
    Paquete paquete;
    while (retirar(&zona1, &paquete)) {
        demorar(trabajador, 0, 3);
        paquete.prioridad = paquete.peso > 10;
        paquete.costo = paquete.peso * 100;
        printf("Escáner %d procesó paquete %d\n", trabajador->id, paquete.id);
        depositar(&zona2, paquete);
    }
    return NULL;
}

static void *clasificador(void *argumento) {
    Trabajador *trabajador = argumento;
    Paquete paquete;
    while (retirar(&zona2, &paquete)) {
        demorar(trabajador, 0, 2);
        Cola *destino = paquete.prioridad ? &prioridad : &normal;
        sem_t *espacios = paquete.prioridad ? &espacios_prioridad : &espacios_normal;
        esperar(espacios);
        esperar(&mutex_finales);
        insertar(destino, paquete);
        printf("Clasificador %d envió paquete %d a cola %s\n",
               trabajador->id, paquete.id, destino->nombre);
        avisar(&disponibles_finales);
        avisar(&mutex_finales);
    }
    return NULL;
}

static int retirar_para_despacho(Paquete *paquete, int id_despachador) {
    esperar(&disponibles_finales);
    esperar(&mutex_finales);
    if (finales_cerradas && prioridad.cantidad == 0 && normal.cantidad == 0) {
        avisar(&mutex_finales);
        return 0;
    }

    /* La elección y la racha son compartidas por los TRES despachadores. */
    int elegir_prioridad = prioridad.cantidad > 0 &&
                          (normal.cantidad == 0 || prioritarios_consecutivos < 3);
    Cola *origen = elegir_prioridad ? &prioridad : &normal;
    int normales_esperando = normal.cantidad;
    TRAZA("TRAZA ELEGIR %s %d %d %d\n", origen->nombre,
          prioridad.cantidad, normal.cantidad, prioritarios_consecutivos);
    *paquete = extraer(origen);
    if (elegir_prioridad) {
        if (prioritarios_consecutivos < 3) prioritarios_consecutivos++;
    } else {
        prioritarios_consecutivos = 0;
    }
    /* Registrar el inicio antes de liberar el turno; la demora sigue en paralelo. */
    printf("Despachador %d inició despacho de paquete %d - prioridad %s - normales esperando al elegir %d - contador prioridad %d\n",
           id_despachador, paquete->id, paquete->prioridad ? "ALTA" : "NORMAL",
           normales_esperando, prioritarios_consecutivos);
    avisar(&mutex_finales);
    avisar(elegir_prioridad ? &espacios_prioridad : &espacios_normal);
    return 1;
}

static void *despachador(void *argumento) {
    Trabajador *trabajador = argumento;
    Paquete paquete;
    while (retirar_para_despacho(&paquete, trabajador->id)) {
        demorar(trabajador, 0, 2);
        esperar(&mutex_despachados);
        despachados++;
        printf("Despachador %d despachó paquete %d - peso %d - prioridad %s - costo %d\n",
               trabajador->id, paquete.id, paquete.peso,
               paquete.prioridad ? "ALTA" : "NORMAL", paquete.costo);
        avisar(&mutex_despachados);
    }
    return NULL;
}

static void crear_grupo(pthread_t *hilos, Trabajador *datos, int cantidad,
                        void *(*funcion)(void *), unsigned int semilla) {
    for (int i = 0; i < cantidad; i++) {
        datos[i] = (Trabajador){.id = i + 1, .semilla = semilla + (unsigned int)i};
        int error = pthread_create(&hilos[i], NULL, funcion, &datos[i]);
        if (error != 0) {
            fprintf(stderr, "pthread_create: %s\n", strerror(error));
            exit(EXIT_FAILURE);
        }
    }
}

static void esperar_grupo(pthread_t *hilos, int cantidad) {
    for (int i = 0; i < cantidad; i++) {
        int error = pthread_join(hilos[i], NULL);
        if (error != 0) {
            fprintf(stderr, "pthread_join: %s\n", strerror(error));
            exit(EXIT_FAILURE);
        }
    }
}

int main(void) {
    pthread_t receptores[RECEPTORES], escaneres[ESCANERES];
    pthread_t clasificadores[CLASIFICADORES], despachadores[DESPACHADORES];
    Trabajador datos_receptores[RECEPTORES], datos_escaneres[ESCANERES];
    Trabajador datos_clasificadores[CLASIFICADORES], datos_despachadores[DESPACHADORES];
    unsigned int semilla = SEMILLA;
    setvbuf(stdout, NULL, _IOLBF, 0);

    iniciar_zona(&zona1, "ZONA1");
    iniciar_zona(&zona2, "ZONA2");
    iniciar_cola(&prioridad, CAPACIDAD_PRIORIDAD, "PRIORIDAD");
    iniciar_cola(&normal, CAPACIDAD_NORMAL, "NORMAL");
    iniciar_semaforo(&espacios_prioridad, CAPACIDAD_PRIORIDAD);
    iniciar_semaforo(&espacios_normal, CAPACIDAD_NORMAL);
    iniciar_semaforo(&disponibles_finales, 0);
    iniciar_semaforo(&mutex_finales, 1);
    iniciar_semaforo(&mutex_recepcion, 1);
    iniciar_semaforo(&mutex_despachados, 1);

    crear_grupo(despachadores, datos_despachadores, DESPACHADORES, despachador, semilla + 300);
    crear_grupo(clasificadores, datos_clasificadores, CLASIFICADORES, clasificador, semilla + 200);
    crear_grupo(escaneres, datos_escaneres, ESCANERES, escaner, semilla + 100);
    crear_grupo(receptores, datos_receptores, RECEPTORES, receptor, semilla);

    esperar_grupo(receptores, RECEPTORES);
    cerrar_zona(&zona1, ESCANERES);
    esperar_grupo(escaneres, ESCANERES);
    cerrar_zona(&zona2, CLASIFICADORES);
    esperar_grupo(clasificadores, CLASIFICADORES);
    esperar(&mutex_finales);
    finales_cerradas = 1;
    avisar(&mutex_finales);
    for (int i = 0; i < DESPACHADORES; i++) avisar(&disponibles_finales);
    esperar_grupo(despachadores, DESPACHADORES);

    destruir_zona(&zona1);
    destruir_zona(&zona2);
    destruir_semaforo(&espacios_prioridad);
    destruir_semaforo(&espacios_normal);
    destruir_semaforo(&disponibles_finales);
    destruir_semaforo(&mutex_finales);
    destruir_semaforo(&mutex_recepcion);
    destruir_semaforo(&mutex_despachados);
    printf("Finalizado: %d paquetes generados y %d despachados.\n", asignados, despachados);
    return despachados == TOTAL_PAQUETES ? EXIT_SUCCESS : EXIT_FAILURE;
}
