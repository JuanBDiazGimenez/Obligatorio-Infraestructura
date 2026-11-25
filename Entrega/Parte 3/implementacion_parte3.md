# Parte 3 — Implementación

## Organización del torneo

`torneo.adb` representa ocho partidos entre dieciséis parejas. Los arreglos `Parejas_A` y `Parejas_B` se completan antes de activar las tareas: el partido 1 enfrenta a las parejas 1 y 2; el 2, a las parejas 3 y 4, y así sucesivamente.

`Ejecutar_Torneo` contiene una task `Coordinador` y tres instancias del task type `Cancha`, identificadas del 1 al 3. El procedimiento agrupa su ejecución y permite que los datos estén preparados antes de que comiencen. Cada cancha disputa un solo partido a la vez, pero las tres pueden jugar simultáneamente.

## Solicitudes y resultados mediante citas

El Coordinador ofrece dos entradas: `Solicitar_Partido` e `Informar_Resultado`. Su `select` permite aceptar una solicitud o un resultado, atendiendo una cita por vez. Esto evita fijar una secuencia que obligue a esperar una solicitud cuando lo que llega es un resultado.

Por ejemplo, Cancha 1 llama a `Coordinador.Solicitar_Partido`. Queda esperando hasta que el Coordinador acepta y termina esa cita. Dentro del `accept`, el Coordinador devuelve el número de partido mediante el parámetro `out` e incrementa `Proximo`. Solo él modifica ese contador, de modo que un partido no puede asignarse a dos canchas.

Terminada la cita, Cancha 1 simula el partido con `delay`, mientras el Coordinador atiende a otras canchas. Al terminar, sortea el ganador y llama a `Informar_Resultado`. Espera a que esa cita finalice antes de solicitar otro partido. No se agregan semáforos: las citas coordinan el acceso al estado del Coordinador y cada cancha conserva sus propias variables.

## Duración y ganador

Se utiliza `Ada.Numerics.Discrete_Random`, de la biblioteca estándar. Hay dos instancias, `Azar_Duracion` y `Azar_Ganador`, para distinguir ambos sorteos. Cada cancha posee sus dos generadores y los inicializa una vez con `Reset`, sin una semilla explícita.

`Random (...) mod 5` obtiene una duración entre 0 y 4 segundos. Para el ganador, `mod 2 + 1` obtiene 1 o 2 y un `if` elige una de las dos parejas de ese partido. Los generadores no se comparten entre tasks. Las duraciones pueden coincidir y un partido posterior puede terminar antes que otro: son consecuencias compatibles con el trabajo concurrente.

Se eligió este paquete para resolver el azar sin diseñar un generador propio. No se presenta como una técnica enseñada en clase. `Discrete_Random.md` explica su funcionamiento y cita el manual de referencia de Ada, sección A.5.2.

Las instancias `package ... is new` adaptan ese paquete genérico al tipo `Integer`; `Generator`, `Reset` y `Random` forman parte de su utilización adicional. La acotación mediante `mod` adapta la operación de resto conocida del curso a los valores del torneo, sin atribuir al docente esta combinación concreta. Con divisor positivo, el resultado de `mod` en Ada es no negativo, incluso cuando el entero generado es negativo.

## Finalización

Cuando no quedan partidos por asignar, el Coordinador responde con `Numero = 0`. Esa cancha sale de su bucle y termina. El Coordinador continúa atendiendo citas hasta haber enviado esta respuesta a las tres canchas.

La salida se expresa con `exit when Numero = 0`: termina el bucle si se cumple la condición. No se localizó ese uso específico en Ada en el material revisado; se conservó como una construcción básica de control, equivalente a comprobar una condición y salir del bucle. No interrumpe a las otras canchas ni al Coordinador.

Asignar el octavo partido no termina el torneo: cada cancha debe informar su resultado antes de volver a pedir y recibir el cero. Cuando las tres recibieron el fin, todos los resultados ya fueron comunicados. Ada espera la terminación de las tareas de `Ejecutar_Torneo` antes de volver al programa principal, que imprime «Torneo terminado».

## Ejecución y base del enfoque

Con GNAT instalado:

```bash
gnatmake torneo.adb
./torneo
```

Los instructivos de esta carpeta detallan los entornos Ubuntu y Windows nativo. Al revisar una ejecución deben aparecer ocho asignaciones únicas, ocho resultados con un ganador perteneciente al partido y la terminación de las tres canchas. El orden de las canchas y las finalizaciones puede variar.

La letra, páginas 9–10 de `Infraestructura Obligatorio Agosto 2026 (1).pdf`, requiere las cuatro tasks, las citas y la finalización tras disputar los ocho partidos. `8. ADA (1) (1).pdf` (material de clase), diapositiva 22, explica la espera de la task que llama durante el rendezvous; las diapositivas 27 y 37 presentan `select` y `task type`. La asignación de partidos, las dos entradas y la respuesta cero son la adaptación de estos mecanismos al torneo.
