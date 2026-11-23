#include <pthread.h>
#include <semaphore.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#define RECEPTORES 4
#define ESCANERES 4
#define CLASIFICADORES 4
#define DESPACHADORES 3
#define TOTAL_PAQUETES 300
#define CAPACIDAD_ZONA 15
#define CAPACIDAD_PRIORIDAD 10
#define CAPACIDAD_NORMAL 15

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
} Trabajador;

Zona zona1, zona2;
Cola prioridad, normal;
sem_t espacios_prioridad, espacios_normal, disponibles_finales;
sem_t mutex_finales, mutex_recepcion, mutex_despachados;
int finales_cerradas;
int prioritarios_consecutivos;
int asignados;
int despachados;

int aleatorio(int minimo, int maximo) {
    return minimo + rand() % (maximo - minimo + 1);
}

void demorar(int minimo, int maximo) {
    unsigned int segundos = aleatorio(minimo, maximo);
    sleep(segundos);
}

void iniciar_cola(Cola *cola, int capacidad, const char *nombre) {
    cola->capacidad = capacidad;
    cola->nombre = nombre;
    cola->entrada = 0;
    cola->salida = 0;
    cola->cantidad = 0;
}

/* Estas dos operaciones se llaman con espacio/elemento reservado y exclusión. */
void insertar(Cola *cola, Paquete paquete) {
    cola->datos[cola->entrada] = paquete;
    cola->entrada = (cola->entrada + 1) % cola->capacidad;
    cola->cantidad++;
}

Paquete extraer(Cola *cola) {
    Paquete paquete = cola->datos[cola->salida];
    cola->salida = (cola->salida + 1) % cola->capacidad;
    cola->cantidad--;
    return paquete;
}

void iniciar_zona(Zona *zona, const char *nombre) {
    iniciar_cola(&zona->cola, CAPACIDAD_ZONA, nombre);
    sem_init(&zona->espacios, 0, CAPACIDAD_ZONA);
    sem_init(&zona->elementos, 0, 0);
    sem_init(&zona->mutex, 0, 1);
}

void depositar(Zona *zona, Paquete paquete) {
    sem_wait(&zona->espacios);
    sem_wait(&zona->mutex);
    insertar(&zona->cola, paquete);
    sem_post(&zona->elementos);
    sem_post(&zona->mutex);
}

int retirar(Zona *zona, Paquete *paquete) {
    sem_wait(&zona->elementos);
    sem_wait(&zona->mutex);
    if (zona->cerrada && zona->cola.cantidad == 0) {
        sem_post(&zona->mutex);
        return 0;
    }
    *paquete = extraer(&zona->cola);
    sem_post(&zona->mutex);
    sem_post(&zona->espacios);
    return 1;
}

/* main cierra una zona solo después del join de TODOS sus productores. */
void cerrar_zona(Zona *zona, int consumidores) {
    sem_wait(&zona->mutex);
    zona->cerrada = 1;
    sem_post(&zona->mutex);
    for (int i = 0; i < consumidores; i++) sem_post(&zona->elementos);
}

void destruir_zona(Zona *zona) {
    sem_destroy(&zona->espacios);
    sem_destroy(&zona->elementos);
    sem_destroy(&zona->mutex);
}

void *receptor(void *argumento) {
    Trabajador *trabajador = argumento;
    while (1) {
        sem_wait(&mutex_recepcion);
        if (asignados == TOTAL_PAQUETES) {
            sem_post(&mutex_recepcion);
            return NULL;
        }
        int id = ++asignados;
        sem_post(&mutex_recepcion);

        demorar(1, 2);
        Paquete paquete;
        paquete.id = id;
        paquete.peso = aleatorio(1, 20);
        paquete.prioridad = 0;
        paquete.costo = 0;
        printf("Receptor %d generó paquete %d con peso %d\n",
               trabajador->id, paquete.id, paquete.peso);
        depositar(&zona1, paquete);
    }
}

void *escaner(void *argumento) {
    Trabajador *trabajador = argumento;
    Paquete paquete;
    while (retirar(&zona1, &paquete)) {
        demorar(0, 3);
        paquete.prioridad = paquete.peso > 10;
        paquete.costo = paquete.peso * 100;
        printf("Escáner %d procesó paquete %d\n", trabajador->id, paquete.id);
        depositar(&zona2, paquete);
    }
    return NULL;
}

void *clasificador(void *argumento) {
    Trabajador *trabajador = argumento;
    Paquete paquete;
    while (retirar(&zona2, &paquete)) {
        demorar(0, 2);
        Cola *destino = paquete.prioridad ? &prioridad : &normal;
        sem_t *espacios = paquete.prioridad ? &espacios_prioridad : &espacios_normal;
        sem_wait(espacios);
        sem_wait(&mutex_finales);
        insertar(destino, paquete);
        printf("Clasificador %d envió paquete %d a cola %s\n",
               trabajador->id, paquete.id, destino->nombre);
        sem_post(&disponibles_finales);
        sem_post(&mutex_finales);
    }
    return NULL;
}

