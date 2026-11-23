# GNAT.Expect y GNAT.OS_Lib

**GNAT.Expect** permite que nuestro programa Ada ejecute `redis-cli` y reciba su respuesta como texto en memoria. Lo usamos mediante `Get_Command_Output`: le indicamos el comando y sus argumentos, espera a que termine y devuelve lo que imprimió. Así enviamos y recibimos mensajes de Redis sin usar archivos de intercambio.

**GNAT.OS_Lib** proporciona la estructura con la que armamos los argumentos de `redis-cli`, como el servidor, el puerto y la operación `LPOP` o `RPUSH`. En nuestro código también permite liberar la memoria reservada para esos argumentos después de ejecutar el comando. Complementa a `GNAT.Expect` y forma parte del acceso a Redis que elegimos para comunicar los programas Ada.

## Cómo se usa en `mensajeria.adb`

La función `Ejecutar` reúne este mecanismo para que los demás procedimientos no tengan que repetirlo. Estas construcciones no se presentan como contenido dado en clase: son una adaptación para invocar `redis-cli` desde Ada, dentro del mecanismo de comunicación elegido para la parte 4.

### `Argument_List` y `new`

`GNAT.OS_Lib.Argument_List` es un arreglo cuyos elementos son accesos a cadenas: cada posición permite localizar el texto de un argumento. Por ejemplo:

```ada
Argumentos : GNAT.OS_Lib.Argument_List :=
  (new String'("-h"), new String'("redis"),
   new String'("-p"), new String'("6739"),
   new String'("--raw"), new String'("-e"),
   new String'(Operacion), new String'(Cola), new String'(Dato));
```

Cada `new String'(...)` reserva memoria para una cadena con ese contenido y devuelve un acceso a ella. No es que Ada obligue a crear así cualquier texto: lo hacemos porque esta interfaz espera accesos a cadenas, no un arreglo de cadenas comunes. Los argumentos se entregan separados; por ejemplo, un mensaje `SOLICITAR 1` ocupa una sola posición aunque contenga un espacio. No construimos una orden para que la interprete un shell.

### `Get_Command_Output`

Esta función pertenece a `GNAT.Expect`. Ejecuta `/usr/bin/redis-cli`, recibe los argumentos que armamos, espera a que el proceso termine y devuelve su salida como un `String`:

```ada
Salida : constant String := GNAT.Expect.Get_Command_Output
  (Command => "/usr/bin/redis-cli",
   Arguments => Argumentos (1 .. Ultimo_Argumento),
   Input => "", Status => Estado'Access, Err_To_Out => True);
```

`Input => ""` indica que no enviamos texto por la entrada estándar. `Err_To_Out => True` incorpora también la salida de error al texto recogido. Pasamos ocho argumentos para operaciones como `LPOP` y nueve cuando la operación necesita además un dato, como `RPUSH` o `SET`.

### `aliased` y `'Access`

```ada
Estado : aliased Integer;
```

`Estado` es una variable que recibe el código de salida del comando. `aliased` permite obtener un acceso a esa variable mediante `Estado'Access`. La función recibe ese acceso y escribe allí el código: el texto vuelve como resultado de la función y el código de salida queda en `Estado`. En nuestro código, si ese código es distinto de cero se señala un error de comunicación.

Esta función exige un parámetro `Status : not null access Integer`; no acepta simplemente un entero ni permite omitirlo. Por eso no alcanza con quitar `aliased`. `Estado` no se crea con `new` y no se libera con `Free`: sigue siendo una variable local cuya duración gestiona Ada.

### `Free`

```ada
for Argumento of Argumentos loop
   GNAT.OS_Lib.Free (Argumento);
end loop;
```

`Free` libera la memoria reservada por cada `new` y deja el acceso en `null`. Es necesario porque consultamos Redis repetidamente: sin liberar las cadenas, la memoria reservada se acumularía. Liberamos los nueve elementos, incluido el último aunque la operación solo haya utilizado ocho.

Se conserva la liberación del recorrido normal. No hay un manejador `when others` para realizar limpieza cuando una excepción interrumpe la llamada: se retiró como parte de la simplificación de diagnósticos acordada. El control `Estado /= 0` permanece y se ejecuta después de liberar los argumentos.

En resumen, `new`, `aliased` y `'Access` son construcciones del lenguaje Ada; `Argument_List` y `Free` los proporciona `GNAT.OS_Lib`, y `Get_Command_Output` pertenece a `GNAT.Expect`. No son todos elementos de una misma biblioteca ni todos fueron vistos en clase. Se justifican aquí por la interfaz utilizada para ejecutar `redis-cli` y recoger su respuesta sin archivos de intercambio.

## Referencias externas

- [Especificación de GNAT.Expect](https://gnu.googlesource.com/gcc/+/refs/heads/releases/gcc-7/gcc/ada/g-expect.ads): firma y comportamiento de `Get_Command_Output`.
- [Biblioteca de GNAT](https://docs.adacore.com/gnat_rm-docs/html/gnat_rm/gnat_rm/the_gnat_library.html): paquetes `GNAT.Expect` y `GNAT.OS_Lib`.
- [Tipos de acceso en Ada, AdaCore](https://learn.adacore.com/courses/intro-to-ada/chapters/access_types.html): accesos, reserva de memoria y variables `aliased`.

La explicación corresponde al código actual. No implica una autorización docente: la consulta sobre el uso de estos paquetes sigue registrada en `Fede/consultas para hacer.md`.
