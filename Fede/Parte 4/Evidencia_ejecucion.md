# Parte 4 — Evidencia de ejecución

## Entorno y alcance

Los registros corresponden a la simulación en Docker: Redis, un coordinador Ada y tres barcos Ada ejecutados como servicios independientes. Se presentan fragmentos de los registros conservados y un escenario dirigido de solicitudes juntas. No se generó una ejecución nueva para preparar este documento.

Los tiempos de navegación y ocupación se eligen entre 1 y 3 segundos. La simulación es continua, por lo que los registros pueden terminar con un barco usando el atracadero o solicitudes pendientes. Ese corte no representa una terminación normal del programa.

## Varios barcos compitiendo

El comienzo del registro del coordinador muestra lo siguiente:

```text
PUERTO LISTO
SOLICITUD 3
AUTORIZACION 3
SOLICITUD 1
SOLICITUD 2
LIBERACION 3
AUTORIZACION 1
SOLICITUD 3
LIBERACION 1
AUTORIZACION 2
LIBERACION 2
AUTORIZACION 3
SOLICITUD 1
LIBERACION 3
AUTORIZACION 1
SOLICITUD 2
LIBERACION 1
AUTORIZACION 2
SOLICITUD 3
SOLICITUD 1
LIBERACION 2
AUTORIZACION 3
SOLICITUD 2
LIBERACION 3
```

El barco 3 recibe la primera autorización. Los barcos 1 y 2 solicitan mientras esa autorización sigue vigente. Solo después de `LIBERACION 3` se autoriza al 1, y después de `LIBERACION 1`, al 2. La nueva solicitud del 3 se registra mientras hay trabajo en curso y espera su turno.

Se revisó el registro completo del coordinador reconstruyendo el ocupante y la fila de solicitudes. Cada autorización encontró el atracadero libre y correspondió al primero de la fila; cada liberación correspondió al ocupante. Los totales de ese registro son:

| Barco | Solicitudes recibidas | Autorizaciones | Liberaciones |
|---|---:|---:|---:|
| 1 | 13 | 12 | 12 |
| 2 | 13 | 13 | 12 |
| 3 | 13 | 13 | 13 |

Hay 38 autorizaciones y 37 liberaciones. Al corte, el barco 2 conserva la autorización y el barco 1 espera: no aparece una autorización superpuesta. La fila pendiente sigue el orden de recepción.

## Actividad de los barcos

Estos fragmentos corresponden al primer ciclo mostrado en el registro individual de cada barco. Se presentan separados: no constituyen una concatenación cronológica entre contenedores.

### Barco 1

```text
BARCO 1 NAVEGA 1
BARCO 1 SOLICITA
BARCO 1 ENTRA 3
BARCO 1 SALE
```

### Barco 2

```text
BARCO 2 NAVEGA 2
BARCO 2 SOLICITA
BARCO 2 ENTRA 1
BARCO 2 SALE
```

### Barco 3

```text
BARCO 3 NAVEGA 1
BARCO 3 SOLICITA
BARCO 3 ENTRA 1
BARCO 3 SALE
```

Cada barco navega, solicita, entra y sale. En los registros individuales completos aparecen 12 ciclos con salida para el barco 1, 12 para el 2 y 13 para el 3. Los registros de los contenedores se recogieron por separado y pueden tener cortes diferentes; no se utilizan sus posiciones de línea para deducir un orden global.

La exclusión se observa en las autorizaciones y liberaciones del coordinador y se relaciona con el protocolo: el barco espera su permiso para entrar y envía la liberación después de salir. Los logs combinados pueden intercalarse al mostrarse y no tienen por qué reproducir ese orden visualmente.

## Solicitudes prácticamente simultáneas

Se conservó además un escenario dirigido: con Redis y el coordinador activos, sin los procesos de barcos, se enviaron solicitudes en orden 2, 3 y 1, sin esperar las liberaciones entre solicitudes. Luego se enviaron las liberaciones correspondientes. Son mensajes de prueba que permiten observar la decisión del coordinador, no otro registro de navegación real.

```text
PUERTO LISTO
SOLICITUD 2
AUTORIZACION 2
SOLICITUD 3
SOLICITUD 1
LIBERACION 2
AUTORIZACION 3
LIBERACION 3
AUTORIZACION 1
LIBERACION 1
```

El permiso del 2 se concede primero. Las solicitudes del 3 y del 1 quedan esperando. El coordinador autoriza al 3 después de la liberación del 2 y al 1 después de la del 3. No se concede un segundo permiso mientras el anterior sigue vigente.

## Interpretación

Los registros muestran participación repetida de los tres barcos, espera con el atracadero ocupado y concesión de permisos sin superposición. El escenario dirigido permite observar además la atención FIFO cuando se acumulan solicitudes. Esta evidencia se complementa con la explicación del protocolo: una ejecución registrada por sí sola no demuestra todos los órdenes de ejecución posibles.

Los fragmentos proceden de `simulacion_coordinador.txt`, `simulacion_barco1.txt`, `simulacion_barco2.txt`, `simulacion_barco3.txt` y `solicitudes_juntas.txt`, conservados durante las pruebas. Este documento incorpora los fragmentos relevantes para presentar la evidencia sin requerir un verificador Python.
