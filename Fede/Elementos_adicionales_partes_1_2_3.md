# Elementos adicionales de las partes 1b, 2 y 3

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

## Herramientas internas

Los `verificar.py`, las pruebas dirigidas y los sanitizadores son auxiliares para comprobar resultados; no forman parte de la lógica exigida. No se atribuyen como herramientas enseñadas. Las variantes rápidas o con valores fijos se generan en copias temporales. En Parte 2 se acordó expresamente excluir `verificar.py` y `pruebas_prioridad.c` del paquete final, conservándolos para uso interno.

**Referencias de la revisión:** original de Parte 1a; presentaciones de Sistema de archivos, Semáforos y Ada; laboratorios y apuntes/transcripciones consultados. Para el concepto de registro: Semáforos, diapositivas 16 y 22; para el paquete adicional: letra, páginas 9–11 y rúbrica 14, y manual de Ada A.5.2 citado en las explicaciones existentes.

Preparado con asistencia de Codex (GPT-6 según contexto de sesión). Este resumen no sustituye la revisión y comprensión del equipo ni acredita autorizaciones que no se hayan dado.
