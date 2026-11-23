# Construcciones de Ada utilizadas en la Parte 4

Nota interna para comprender el código actual. Estas construcciones pertenecen al lenguaje Ada; no se presentan como ejemplos específicos dados en clase.

## Subtipos y rangos

```ada
subtype Id_Barco is Positive range 1 .. 3;
```

Un subtipo conserva el tipo de base y restringe sus valores permitidos. En este caso, `Id_Barco` admite los identificadores 1, 2 y 3. No crea un tipo completamente independiente de `Positive`. Asignar un valor fuera del rango provoca una excepción de comprobación de límites; no se recorta automáticamente el número.

En `barco.adb`, `subtype Segundos is Integer range 1 .. 3` también delimita los valores que genera la instancia de `Discrete_Random`: las duraciones elegidas están entre uno y tres segundos.

`range` puede restringir directamente una variable, sin nombrar un subtipo:

```ada
Ocupante : Natural range 0 .. 3 := 0;
```

Aquí cero representa el atracadero libre y 1, 2 o 3 identifican al barco autorizado. Los índices `Entrada` y `Salida` admiten 1 a 3, y `Cantidad` admite 0 a 3. Son límites de los datos; no sustituyen la lógica de sincronización.

## Bloques `declare`

Un bloque `declare` permite declarar variables o constantes locales en medio de la ejecución. Primero se elaboran sus declaraciones y después se ejecutan las instrucciones comprendidas entre `begin` y `end`.

```ada
declare
   Mensaje : constant String := Recibir (Eventos);
begin
   -- Procesar el mensaje recibido.
end;
```

En cada entrada al bloque se recibe un mensaje y se crea una cadena con la longitud de ese resultado. Esto resulta útil porque una variable `String` común tiene límites fijos una vez creada: no se puede reutilizar sin más para textos de cualquier longitud. El bloque también limita dónde se puede usar el nombre `Mensaje`.

No crea otra task ni ejecuta instrucciones concurrentemente. En el coordinador, los bloques permiten trabajar con cada mensaje y con el siguiente barco a autorizar. En mensajería permiten trabajar con la salida de cada comando; en el barco, con el permiso recibido.

Salir del bloque no libera automáticamente las cadenas creadas mediante `new` en otro lugar: esas reservas se gestionan con `Free`, como se explica en `GNAT_Expect_y_OS_Lib.md`.

## `others` en excepciones: retirado

`when others` capturaba cualquier excepción que llegara al manejador de `Ejecutar`, liberaba los argumentos y volvía a propagarla con `raise;`. Ese bloque fue retirado por la decisión de simplificar el manejo de errores. Los `Free` del recorrido normal y el control del código de salida de `redis-cli` permanecen.

## Resultados que no se utilizan

Ada no permite invocar una función como si fuera un procedimiento y descartar directamente el resultado. Por eso conservamos constantes para recibir las respuestas de `RPUSH`, `DEL` y `SET`, y el permiso obtenido mediante `Recibir`, aunque ya no examinemos su contenido.

El Dockerfile utiliza `-gnatwa -gnatwU -gnatwe`: activa los avisos generales, desactiva la categoría de elementos no utilizados y trata los avisos restantes como errores. Así podemos guardar esos resultados sin agregar lecturas artificiales. Esto no cambia la ejecución ni desactiva comprobaciones de límites. El alcance y la consulta docente se explican en `Resultados_no_utilizados.md`.

## Alcance de esta nota

Explica la implementación existente; no introduce cambios ni implica que toda comprobación defensiva sea un requisito de la letra. Se retiraron los diagnósticos acordados; únicamente queda el lanzamiento explícito de `Error_Comunicacion` si falla la ejecución de `redis-cli`. Poder explicar estas construcciones y seguir sus efectos es lo relevante para comprender la solución.

Referencias técnicas externas: Manual de Ada, [subtipos y restricciones](https://www.adaic.org/resources/add_content/standards/12rm/html/RM-3-2-2.html), [bloques](https://www.adaic.org/resources/add_content/standards/12rm/html/RM-5-6.html) y [manejo de excepciones](https://www.adaic.org/resources/add_content/standards/12rm/html/RM-11-2.html).
