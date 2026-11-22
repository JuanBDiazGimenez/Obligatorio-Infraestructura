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

void esperar(sem_t *semaforo) {
    sem_wait(semaforo);
}

void avisar(sem_t *semaforo) {
    sem_post(semaforo);
}

void iniciar_semaforo(sem_t *semaforo, unsigned int valor) {
    sem_init(semaforo, 0, valor);
}

void destruir_semaforo(sem_t *semaforo) {
    sem_destroy(semaforo);
}

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
    iniciar_semaforo(&zona->espacios, CAPACIDAD_ZONA);
    iniciar_semaforo(&zona->elementos, 0);
    iniciar_semaforo(&zona->mutex, 1);
}

void depositar(Zona *zona, Paquete paquete) {
    esperar(&zona->espacios);
    esperar(&zona->mutex);
    insertar(&zona->cola, paquete);
    avisar(&zona->elementos);
    avisar(&zona->mutex);
}

int retirar(Zona *zona, Paquete *paquete) {
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
void cerrar_zona(Zona *zona, int consumidores) {
    esperar(&zona->mutex);
    zona->cerrada = 1;
    avisar(&zona->mutex);
    for (int i = 0; i < consumidores; i++) avisar(&zona->elementos);
}

void destruir_zona(Zona *zona) {
    destruir_semaforo(&zona->espacios);
    destruir_semaforo(&zona->elementos);
    destruir_semaforo(&zona->mutex);
}

void *receptor(void *argumento) {
    Trabajador *trabajador = argumento;
    while (1) {
        esperar(&mutex_recepcion);
        if (asignados == TOTAL_PAQUETES) {
            avisar(&mutex_recepcion);
            return NULL;
        }
        int id = ++asignados;
        avisar(&mutex_recepcion);

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

int retirar_para_despacho(Paquete *paquete) {
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
    *paquete = extraer(origen);
    if (elegir_prioridad) {
        if (prioritarios_consecutivos < 3) prioritarios_consecutivos++;
    } else {
        prioritarios_consecutivos = 0;
    }
    avisar(&mutex_finales);
    avisar(elegir_prioridad ? &espacios_prioridad : &espacios_normal);
    return 1;
}

void *despachador(void *argumento) {
    Trabajador *trabajador = argumento;
    Paquete paquete;
    while (retirar_para_despacho(&paquete)) {
        demorar(0, 2);
        esperar(&mutex_despachados);
        despachados++;
        printf("Despachador %d despachó paquete %d - peso %d - prioridad %s - costo %d\n",
               trabajador->id, paquete.id, paquete.peso,
               paquete.prioridad ? "ALTA" : "NORMAL", paquete.costo);
        avisar(&mutex_despachados);
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
    iniciar_semaforo(&espacios_prioridad, CAPACIDAD_PRIORIDAD);
    iniciar_semaforo(&espacios_normal, CAPACIDAD_NORMAL);
    iniciar_semaforo(&disponibles_finales, 0);
    iniciar_semaforo(&mutex_finales, 1);
    iniciar_semaforo(&mutex_recepcion, 1);
    iniciar_semaforo(&mutex_despachados, 1);

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
    return 0;
}
