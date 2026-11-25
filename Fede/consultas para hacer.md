# Consultas para hacer

## Alcance de contenidos entre semestres

**Consulta al profesor:** ¿se mantienen los mismos temas y criterios sobre los conceptos que podemos utilizar en este obligatorio respecto al semestre anterior? ¿Un concepto utilizado entonces sigue siendo válido ahora, siempre que corresponda al ejercicio y podamos explicar su funcionamiento?

La idea es aclarar el alcance general de los contenidos, sin comparar soluciones ni pedir autorización por cada construcción. Fede entiende que los temas se mantienen salvo Seguridad, que ya no se dicta; ese cambio queda como información a confirmar con el docente, no como un dato verificado.

## Parte 4: Ada.Command_Line y archivos de los barcos

Usamos un único archivo `barco.adb`, ejecutado en tres contenedores independientes. Cada ejecución recibe su identificador (1, 2 o 3) mediante `Ada.Command_Line`. Esto evita mantener tres archivos casi idénticos: cada barco sigue siendo un proceso independiente, con sus propias variables.

**Consulta al profesor:** ¿podemos usar esta organización con `Ada.Command_Line`, o se espera que entreguemos un archivo Ada distinto por cada barco, con su identificador fijo?

## Parte 4: GNAT.Expect y GNAT.OS_Lib

Estos paquetes vienen incluidos con GNAT; no son paquetes de la biblioteca estándar definida por el lenguaje Ada ni requieren instalar una biblioteca de terceros por separado. Son específicos del entorno GNAT.

Usamos `GNAT.Expect` para ejecutar `redis-cli` y recoger su respuesta en memoria. `GNAT.OS_Lib` proporciona la lista de argumentos y permite liberar la memoria utilizada. Así los programas Ada acceden a Redis para intercambiar mensajes, sin archivos de intercambio.

**Consulta al profesor:** ¿podemos utilizar `GNAT.Expect` y `GNAT.OS_Lib` como parte del mecanismo de comunicación de la parte 4, explicando su funcionamiento, aunque no se hayan trabajado en clase?

## Parte 4: Redis y coordinación del arranque

**Consulta al profesor:** ¿es adecuado usar Redis como intermediario entre los programas Ada, con `RPUSH` y `LPOP` para los mensajes y permisos individuales, y `DEL`, `SET` y `GET` para preparar y coordinar el arranque?

En concreto, el coordinador borra las claves de nuestra simulación con `DEL` y luego publica `SET puerto:listo 1`. Un chequeo de Compose consulta `GET puerto:listo` y permite arrancar los barcos cuando encuentra `1`. Así ningún barco manda solicitudes mientras se limpian las colas. La marca indica preparación terminada; no representa la disponibilidad del atracadero ni vigila permanentemente al coordinador.

Estos comandos pertenecen a Redis. La consulta los presenta como parte de la solución de comunicación e infraestructura que la parte 4 deja investigar y seleccionar, no como sintaxis Ada ni como mecanismos cuya implementación exacta se atribuya al curso. Complementa la consulta anterior sobre cómo invocamos `redis-cli` desde Ada.

## Ada: sintaxis básica y biblioteca estándar no vistas explícitamente

**Consulta al profesor:** ¿podemos utilizar construcciones básicas del lenguaje y funciones de la biblioteca estándar de Ada que no se hayan mostrado explícitamente en clase, siempre que comprendamos su funcionamiento y mantengamos una solución sencilla? ¿Este criterio se aplica tanto a la parte 3 como al código Ada de la parte 4? ¿Alcanza con poder explicarlas o se espera además una justificación específica en la documentación?

Como ejemplos para aclarar el alcance: cortes de cadenas (`Texto (inicio .. fin)`), atributos `'First` y `'Last`, y funciones estándar como `Index` y `Trim` para separar o limpiar mensajes. La pregunta es por el criterio general, no por obtener una autorización individual para cada operación básica.

### Referencia de la letra y alcance por aclarar

En `Infraestructura Obligatorio Agosto 2026 (1).pdf`, página 14, dentro de la rúbrica **Ejercicio Ada**, dice:

> En caso de presentar sentencias, bibliotecas, estructuras o soluciones no dadas en clase o ajenas a los laboratorios, deberá demostrar total solvencia en su utilización.

No habla específicamente de «bibliotecas externas»: incluye bibliotecas y también sentencias, estructuras y soluciones no vistas. Está bajo el apartado Ada, separado de **Ejercicio Docker**, por lo que no damos por explícita su aplicación al código Ada de la parte 4. Esa es parte de la aclaración que se busca.

Por otra parte, la página 12, en las consideraciones de la parte 4, deja al equipo investigar y seleccionar la comunicación y la infraestructura. La página 15 exige comprender todo el código y las configuraciones entregados. Estas disposiciones dan contexto a la consulta, sin sustituir la respuesta docente.

## Parte 4: resultados de funciones que no se utilizan

**Consulta al profesor:** algunas funciones se ejecutan para enviar comandos a Redis o esperar un permiso, pero su texto de respuesta ya no se comprueba. Como Ada exige recoger ese resultado, ¿es adecuado guardarlo sin utilizarlo y compilar con `-gnatwU` para desactivar esos avisos, manteniendo los demás avisos como errores? ¿Se prefiere otra organización sencilla?

Esto evita agregar lecturas artificiales con un `if` cuyo cuerpo no hace nada. Se verificó que los únicos avisos actuales de elementos no utilizados corresponden a las respuestas de RPUSH, DEL y SET y al texto del permiso. La opción desactiva toda esa categoría de avisos, no solo estos cuatro casos, pero no cambia la sincronización ni las comprobaciones durante la ejecución.
