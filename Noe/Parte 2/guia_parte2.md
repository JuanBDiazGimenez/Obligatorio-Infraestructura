# Parte 2 (C) – Centro de distribución Springfield: guía para entender y explicar el código

Archivo: `springfield.c` (hilos POSIX + semáforos POSIX).

```bash
gcc -Wall -pthread springfield.c -o springfield
./springfield              # ~2 minutos a tiempo real
gcc -DESCALA=20 -pthread springfield.c -o springfield_rapido   # opcional: todos los tiempos / 20, para probar
```

## 0. Qué se hizo y cómo (proceso)

1. Se identificó la estructura: **4 etapas en cadena** conectadas por **4 buffers**. Cada buffer es un problema clásico de *productor-consumidor con buffer acotado*.
2. Se hizo **una sola estructura `Cola`** (circular, FIFO) y se reutilizó para Zona 1, Zona 2, cola prioridad y cola normal. Solo cambia la capacidad (15, 15, 10, 15).
3. Se pensó cómo garantizar los 300 paquetes exactos y cómo terminan los hilos (contador `reclamar`).
4. Se pensó la regla de los despachadores (máximo 3 prioritarios seguidos).
5. Se compiló sin warnings (`-Wall -Wextra`) y se probó: 3 corridas rápidas + 20 corridas de estrés (tiempos casi nulos, mucha competencia entre hilos) + 1 corrida a tiempo real. Un script verificó en cada salida: 300 paquetes sin repetidos ni perdidos, que todo despachado pasó por las 3 etapas, FIFO en cada cola, capacidades 10/15, prioridad = peso > 10, costo = peso × 100 y la regla de los 3 consecutivos.

## 1. Mapa del sistema
```
4 Receptores → [Zona 1 (15)] → 4 Escáneres → [Zona 2 (15)] → 4 Clasificadores ─┬→ [cola PRIORIDAD (10)] ─┐
                                                                                └→ [cola NORMAL (15)]     ├→ 3 Despachadores
                                                                                                          ┘
```
Son 15 hilos en total (`pthread_create`). El `main` los crea y espera a que todos terminen (`pthread_join`).

## 2. Qué hay que saber (conceptos)
| Concepto | Qué significa |
|---|---|
| **Hilo (`pthread`)** | Un flujo de ejecución dentro del mismo proceso. Comparten memoria global, por eso hay que sincronizar. |
| **Semáforo (`sem_t`)** | Un contador entero con dos operaciones atómicas. `sem_wait` espera hasta que el valor sea > 0 y lo decrementa. `sem_post` lo incrementa y despierta a alguien que espera. |
| **Semáforo binario como mutex** | Iniciado en 1: solo un hilo puede estar entre `sem_wait` y `sem_post` (exclusión mutua). |
| **Semáforo contador** | Iniciado en N: cuenta recursos (lugares libres o paquetes disponibles). |
| **Productor-consumidor acotado** | 3 semáforos por buffer: `espacio` (inicia en la capacidad), `items` (inicia en 0) y `mutex` (inicia en 1). |
| **`sem_init(&s, 0, valor)`** | El `0` significa que el semáforo es compartido entre hilos del mismo proceso (no entre procesos). |
| **`rand_r(&semilla)`** | Aleatorio seguro entre hilos: cada hilo tiene su propia semilla (`rand()` comparte estado global). |
| **`nanosleep`** | Pausa de tiempo preciso (simula el tiempo de trabajo de cada etapa). |

### El patrón que se repite en cada buffer
```c
// Productor                          // Consumidor
sem_wait(&c->espacio);                sem_wait(&c->items);
sem_wait(&c->mutex);                  sem_wait(&c->mutex);
encolar(c, p);                        p = desencolar(c);
sem_post(&c->mutex);                  sem_post(&c->mutex);
sem_post(&c->items);                  sem_post(&c->espacio);
```

- Si el buffer está lleno, el productor se bloquea en `espacio`. Eso garantiza que **nunca haya más paquetes que la capacidad**.
- Si está vacío, el consumidor se bloquea en `items`. No se consume nada que no exista.
- El `mutex` protege los índices de la cola mientras uno modifica. El orden importa: primero el semáforo contador y **después** el mutex (si fuera al revés, un hilo podría dormir con el mutex tomado y trabar a todos: deadlock).

## 3. El código por bloques

