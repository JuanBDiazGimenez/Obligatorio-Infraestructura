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
Los inicializa una vez al comenzar. Antes de jugar llama a `Elegir_Duracion`;
después de la demora llama a `Elegir_Ganador`. El sorteo 1 significa la pareja A
del partido y el 2 la pareja B, no necesariamente las parejas globales 1 y 2.

Los generadores no se comparten entre canchas. Por eso no hace falta agregar un
semáforo ni una cita para protegerlos. El Coordinador sigue usando únicamente
tasks y rendezvous para asignar partidos y recibir resultados. El paquete no
decide qué cancha recibe cada partido ni sincroniza la ejecución.

## Si en la defensa piden eliminar el azar

**No hay que rehacer el torneo.** La política de elección está separada de su
coordinación mediante dos funciones pequeñas:

- Para que los partidos duren siempre dos segundos, `Elegir_Duracion` devolvería
  siempre 2, en lugar de pedir un valor a `Random`.
- Para que gane siempre la primera pareja, `Elegir_Ganador` devolvería siempre
  `Encuentro.Pareja_A`.
- Para aplicar otra regla, por ejemplo favorecer a la pareja de menor número,
  se cambiaría solamente la elección del ganador.

Las tasks, las citas, las asignaciones y el cierre no cambian. Si se retirara
completamente el paquete, también habría que quitar los generadores, sus Reset,
las instancias y los parámetros que ya no se usan. Esa es una limpieza localizada,
no una reescritura de la sincronización. Devolver valores fijos sería una variante
para la pregunta de defensa, no la entrega actual que pide aleatoriedad.

Con un generador propio también se podría separar la elección en estas funciones.
Cambiarlo por una regla fija sería igual de localizado; habría más código del
generador propio que explicar y eventualmente retirar. La facilidad para cambiar
depende de separar responsabilidades, no de que el generador sea propio o estándar.

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

La elección de este paquete y de las dos funciones es una decisión de esta
implementación, no una solución atribuida al docente. Esta explicación se preparó
con asistencia de Codex (GPT-6 según el contexto de la sesión); el equipo debe
revisarla y poder explicar el uso concreto.
