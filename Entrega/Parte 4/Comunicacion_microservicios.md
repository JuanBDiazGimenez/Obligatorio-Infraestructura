# Parte 4 — Comunicación entre microservicios

## Organización y elección del mecanismo

La solución ejecuta tres barcos Ada independientes, un coordinador Ada y Redis. Cada barco utiliza el mismo ejecutable con un identificador distinto, recibido mediante `Ada.Command_Line`; son procesos en contenedores separados, no tasks de un único programa.

Se eligió Redis como intermediario de mensajes porque permite insertar y retirar elementos de listas mediante operaciones individuales, y su uso para comunicar servicios fue trabajado en el laboratorio de Voting App. La adaptación a Ada se realiza mediante `redis-cli`: los programas lo ejecutan y reciben su salida en memoria. No se utilizan archivos temporales para intercambiar mensajes ni otro lenguaje para implementar la lógica del puerto.

El coordinador es el único que conserva y modifica el ocupante del atracadero y la fila de solicitudes pendientes. Así no hay tres copias independientes decidiendo si el lugar está libre.

## Mensajes y claves

| Clave Redis | Contenido y uso |
|---|---|
| `puerto:eventos` | Lista común: los barcos envían `SOLICITAR 1`, `LIBERAR 1`, etc.; el coordinador retira los eventos. |
| `puerto:permiso:1`, `puerto:permiso:2`, `puerto:permiso:3` | Buzón individual: el coordinador deposita `AUTORIZADO` para el barco elegido y solo ese barco lo retira. |
| `puerto:listo` | Marca de preparación inicial; no autoriza a entrar al atracadero. |

`Enviar` usa `RPUSH`, que agrega al final de una lista. `Recibir` usa `LPOP`, que retira el primer elemento en una sola operación. Si no hay un mensaje, espera 0,1 segundos y vuelve a consultar. Esa pausa evita consultas continuas; el orden de atención lo conservan las listas y la fila del coordinador.

## Un ciclo de acceso

1. Un barco navega durante un tiempo aleatorio de 1 a 3 segundos, envía `SOLICITAR` con su identificador y espera en su buzón.
2. El coordinador recibe la solicitud y la guarda en una cola circular FIFO. Si el atracadero está ocupado, sigue recibiendo eventos sin conceder otro permiso.
3. Cuando está libre y hay pendientes, retira al primero y asigna `Ocupante` a ese barco **antes** de enviarle `AUTORIZADO`.
4. El barco retira el mensaje de su buzón, entra y utiliza el atracadero entre 1 y 3 segundos al azar.
5. Al salir envía `LIBERAR` con su identificador. El coordinador procesa la liberación y puede autorizar al siguiente pendiente. El barco vuelve a navegar.

Si los barcos 2 y 3 solicitan mientras el 1 ocupa el lugar, quedan pendientes según el orden en que sus mensajes entraron a Redis. Después de la liberación del 1 se autoriza solo al primero; el otro espera la siguiente liberación. Solicitudes prácticamente simultáneas quedan ordenadas por las inserciones en la lista común.

El coordinador procesa un evento por vez. Mientras `Ocupante` sea distinto de cero no envía otro permiso. Cada barco mantiene una sola solicitud pendiente, espera su permiso y libera antes de volver a solicitar. Bajo este protocolo y con una única instancia del coordinador, nunca hay dos barcos autorizados a utilizar el atracadero simultáneamente. No se necesitan semáforos compartidos entre contenedores: el estado de concesión pertenece a un único proceso.

## Invocación desde Ada

`mensajeria.ads` declara la interfaz y `mensajeria.adb` reúne el acceso a Redis:

- `GNAT.Expect.Get_Command_Output` ejecuta `/usr/bin/redis-cli`, espera su terminación y devuelve su salida como `String`.
- `GNAT.OS_Lib.Argument_List` permite pasar argumentos separados, incluidos servidor `redis`, puerto `6739`, operación, clave y mensaje. No se arma una orden para que la interprete un shell. `--raw` pide salida sin formato adicional y `-e` permite reflejar errores de Redis en el código de salida.
- Los elementos de esa interfaz son accesos a cadenas. Se crean con `new String'(...)` y se liberan después de la llamada mediante `GNAT.OS_Lib.Free` para evitar acumular memoria en las consultas repetidas.
- `Estado : aliased Integer` y `Estado'Access` permiten que la función escriba el código de salida en esa variable. Si es distinto de cero, se lanza `Error_Comunicacion`.

