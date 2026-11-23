# Nota interna: operaciones de cadenas

Fede indicó conservar las operaciones actuales de cadenas de la Parte 4. Esta nota registra el criterio conversado para revisarlas; no es una sección adicional de la documentación de entrega.

- `Index` encuentra el espacio que separa la acción del identificador en mensajes como `SOLICITAR 1`.
- Los cortes `Texto (inicio .. fin)` extraen una parte de la cadena: la acción, el identificador o una respuesta sin sus finales de línea.
- `'First` y `'Last` indican los índices inicial y final de un arreglo o cadena.
- `Trim` elimina los espacios de los extremos. Se usa para formar nombres como `puerto:permiso:1` a partir del texto generado por `'Image`.

`Index` y `Trim` pertenecen a la biblioteca estándar `Ada.Strings.Fixed`; los cortes y los atributos de límites son construcciones del lenguaje. No se encontraron ejemplos específicos de estas operaciones en el material Ada revisado. Esto no las convierte por sí solo en elecciones problemáticas: son operaciones sencillas con una función concreta en el manejo de mensajes, y se acordó mantenerlas.

La revisión debe tener mesura: distinguir una operación básica del lenguaje de una biblioteca o mecanismo que requiera una explicación más amplia. No hace falta crear automáticamente una justificación separada para cada detalle sintáctico. Antes de entregar se decidirá qué explicación resulta útil incorporar a la documentación general.

Como respaldo relacionado, `8. ADA (1) (1).pdf`, diapositiva 19, enseña `'Length` e `Integer'Value`; `Laboratorios Infra (1).pdf`, página 60, utiliza `'Range`. Esas referencias respaldan los atributos y conversiones que efectivamente muestran, no un ejemplo docente de todas las operaciones enumeradas aquí.

Referencia externa para `Index` y `Trim`: [Manual de Ada, A.4.3](https://www.adaic.org/resources/add_content/standards/12rm/html/RM-A-4-3.html).

## Normalización de las respuestas de redis-cli

Se conserva la limpieza de CR/LF en `Recibir`, sin extraer una función auxiliar. Al retirar la comparación diagnóstica de `SET` con `OK`, se retiró también la limpieza de `Preparar`, que dejó de tener uso.

La limpieza responde al mecanismo elegido: `redis-cli` imprime respuestas como texto y `GNAT.Expect` captura también sus finales de línea. No es una validación adicional de entradas del usuario. Permite devolver el contenido del mensaje sin sus finales de línea y reconocer una consulta sin mensaje para seguir esperando. Las comparaciones con `AUTORIZADO` y `OK` fueron retiradas como diagnósticos prescindibles. Durante la implementación se observó que los finales de línea interferían con la comparación de la respuesta de `SET`.

El código comienza en `Respuesta'Last` y retrocede mientras el carácter sea LF (salto de línea) o CR (retorno de carro). Luego utiliza el corte hasta el último carácter de contenido. No borra espacios ni modifica el interior del mensaje. La condición con `and then` comprueba primero que exista una posición válida antes de consultar el carácter, incluso cuando la respuesta está vacía o solo contiene finales de línea.

Esta limpieza se conserva por su función en la lectura de respuestas, independientemente de que posteriormente se retiren algunas comprobaciones diagnósticas. La revisión inicial fue documental; posteriormente se aplicó la simplificación de diagnósticos acordada.
