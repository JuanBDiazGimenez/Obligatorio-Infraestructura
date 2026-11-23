# Elementos adicionales de las partes 1b, 2, 3 y 4

Resumen del código actual, al 22/11/2026. Se consideran respaldo tanto las clases como el original provisto. No encontrar un ejemplo específico no significa que algo esté prohibido: distinguimos lo autorizado de las adaptaciones de conceptos conocidos. No se incluyen elementos que ya retiramos.

## Parte 1b — Bash

| Elemento | Explicación breve |
| --- | --- |
| `local` | Mantiene separadas las variables auxiliares durante la llamada de una función. No se localizó enseñado en Bash; Fede autorizó conservarlo. |
| `[:space:]` | Reconoce espacios en blanco, incluidas tabulaciones. Se usa para rechazar entradas formadas únicamente por esos caracteres. No se localizó esa clase concreta; Fede autorizó conservarla. |
| Estados de funciones, `if !` y `while true` | Las búsquedas devuelven éxito o fracaso, `!` invierte una condición y los bucles repiten hasta retornar o salir. No se localizaron ejemplos idénticos en Bash; se conservaron por acuerdo como adaptaciones básicas de funciones y control de flujo. |

## Parte 2 — C, ambas versiones

| Elemento | Explicación breve |
| --- | --- |
| `rand()`, `srand()` y `time(NULL)` | `rand()` obtiene un número pseudoaleatorio; el resto de la expresión lo acota al intervalo requerido. `srand(time(NULL))` inicializa una vez la secuencia usando la hora. Se trabajó el azar, pero no se localizó esa receta concreta; se eligió `rand()` con autorización de Fede. |
| Estructuras C con `typedef struct` | Agrupan los campos de paquetes, colas, zonas y trabajadores bajo nombres propios. El concepto de registro aparece en el pseudocódigo del curso, pero no se localizó la declaración equivalente escrita en C. Es una adaptación de representación de datos; no se presenta como una nueva excepción expresamente aprobada en la conversación. |

## Parte 3 — Ada, ambas versiones

| Elemento | Explicación breve |
| --- | --- |
| `Ada.Numerics.Discrete_Random` | Paquete estándar que permite obtener enteros pseudoaleatorios. Se usa porque la letra pide duración y ganador aleatorios. Su uso fue conversado y autorizado; cada carpeta tiene una explicación específica en `Discrete_Random.md`. |
| Instancias del paquete y generadores | `package ... is new` adapta el paquete a `Integer`. Cada cancha tiene sus generadores, los inicializa una vez con `Reset` y obtiene valores con `Random`. Son parte del uso adicional del paquete, no ejemplos atribuidos al docente. |
| `mod` para acotar sorteos | `mod 5` produce 0–4 y `mod 2 + 1` produce 1–2. Es la operación de resto conocida del curso, expresada en Ada; esta aplicación al generador es una adaptación propia, no una receta docente del torneo. |
| `exit when Numero = 0` | Sale del bucle de la cancha cuando no quedan partidos. No se localizó el ejemplo específico en Ada; se conservó por acuerdo como control básico equivalente a una salida condicionada del bucle. |

En v2, `Elegir_Duracion` y `Elegir_Ganador` separan la elección en funciones pequeñas. Esa organización se discutió al conservar las dos versiones; no es una exigencia de la letra. Los arreglos, las asignaciones, los bucles y `Ejecutar_Torneo` combinan mecanismos respaldados y no necesitan tratarse como bibliotecas adicionales.

## Parte 4 — Ada, Redis y Docker

Este ejercicio tiene un alcance particular: la letra, página 12, deja investigar y seleccionar la comunicación y la infraestructura. No hay una única implementación esperada. Redis y Docker sí se trabajaron en el laboratorio de Voting; lo adicional es integrar Redis con programas Ada independientes y adaptar el intercambio de mensajes al atracadero. No corresponde presentar todo Redis como ajeno al curso ni exigir una alternativa docente idéntica para cada comando de la solución elegida.

Las decisiones siguientes se conversaron y se acordó conservarlas con Fede. Esto no equivale a aprobación del profesor: las consultas pertinentes están en [consultas para hacer.md](consultas%20para%20hacer.md).

