/* Prueba de la coordinación compartida, sin crear hilos ni esperar segundos. */
#define main main_simulacion
#include "main.c"
#undef main
#include <assert.h>

static void agregar_prueba(int id, int alta) {
    sem_t *espacios = alta ? &espacios_prioridad : &espacios_normal;
    sem_wait(espacios);
    sem_wait(&mutex_finales);
    insertar(alta ? &prioridad : &normal, (Paquete){.id = id, .prioridad = alta});
    sem_post(&disponibles_finales);
    sem_post(&mutex_finales);
}

static void esperar_id(int id) {
    Paquete paquete;
    assert(retirar_para_despacho(&paquete, 1));
    assert(paquete.id == id);
}

int main(void) {
    iniciar_cola(&prioridad, 10, "PRIORIDAD");
    iniciar_cola(&normal, 15, "NORMAL");
    sem_init(&espacios_prioridad, 0, 10);
    sem_init(&espacios_normal, 0, 15);
    sem_init(&disponibles_finales, 0, 0);
    sem_init(&mutex_finales, 0, 1);

    for (int i = 1; i <= 10; i++) agregar_prueba(i, 1);
    for (int i = 101; i <= 115; i++) agregar_prueba(i, 0);
    const int orden[] = {1, 2, 3, 101, 4, 5, 6, 102, 7, 8, 9, 103, 10,
                         104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115};
    for (unsigned int i = 0; i < sizeof orden / sizeof orden[0]; i++) {
        esperar_id(orden[i]);
    }

    /* Sin normales se permite continuar; si luego llega uno, tiene turno. */
    for (int i = 201; i <= 204; i++) {
        agregar_prueba(i, 1);
        esperar_id(i);
    }
    agregar_prueba(205, 1);
    agregar_prueba(301, 0);
    esperar_id(301);
    esperar_id(205);

    finales_cerradas = 1;
    sem_post(&disponibles_finales);
    Paquete paquete;
    assert(!retirar_para_despacho(&paquete, 1));
    assert(prioridad.cantidad == 0 && normal.cantidad == 0);
    sem_destroy(&espacios_prioridad);
    sem_destroy(&espacios_normal);
    sem_destroy(&disponibles_finales);
    sem_destroy(&mutex_finales);
    puts("Prioridad: secuencia 3:1, FIFO, cola unica, llegada tardia y cierre correctos.");
    return 0;
}
