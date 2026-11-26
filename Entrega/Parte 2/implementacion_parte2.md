# Parte 2 — Implementación

## Recorrido de los paquetes

`main.c` crea 4 receptores, 4 escáneres, 4 clasificadores y 3 despachadores mediante `pthread_create`. Los receptores generan exactamente 300 paquetes. `mutex_recepcion` protege la asignación de sus identificadores para que sean únicos, del 1 al 300.

Cada paquete atraviesa Zona 1, escaneo, Zona 2, clasificación y una de las dos colas finales. Los receptores demoran entre 1 y 2 segundos; los escáneres, entre 0 y 3; clasificadores y despachadores, entre 0 y 2. `aleatorio` usa `rand()` para obtener pesos entre 1 y 20 y las demoras; `sleep` simula el trabajo. No se inicializa una semilla explícita: la secuencia pseudoaleatoria puede repetirse entre ejecuciones, aunque la concurrencia puede cambiar su distribución entre trabajadores.

El escáner calcula `costo = peso * 100` y marca prioridad alta si el peso supera 10. La prioridad no cambia el tratamiento en Zona 2: el clasificador la utiliza para elegir la cola final.

## Colas y semáforos

`Paquete` reúne identificador, peso, prioridad y costo. `Cola` usa un arreglo circular: `insertar` avanza `entrada` y `extraer` avanza `salida`. Se conserva FIFO según el orden efectivo de inserción en cada cola. Los identificadores no tienen por qué salir en orden numérico, ni los trabajos terminar en el orden en que comenzaron.

Zona 1 y Zona 2 tienen capacidad 15. En cada `Zona`, `espacios` cuenta lugares libres, `elementos` permite esperar datos y `mutex`, iniciado en 1, protege la cola. `depositar` reserva espacio antes de tomar el mutex; `retirar` espera un elemento antes de tomarlo. Así nadie queda esperando espacio o datos mientras retiene la exclusión de la cola.

Las colas finales tienen capacidades 10 para prioridad y 15 para normales. Sus semáforos de espacios son independientes; `disponibles_finales` permite esperar paquetes de cualquiera de ellas. `mutex_finales` protege ambas colas y la elección del siguiente despacho. `mutex_despachados` protege el contador de trabajos terminados.

## Prioridad compartida y salida

`retirar_para_despacho` elige prioridad si hay paquetes prioritarios y no hay normales esperando, o si el contador compartido todavía es menor que 3. Al seleccionar un normal, reinicia el contador. Si no hay normales, puede seguir seleccionando prioritarios; el contador queda limitado a 3 y obliga a elegir un normal cuando este esté esperando.

La selección, la extracción y el cambio del contador ocurren dentro del mismo `mutex_finales`. Por ejemplo, después de tres selecciones prioritarias, el siguiente despachador debe tomar un normal si lo hay, aunque sea otro de los tres hilos.

La regla se aplica al **inicio del despacho**, cuando se retira el paquete. El mensaje «inició despacho» se imprime dentro de esa sección crítica e incluye los normales esperando y el contador. Luego se libera el mutex y se realiza la demora en paralelo. Por eso las finalizaciones pueden aparecer en otro orden. Esta línea adicional permite observar la decisión sin hacer esperar a un despachador por la finalización de los demás.

## Finalización

`main` espera con `pthread_join` a todos los productores de una etapa antes de cerrar su salida: primero receptores, luego escáneres y finalmente clasificadores. `cerrar_zona` marca el cierre y despierta a sus consumidores. Estos siguen retirando paquetes y terminan solamente al encontrar la zona cerrada y vacía. Las colas finales usan el mismo criterio. Esas señales de cierre son avisos para despertar hilos, no paquetes adicionales.

Tras esperar a los despachadores, se destruyen los semáforos y se imprime el total generado y despachado.

## Ejecución y base del enfoque

Como decisiones adicionales, se utiliza `rand()` para obtener valores pseudoaleatorios y la expresión `minimo + rand() % (maximo - minimo + 1)` para acotarlos al intervalo solicitado. Se eligió esta función por su uso sencillo para los pesos y tiempos del ejercicio; no se atribuye al material una implementación docente de este auxiliar.

Las declaraciones `typedef struct` agrupan campos relacionados y les dan nombres como `Paquete`, `Cola`, `Zona` y `Trabajador`. Esto permite pasar un paquete completo entre etapas y reunir los datos de cada cola con sus semáforos. El concepto de registro aparece en el pseudocódigo de Semáforos, diapositivas 16 y 22, pero no se localizó esa declaración concreta en C en el material revisado. Es una adaptación de la representación de datos, no un mecanismo adicional de sincronización.

Desde la carpeta que contiene `main.c`, en Ubuntu con GCC y soporte POSIX:

```bash
gcc -Wall -Wextra -pthread main.c -o paquetes
./paquetes
```

El resultado esperado es 300 paquetes únicos que completan todas las etapas y un resumen de 300 generados y 300 despachados. La traza de inicio permite revisar la regla de prioridad; por sí solas, las finalizaciones no muestran el orden de selección.

La letra, páginas 7–8 de `Infraestructura Obligatorio Agosto 2026 (1).pdf`, fija etapas, capacidades y regla de prioridad. `6. Semaforos Version Marzo (1).pdf` (material de clase), diapositivas 9–10 y 24–25, presenta buffers FIFO, exclusión y procesos consumidores de un buffer y productores de otro. Las cuatro etapas, el cierre y el contador global son la adaptación de esos mecanismos a este ejercicio.
