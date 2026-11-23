# Observaciones para revisar

## Parte 2, ambas versiones: sintaxis de estructuras de datos

**Pendiente:** revisar la sintaxis utilizada para declarar y manejar las estructuras de datos de ambas versiones, especialmente `struct`, `typedef`, arreglos y acceso a sus campos mediante variables o punteros. Contrastar con el material de clase y los laboratorios para distinguir la sintaxis efectivamente trabajada de adaptaciones o construcciones adicionales.

La revisión se centra en cómo están escritas y utilizadas las estructuras, no solamente en si el programa funciona. Evaluar alternativas equivalentes más cercanas al curso cuando corresponda y registrar qué conviene conservar y explicar. Esta anotación no da por realizada la revisión ni autoriza cambios de código por sí sola.

## Guías de prueba: sintaxis de los comandos

**Pendiente:** revisar los comandos y sus opciones en los instructivos de pruebas de las distintas partes y ajustarlos, cuando haya una alternativa equivalente, a la forma utilizada en clase o en los laboratorios. La intención es facilitar su comprensión y mantener uniformidad con el curso, sin cambiar lo que se comprueba.

Contrastar cada caso con el material antes de sustituirlo. Si una opción adicional cumple una necesidad concreta, explicarla brevemente en vez de reemplazarla sin evaluar su efecto. Esta anotación no da por realizada la revisión ni modifica comandos o PDFs.

## Parte 3, ambas versiones: orden de los datos en las trazas

Fede señaló que puede resultar confuso alternar el orden de partido y cancha entre mensajes como:

```text
Coordinador: Partido 2 asignado a Cancha 3. Pareja 3 vs Pareja 4.
Cancha 1 disputa Partido 1 durante 4 segundos.
Cancha 3 disputa Partido 2 durante 4 segundos.
```

Son eventos distintos y no se identificó un error funcional: el coordinador informa la asignación y cada cancha informa el comienzo de su partido. Sin embargo, pasar de «Partido → Cancha» a «Cancha → Partido» puede dificultar seguir la salida intercalada.

**Pendiente opcional:** evaluar si conviene mantener un orden más uniforme de los identificadores, conservando la distinción entre asignación e inicio. No se decidió un formato ni se modificaron mensajes o código.