### 3.1 Estructuras y variables globales (líneas 17-36)
| Líneas | Qué hace |
|---|---|
| 17-22 | `Paquete`: id, peso, prioridad y costo (estos dos se completan al escanear). |
| 26-30 | `Cola`: arreglo circular + `cabeza` (siguiente a sacar), `cuenta` (cuántos hay), `cap` (capacidad) y sus 3 semáforos. |
| 32 | Las 4 colas: `zona1`, `zona2`, `cola_prio`, `cola_norm`. |
| 33 | `disponibles`: cuántos paquetes hay en total entre las dos colas finales. Los despachadores esperan en este semáforo. |
| 34-35 | Contadores de trabajo por etapa, protegidos por el semáforo `m_cont`. |
| 36 | `consecutivos_prio`: cuántos prioritarios seguidos se despacharon. |

### 3.2 Funciones auxiliares (líneas 38-71)
| Función | Qué hace |
|---|---|
| `cola_init` (38-44) | Deja la cola vacía e inicializa los 3 semáforos: `espacio = cap`, `items = 0`, `mutex = 1`. |
| `encolar` (47-50) | Guarda en la posición `(cabeza + cuenta) % cap` (el fin de la cola circular). El `%` hace que dé la vuelta. |
| `desencolar` (52-57) | Saca de `cabeza` y avanza `cabeza` circularmente. Esto garantiza **FIFO**. |
| `reclamar` (60-65) | Bajo exclusión mutua, devuelve el número 1, 2, 3… hasta 300, y después 0. Es **cuántos paquetes puede procesar una etapa**: asegura exactamente 300 y que cada hilo sepa cuándo terminar. |
| `espera_ms` (67-71) | Duerme un tiempo aleatorio entre `min` y `max` ms. |

### 3.3 Receptor (líneas 73-88)

1. `reclamar(&c_generados)` entrega el **id** (1, 2, 3…): es único y autoincremental porque lo asigna una sección crítica. Cuando devuelve 0 ya se generaron los 300 y el hilo termina.
2. Duerme 1-2 s (`espera_ms(1000, 2000)`) y crea el paquete con peso `1 + rand_r() % 20` (1 a 20).
3. Patrón productor sobre `zona1`; imprime *dentro* de la sección crítica para que el orden impreso sea el orden real de la cola.

### 3.4 Escáner (líneas 90-112)

1. `reclamar(&c_escaneados)`: cuota de trabajos de la etapa.
2. Consume de `zona1` (patrón consumidor) y **libera el lugar** (`sem_post espacio`) antes de procesar, para no frenar a los receptores.
3. Duerme hasta 3 s, define `prioridad = peso > 10` y `costo = peso * 100`.
4. Produce en `zona2` e imprime "Escáner X procesó paquete Y".

### 3.5 Clasificador (líneas 114-135)

1. Consume de `zona2`, duerme hasta 2 s.
2. Elige destino: `p.prioridad ? &cola_prio : &cola_norm`. Como las dos son `Cola`, el mismo código sirve para ambas (`destino->...`).
3. Produce en el destino (si está llena, **se bloquea ahí** hasta que haya lugar) e imprime la cola.
4. `sem_post(&disponibles)`: avisa a los despachadores que hay un paquete más.

### 3.6 Despachador (líneas 137-163) – la parte más delicada
| Líneas | Qué hace |
|---|---|
| 140 | `reclamar`: exactamente 300 despachos entre los 3. |
| 141 | `sem_wait(&disponibles)`: espera hasta que haya algún paquete en cualquiera de las dos colas, y **lo reserva** para este despachador. Así nunca se queda esperando en una cola vacía mientras la otra tiene paquetes. |
| 142 | Simula lo que tarda en despachar (hasta 2 s). |
| 145-146 | Toma el mutex de las **dos** colas, siempre en el mismo orden (prio, norm) para evitar deadlock. Así decide viendo las dos colas a la vez, sin que nadie las cambie. |
| 148-154 | **Regla de prioridad**: se elige prioridad si hay alguno y *no* ocurre que ya se despacharon 3 seguidos con un normal esperando. En cualquier otro caso, normal (y el contador vuelve a 0). |
| 155-157 | Saca el paquete y lo imprime en el mismo momento. |
| 158-160 | Libera los mutex y devuelve el lugar a la cola de origen. |