Estos paquetes pertenecen a la biblioteca de GNAT, no a la biblioteca estándar de Ada. Su elección es la adaptación para llamar al cliente desde Ada; no se presenta como un ejemplo docente.

`Recibir` elimina únicamente CR y LF al final de la salida capturada. Así diferencia una respuesta vacía de un mensaje y entrega su contenido sin los finales de línea que imprime el cliente. Los bloques `declare` permiten crear cadenas locales con la longitud de cada respuesta. `Index` y los cortes separan la acción del identificador; `Trim` elimina el espacio inicial de `'Image` al construir los nombres de buzón.

Algunas funciones se llaman por su efecto, aunque no se examine su resultado: enviar, borrar, publicar la marca o retirar el permiso. Ada exige recoger esos resultados; se guardan en constantes. El Dockerfile utiliza `-gnatwa -gnatwU -gnatwe`: activa avisos generales, desactiva los de elementos no utilizados y trata los restantes como errores. `-gnat2012` selecciona Ada 2012 y `-gnato` activa comprobaciones de desbordamiento aritmético. Estas opciones no eliminan las comprobaciones de límites durante la ejecución.

## Infraestructura y arranque

Compose define una red interna y cinco servicios bajo el proyecto `atracadero`. Redis escucha en 6739 sin publicar el puerto al equipo; los programas lo localizan por el nombre de servicio `redis`. No se configura persistencia: `--save ""` desactiva los guardados periódicos y `--appendonly no`, el registro de operaciones.

El Dockerfile tiene una etapa de compilación sobre Ubuntu 24.04 con GNAT y otra de ejecución con `libgnat-13` y `redis-tools`. Copia los dos ejecutables a `/app`. El comando predeterminado inicia al coordinador; los tres servicios de barcos lo reemplazan por `/app/barco` con los argumentos 1, 2 y 3. Así reutilizan la imagen `atracadero-ada:local`.

El arranque sigue esta secuencia:

1. El `healthcheck` de Redis espera una respuesta a `PING`.
2. `depends_on` permite iniciar al coordinador. Su procedimiento `Preparar` elimina con `DEL` únicamente las claves de esta simulación, incluidos los permisos anteriores, y publica `SET puerto:listo 1`.
3. El `healthcheck` del coordinador consulta esa marca mediante `GET`. Compose inicia los barcos cuando la obtiene. Ambos chequeos usan intervalo de 1 segundo, timeout de 2 y 30 reintentos.

En el chequeo del coordinador, `CMD-SHELL` permite evaluar la comparación y `$$` deja que la sustitución del comando se realice dentro del contenedor. Esta espera evita que un barco envíe una solicitud que luego borre la preparación inicial. No es un mecanismo de recuperación ante fallos: se inicia y detiene el conjunto completo.

## Fuentes

- Letra, `Infraestructura Obligatorio Agosto 2026 (1).pdf`, páginas 11–13: barcos independientes, exclusión, comunicación e infraestructura a elegir y documentación exigida. FIFO es una decisión de esta solución.
- Laboratorio 8, Voting App: Redis como intermediario entre servicios. La invocación desde Ada, los buzones y el protocolo del atracadero son adaptaciones propias.
- [Biblioteca de GNAT](https://docs.adacore.com/gnat_rm-docs/html/gnat_rm/gnat_rm/the_gnat_library.html): `GNAT.Expect` y `GNAT.OS_Lib`.
- [Redis LPOP](https://redis.io/docs/latest/commands/lpop/) y [RPUSH](https://redis.io/docs/latest/commands/rpush/): operaciones de las listas.
- [Orden de arranque con Compose](https://docs.docker.com/compose/how-tos/startup-order/): dependencias y comprobaciones de salud.

El azar utiliza `Ada.Numerics.Discrete_Random`, de la biblioteca estándar, con un generador propio por barco inicializado una vez. La lógica de acceso y la comunicación descritas corresponden a los archivos Ada y a la configuración que acompañan este documento.
