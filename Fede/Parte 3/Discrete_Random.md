# Discrete_Random y el azar del torneo

`Ada.Numerics.Discrete_Random` es un paquete de la biblioteca estándar de Ada
para generar valores **pseudoaleatorios discretos**, por ejemplo números enteros.
No es una biblioteca de terceros que tengamos que descargar por separado.

## Qué significa cada cosa

1. **Rango:** indica qué valores pueden salir. En el torneo usamos enteros entre
   **0 y 4** para la duración y entre **1 y 2** para elegir una de las dos parejas.
2. **Paquete genérico:** es una plantilla. Al instanciarla le indicamos el tipo y
   rango que necesitamos. Así obtenemos `Azar_Duracion` y `Azar_Ganador`.
3. **Generator:** es el objeto que conserva el estado de una secuencia. No es un
   número sorteado ni la semilla: guarda la información necesaria para obtener
   sucesivos valores.
4. **Reset:** inicializa ese estado. Sin semilla explícita usa una inicialización
   dependiente del tiempo. Con una semilla entera explícita se puede repetir la
   secuencia en la misma implementación, lo que sirve para pruebas.
5. **Random:** devuelve el siguiente valor del rango y avanza el estado del
   generador. Se llama cada vez que necesitamos otro sorteo; **no se hace Reset
   antes de cada llamada**.

Se dice pseudoaleatorio porque una secuencia depende de su estado inicial y de
un algoritmo. No es azar físico ni garantiza resultados diferentes en cada
llamada: dos partidos pueden durar lo mismo y puede ganar varias veces la primera
pareja. Tampoco se garantiza que dos Reset muy próximos den secuencias distintas.

## Cómo se usa en este programa

Cada cancha tiene dos generadores propios: uno para duración y otro para ganador.
Los inicializa una vez al comenzar con `Reset`. Dentro del cuerpo de la cancha:

- Antes de jugar, `Azar_Duracion.Random (Generador_Duracion)` obtiene los segundos
  y los guarda en `Duracion`. Luego `delay Duration (Duracion)` simula el partido.
- Después de la demora, `Azar_Ganador.Random (Generador_Ganador)` obtiene 1 o 2.
  Un `if` selecciona `Partidos (Numero).Pareja_A` si sale 1, o
  `Partidos (Numero).Pareja_B` si sale 2, y guarda esa pareja en `Ganador`.

El sorteo 1 significa la pareja A del partido y el 2 la pareja B, no necesariamente
las parejas globales 1 y 2. Los sorteos se realizan directamente en la cancha.

Los generadores no se comparten entre canchas. Por eso no hace falta agregar un
semáforo ni una cita para protegerlos. El Coordinador sigue usando únicamente
tasks y rendezvous para asignar partidos y recibir resultados. El paquete no
decide qué cancha recibe cada partido ni sincroniza la ejecución.

## Justificación y fuentes

- La letra, `Infraestructura Obligatorio Agosto 2026 (1).pdf`, páginas 9–10,
  pide duración y ganador aleatorios. La rúbrica de la página 14 **no prohíbe**
  bibliotecas no dadas en clase: exige demostrar total solvencia en su utilización.
- `Material de clase/8. ADA (1) (1).pdf`, diapositivas 11 y 14, muestra el uso de
  `Ada.Text_IO` y `Ada.Integer_Text_IO`; la 18 explica paquetes. Esto respalda
  el uso de paquetes, pero **no demuestra que Discrete_Random se enseñara**.
- [Manual de referencia de Ada, A.5.2](https://www.adaic.org/resources/add_content/standards/12rm/html/RM-A-5-2.html):
  fuente externa para `Discrete_Random`, `Generator`, `Reset` y `Random`, y para la
  necesidad de sincronizar un generador si se compartiera entre tareas.

La elección de este paquete y de los dos rangos es una decisión de esta
implementación, no una solución atribuida al docente. Esta explicación se preparó
con asistencia de Codex (GPT-6 según el contexto de la sesión); el equipo debe
revisarla y poder explicar el uso concreto.
