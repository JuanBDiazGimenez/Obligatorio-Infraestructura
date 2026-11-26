#include <semaphore.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>

int totalPaquetes = 300;
int generados = 0;
int escaneados = 0;
int clasificados = 0;
int despachados = 0;
sem_t mutexGenerados;
sem_t mutexEscaneados;
sem_t mutexClasificados;
sem_t mutexDespachados;
sem_t hayPaquete;
sem_t mutexDespacho;
int consecutivosPrio = 0;

typedef struct Paquete paquete;
struct Paquete
{
    int id;
    int peso;
    int prioridad;
    int costo;
};

typedef struct Buffer buffer;
struct Buffer
{
    paquete datos[15];
    int capacidad;
    int in;
    int out;
    sem_t espaciosVacios;
    sem_t espaciosLlenos;
    sem_t mutex;
};
buffer zona1;
buffer zona2;
buffer colaPrio;
buffer colaNorm;

void inicializarBuffer(buffer *b, int cap)
{
    b->capacidad = cap;
    b->in = 0;
    b->out = 0;
    sem_init(&b->espaciosLlenos, 0, 0);
    sem_init(&b->espaciosVacios, 0, cap);
    sem_init(&b->mutex, 0, 1);
}

void insertar(buffer *b, paquete p)
{
    sem_wait(&b->espaciosVacios);
    sem_wait(&b->mutex);

    b->datos[b->in] = p;
    b->in++;
    if (b->in == b->capacidad)
        b->in = 0;

    sem_post(&b->mutex);
    sem_post(&b->espaciosLlenos);
}

paquete extraer(buffer *b)
{
    sem_wait(&b->espaciosLlenos);
    sem_wait(&b->mutex);

    paquete p = b->datos[b->out];
    b->out++;
    if (b->out == b->capacidad)
        b->out = 0;

    sem_post(&b->mutex);
    sem_post(&b->espaciosVacios);
    return p;
}

void *receptor(void *arg)
{
    int num = *(int *)arg;
    while (1)
    {
        sem_wait(&mutexGenerados);
        if (generados == totalPaquetes)
        {
            sem_post(&mutexGenerados);
            break;
        }
        generados++;
        int id = generados;
        sem_post(&mutexGenerados);
        sleep(rand() % 2 + 1);
        paquete p;
        p.id = id;
        p.peso = rand() % 20 + 1;
        p.prioridad = 0;
        p.costo = 0;
        printf("Receptor %d genero paquete %d con peso %d\n", num, p.id, p.peso);
        insertar(&zona1, p);
    }
    return NULL;
}

void *escaner(void *arg)
{
    int num = *(int *)arg;
    while (1)
    {
        sem_wait(&mutexEscaneados);
        if (escaneados == totalPaquetes)
        {
            sem_post(&mutexEscaneados);
            break;
        }
        escaneados++;
        sem_post(&mutexEscaneados);
        paquete p = extraer(&zona1);
        sleep(rand() % 4);
        p.prioridad = (p.peso > 10) ? 1 : 0;
        p.costo = p.peso * 100;
        printf("Escaner %d proceso paquete %d\n", num, p.id);
        insertar(&zona2, p);
    }
    return NULL;
}

void *clasificador(void *arg)
{
    int num = *(int *)arg;
    while (1)
    {
        sem_wait(&mutexClasificados);
        if (clasificados == totalPaquetes)
        {
            sem_post(&mutexClasificados);
            break;
        }
        clasificados++;
        sem_post(&mutexClasificados);
        paquete p = extraer(&zona2);
        sleep(rand() % 3);
        if (p.prioridad == 1)
        {
            printf("Clasificador %d envio paquete %d a cola PRIORIDAD\n", num, p.id);
            insertar(&colaPrio, p);
        }
        else
        {
            printf("Clasificador %d envio paquete %d a cola NORMAL\n", num, p.id);
            insertar(&colaNorm, p);
        }
        sem_post(&hayPaquete); // avisa a los despachadores que hay un paquete en alguna cola
    }
    return NULL;
}

void *despachador(void *arg)
{
    int num = *(int *)arg;
    while (1)
    {
        sem_wait(&mutexDespachados);
        if (despachados == totalPaquetes)
        {
            sem_post(&mutexDespachados);
            break;
        }
        despachados++;
        sem_post(&mutexDespachados);
        sem_wait(&hayPaquete);
        sem_wait(&mutexDespacho);
        int cantPrio, cantNorm;
        sem_getvalue(&colaPrio.espaciosLlenos, &cantPrio);
        sem_getvalue(&colaNorm.espaciosLlenos, &cantNorm);

        paquete p;
        if (cantNorm > 0 && (consecutivosPrio >= 3 || cantPrio == 0))
        {
            p = extraer(&colaNorm);
            consecutivosPrio = 0;
        }
        else
        {
            p = extraer(&colaPrio);
            consecutivosPrio++;
        }

        sem_post(&mutexDespacho);

        sleep(rand() % 3);
        printf("Despachador %d despacho paquete %d - peso %d - prioridad %s - costo %d\n",
               num, p.id, p.peso, p.prioridad == 1 ? "ALTA" : "NORMAL", p.costo);
    }
    return NULL;
}

int main()
{

    sem_init(&mutexGenerados, 0, 1);
    sem_init(&mutexEscaneados, 0, 1);
    sem_init(&mutexClasificados, 0, 1);
    sem_init(&mutexDespachados, 0, 1);
    sem_init(&mutexDespacho, 0, 1);
    sem_init(&hayPaquete, 0, 0);

    inicializarBuffer(&zona1, 15);
    inicializarBuffer(&zona2, 15);
    inicializarBuffer(&colaPrio, 10);
    inicializarBuffer(&colaNorm, 15);

    pthread_t hilosReceptores[4];
    pthread_t hilosEscaneres[4];
    pthread_t hilosClasificadores[4];
    pthread_t hilosDespachadores[3];

    int ids[4];
    for (int i = 0; i < 4; i++)
    {
        ids[i] = i + 1;
    }

    for (int i = 0; i < 4; i++)
    {
        pthread_create(&hilosReceptores[i], NULL, receptor, &ids[i]);
        pthread_create(&hilosEscaneres[i], NULL, escaner, &ids[i]);
        pthread_create(&hilosClasificadores[i], NULL, clasificador, &ids[i]);
    }
    for (int i = 0; i < 3; i++)
    {
        pthread_create(&hilosDespachadores[i], NULL, despachador, &ids[i]);
    }

    for (int i = 0; i < 4; i++)
    {
        pthread_join(hilosReceptores[i], NULL);
        pthread_join(hilosEscaneres[i], NULL);
        pthread_join(hilosClasificadores[i], NULL);
    }
    for (int i = 0; i < 3; i++)
    {
        pthread_join(hilosDespachadores[i], NULL);
    }

    printf("Se despacharon los %d paquetes\n", totalPaquetes);
    return 0;
}