| Elemento o decisión | Explicación breve |
| --- | --- |
| Redis como intermediario y acceso desde Ada | `RPUSH` y `LPOP` transportan solicitudes, liberaciones y permisos individuales. La extracción de listas tiene antecedente en el Worker del laboratorio; la adaptación a estos mensajes es propia. `GNAT.Expect.Get_Command_Output` ejecuta `redis-cli` y captura la respuesta sin archivos de intercambio; `GNAT.OS_Lib` aporta los argumentos y su liberación. Son paquetes incluidos con GNAT, no de la biblioteca estándar de Ada. |
| Argumentos, memoria y estado del comando | `Argument_List` requiere accesos a cadenas, construidos con `new` y liberados con `Free`. `aliased` permite pasar `Estado'Access` para recibir el código de salida. Es parte de la interfaz elegida, explicada en [GNAT_Expect_y_OS_Lib.md](Parte%204/GNAT_Expect_y_OS_Lib.md). Se conserva `Error_Comunicacion` si falla el comando; se retiraron los diagnósticos adicionales y el manejador general de excepciones. |
| Preparación y lectura de las respuestas | `DEL`, `SET`, `GET` y `puerto:listo` coordinan la preparación antes de iniciar los barcos; no representan el permiso del atracadero. La limpieza de CR/LF en `Recibir` adapta el texto capturado de `redis-cli` y permite distinguir una consulta sin mensaje. Son consecuencias concretas del mecanismo elegido; detalle en [Arranque_Redis.md](Parte%204/Arranque_Redis.md) y [Notas_internas_cadenas.md](Parte%204/Notas_internas_cadenas.md). |
| `Ada.Command_Line` | Cada barco es un proceso independiente que recibe su identificador al arrancar. Usar el mismo ejecutable evita tres fuentes casi idénticas; no los convierte en tasks de un solo programa. Se mantiene, con consulta docente pendiente sobre esa organización. |
| Construcciones y funciones de Ada | Se conservan subtipos, rangos, bloques `declare`, cortes y atributos de cadenas, e `Index` y `Trim` de la biblioteca estándar. Son herramientas para representar los datos y manejar mensajes; no se plantea una justificación separada para cada detalle básico. Se explican para uso interno en [Construcciones_Ada.md](Parte%204/Construcciones_Ada.md) y la nota de cadenas. `Discrete_Random`, ya acordado para la parte 3, también se usa para los tiempos de los barcos. |
| Compilación con `-gnatwU` | Permite guardar respuestas sin leerlas, sin condiciones artificiales. Desactiva la categoría de avisos de elementos no utilizados; los demás avisos siguen activos y se tratan como errores. No desactiva controles durante la ejecución. Fue acordado y probado; explicación y alcance en [Resultados_no_utilizados.md](Parte%204/Resultados_no_utilizados.md), con consulta docente anotada. |

La estructura del Dockerfile y de `docker-compose.yml` tiene respaldo en el material: el laboratorio incluye construcción en dos etapas, `COPY --from`, chequeos de salud y dependencias `service_healthy`. Instalar GNAT, compilar Ada y comprobar nuestra marca de preparación adapta esa estructura a la solución. No se consideran mecanismos nuevos por el solo hecho de que el ejemplo del laboratorio use otros lenguajes.

Este resumen conserva las decisiones vigentes. Los detalles están en las notas enlazadas; no pretende convertir cada una en una sección obligatoria de la entrega. La rúbrica de la página 14 contempla sentencias, bibliotecas, estructuras y soluciones no vistas, exigiendo solvencia y una solución simple y acorde al curso. La página 15 exige comprender toda la entrega.

## Herramientas internas

Los `verificar.py`, las pruebas dirigidas y los sanitizadores son auxiliares para comprobar resultados; no forman parte de la lógica exigida. No se atribuyen como herramientas enseñadas. Las variantes rápidas o con valores fijos se generan en copias temporales. En Parte 2 se acordó expresamente excluir `verificar.py` y `pruebas_prioridad.c` del paquete final, conservándolos para uso interno.

**Referencias de la revisión:** original de Parte 1a; presentaciones de Sistema de archivos, Semáforos y Ada; laboratorios y apuntes/transcripciones consultados. Para el concepto de registro: Semáforos, diapositivas 16 y 22; para el paquete adicional: letra, páginas 9–11 y rúbrica 14, y manual de Ada A.5.2 citado en las explicaciones existentes.

Preparado con asistencia de Codex (GPT-6 según contexto de sesión). Este resumen no sustituye la revisión y comprensión del equipo ni acredita autorizaciones que no se hayan dado.