**Por qué `espera` va antes de decidir:** así el momento en que se imprime "despachó" es el mismo en que el paquete sale de la cola. Si el despachador sacara el paquete, durmiera y recién imprimiera, con 3 despachadores las líneas impresas podrían salir en distinto orden que las decisiones, y parecería que se rompe la regla de los 3 consecutivos.

**¿Siempre hay un paquete cuando decide?** Sí: cada `sem_wait(&disponibles)` exitoso corresponde a un paquete en alguna cola reservado para ese despachador. Si la cola prioridad está vacía, necesariamente el paquete está en la normal.

### 3.7 `main` (líneas 165-192)

- Inicializa las colas y semáforos.
- Crea los 15 hilos con un bucle: `rutinas[]` es un arreglo de punteros a las 4 funciones de hilo y `cantidad[]` cuántos hay de cada tipo. Cada hilo recibe su número (`ids[n]`) como argumento.
- `pthread_join` de todos: el programa termina **solo cuando los 300 fueron despachados**, porque los despachadores son los últimos en terminar.

## 4. Cómo se cumple cada garantía de la letra
| Garantía | Cómo |
|---|---|
| No más paquetes que la capacidad | Semáforo `espacio` inicializado en la capacidad. |
| No se pierde ningún paquete | Solo se saca con `items`/`disponibles` y solo se agrega con `espacio`: todo lo que entra, sale. |
| Ninguno se procesa dos veces en la misma etapa | Se saca de la cola dentro del mutex; un paquete sale una sola vez. |
| Sin saltear etapas | Cada paquete solo avanza por las colas, en orden. |
| FIFO | Cola circular: se agrega al fin, se saca del inicio, dentro del mutex. |
| Termina con 300 despachados | Contadores `reclamar` + `pthread_join`. |
| Normales no postergados | Regla de las líneas 148-154. |

## 5. Preguntas probables de defensa

1. ¿Qué pasa si invertís `sem_wait(&espacio)` y `sem_wait(&mutex)`? → Un productor con el mutex tomado y buffer lleno duerme esperando `espacio`; el consumidor necesita el mutex para liberar espacio: **deadlock**.
2. ¿Para qué sirve cada semáforo de `Cola`? → `espacio` cuenta lugares libres, `items` cuenta paquetes, `mutex` da exclusión mutua.
3. ¿Qué diferencia hay entre semáforo binario y contador? → Binario (0/1) exclusión mutua; contador (0..N) cuenta recursos.
4. ¿Por qué el id sale de `reclamar` y no de una variable global `++`? → Porque `++` entre varios hilos no es atómico; `reclamar` lo hace bajo mutex.
5. ¿Cómo garantizás exactamente 300? → Cada etapa reclama un número del 1 al 300 antes de trabajar; el 301 recibe 0 y el hilo termina.
6. ¿Cómo evitás que los normales queden postergados? → `consecutivos_prio >= 3 && cola_norm.cuenta > 0` fuerza un normal.
7. ¿Por qué `disponibles` y no un semáforo por cola? → El despachador debe esperar "cualquiera de las dos"; con un semáforo por cola no puede esperar en ambas a la vez.
8. ¿Qué pasa si un clasificador tiene un paquete prioritario y la cola prioridad está llena? → Se bloquea en `espacio` hasta que un despachador saque uno; no hay deadlock porque los despachadores no dependen del clasificador bloqueado.
9. ¿Para qué `rand_r`? → Seguro para hilos con semilla propia.
10. ¿Qué hace `pthread_join`? → Espera a que termine un hilo.

## 6. Limitaciones / decisiones

- Los hilos no tienen exclusión sobre `printf`; se imprime dentro de las secciones críticas para mantener el orden real (glibc además hace atómico cada `printf`).
- No hay manejo de errores de `sem_*` / `pthread_*` (alcance del obligatorio).
- Los mensajes llevan tildes (UTF-8): hay que usar un terminal UTF-8.

## 7. Declaración de uso de IA

- **Herramienta:** Claude Code (Claude Sonnet 5.5, Anthropic).
- **Contexto de uso:** diseño y redacción inicial del código y de esta guía, y pruebas automáticas de la salida.
- **Verificación propia:** [completar: qué compiló, ejecutó, revisó y modificó cada integrante].
- Somos responsables de cualquier error del contenido generado.