int retirar_para_despacho(Paquete *paquete, int id_despachador) {
    sem_wait(&disponibles_finales);
    sem_wait(&mutex_finales);
    if (finales_cerradas && prioridad.cantidad == 0 && normal.cantidad == 0) {
        sem_post(&mutex_finales);
        return 0;
    }

    /* La elección y la racha son compartidas por los TRES despachadores. */
    int elegir_prioridad = prioridad.cantidad > 0 &&
                          (normal.cantidad == 0 || prioritarios_consecutivos < 3);
    Cola *origen = elegir_prioridad ? &prioridad : &normal;
    int normales_esperando = normal.cantidad;
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
    sem_post(&mutex_finales);
    sem_post(elegir_prioridad ? &espacios_prioridad : &espacios_normal);
    return 1;
}

void *despachador(void *argumento) {
    Trabajador *trabajador = argumento;
    Paquete paquete;
    while (retirar_para_despacho(&paquete, trabajador->id)) {
        demorar(0, 2);
        sem_wait(&mutex_despachados);
        despachados++;
        printf("Despachador %d despachó paquete %d - peso %d - prioridad %s - costo %d\n",
               trabajador->id, paquete.id, paquete.peso,
               paquete.prioridad ? "ALTA" : "NORMAL", paquete.costo);
        sem_post(&mutex_despachados);
    }
    return NULL;
}

void esperar_grupo(pthread_t *hilos, int cantidad) {
    for (int i = 0; i < cantidad; i++) {
        pthread_join(hilos[i], NULL);
    }
}

int main(void) {
    pthread_t receptores[RECEPTORES], escaneres[ESCANERES];
    pthread_t clasificadores[CLASIFICADORES], despachadores[DESPACHADORES];
    Trabajador datos_receptores[RECEPTORES], datos_escaneres[ESCANERES];
    Trabajador datos_clasificadores[CLASIFICADORES], datos_despachadores[DESPACHADORES];
    srand(time(NULL));

    iniciar_zona(&zona1, "ZONA1");
    iniciar_zona(&zona2, "ZONA2");
    iniciar_cola(&prioridad, CAPACIDAD_PRIORIDAD, "PRIORIDAD");
    iniciar_cola(&normal, CAPACIDAD_NORMAL, "NORMAL");
    sem_init(&espacios_prioridad, 0, CAPACIDAD_PRIORIDAD);
    sem_init(&espacios_normal, 0, CAPACIDAD_NORMAL);
    sem_init(&disponibles_finales, 0, 0);
    sem_init(&mutex_finales, 0, 1);
    sem_init(&mutex_recepcion, 0, 1);
    sem_init(&mutex_despachados, 0, 1);

    for (int i = 0; i < DESPACHADORES; i++) {
        datos_despachadores[i].id = i + 1;
        pthread_create(&despachadores[i], NULL, despachador, &datos_despachadores[i]);
    }

    for (int i = 0; i < CLASIFICADORES; i++) {
        datos_clasificadores[i].id = i + 1;
        pthread_create(&clasificadores[i], NULL, clasificador, &datos_clasificadores[i]);
    }

    for (int i = 0; i < ESCANERES; i++) {
        datos_escaneres[i].id = i + 1;
        pthread_create(&escaneres[i], NULL, escaner, &datos_escaneres[i]);
    }

    for (int i = 0; i < RECEPTORES; i++) {
        datos_receptores[i].id = i + 1;
        pthread_create(&receptores[i], NULL, receptor, &datos_receptores[i]);
    }

    esperar_grupo(receptores, RECEPTORES);
    cerrar_zona(&zona1, ESCANERES);
    esperar_grupo(escaneres, ESCANERES);
    cerrar_zona(&zona2, CLASIFICADORES);
    esperar_grupo(clasificadores, CLASIFICADORES);
    sem_wait(&mutex_finales);
    finales_cerradas = 1;
    sem_post(&mutex_finales);
    for (int i = 0; i < DESPACHADORES; i++) sem_post(&disponibles_finales);
    esperar_grupo(despachadores, DESPACHADORES);

    destruir_zona(&zona1);
    destruir_zona(&zona2);
    sem_destroy(&espacios_prioridad);
    sem_destroy(&espacios_normal);
    sem_destroy(&disponibles_finales);
    sem_destroy(&mutex_finales);
    sem_destroy(&mutex_recepcion);
    sem_destroy(&mutex_despachados);
    printf("Finalizado: %d paquetes generados y %d despachados.\n", asignados, despachados);
    return 0;
}
