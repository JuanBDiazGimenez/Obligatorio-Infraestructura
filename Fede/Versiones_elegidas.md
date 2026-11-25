# Versiones elegidas

Fede definió el 25/11/2026 las siguientes versiones como definitivas entre sus alternativas:

- **Parte 2:** `Parte 2 v2/main.c`, con mensajes de inicio y final de despacho.
- **Parte 3:** `Parte 3/torneo.adb`, con las elecciones aleatorias directamente en la task.

Las otras versiones se conservan por ahora; no se eliminan ni se incluyen automáticamente en la entrega final.

## Pruebas en Windows

Se verificaron en copias aisladas, sin modificar los originales:

- **Parte 2 v2:** GCC 16.2.0, MSYS2 UCRT64 y winpthreads. Compilación sin advertencias, tres ejecuciones rápidas con trazas y una con tiempos reales. Las pruebas comprobaron 300 paquetes por etapa, FIFO, capacidades y prioridad; la salida real tuvo 1501 líneas y 300 pares de inicio/final correctos.
- **Parte 3:** GNAT 16.2.0 para Windows. Compilación sin advertencias, 20 ejecuciones rápidas y dos con tiempos reales. Ocho partidos y resultados únicos, ganadores válidos, hasta tres canchas concurrentes y finalización correcta.
- **Parte 1b:** Git Bash de Windows. Los recorridos de usuarios, asignación, actualización, reportes, correlativos y persistencia fueron comprobados. Tras corregir la lectura del retorno de carro en disponibilidad, también se comprobaron CSV LF y CRLF en Git Bash y Ubuntu WSL; no se convierte el CSV original.

Los compiladores de C y Ada generaron ejecutables nativos de Windows; estas pruebas no usaron WSL ni Docker. La ejecución de Bash utiliza Git Bash.

El script de Parte 1 conserva finales LF. La lectura de disponibilidad admite los CSV LF y CRLF comprobados; ya no se exige convertir el CSV suministrado para esas operaciones.
