# Parte 1.b — Sistema Don Drones

## Ejecución y archivos

Ejecutar con Bash en Linux o Git Bash:

```bash
cd "Fede/Parte 1"
bash don_drones.sh
```

Los comandos anteriores parten de la raíz del repositorio.
Para ejecución directa en Linux: `chmod +x don_drones.sh` y `./don_drones.sh`.
El script se entrega con finales LF. Usa Bash y comandos `grep`, `cut`, `sed` y `echo`. No requiere Python ni otro lenguaje para funcionar.

- `don_drones.sh`: extensión independiente de los scripts de la parte a.
- `flota.csv`: copia inicial de la flota provista, con las mismas cinco columnas.
- `usuarios.csv`: se crea en el primer arranque, con `admin,admin`. Persiste los
  registros posteriores. No se regenera en cada inicio.

Los archivos se buscan con rutas relativas a la carpeta actual. Antes de ejecutar,
entrar a la carpeta que contiene el script y los CSV. Si falta flota.csv, se informa
el problema y se termina sin inventar datos. Para probar sin alterar la flota de
trabajo, copiar el script y el CSV a otra carpeta, entrar en ella y ejecutar allí.

## Menús y responsabilidades

Sin sesión, el menú permite registrarse, iniciar sesión o salir. Con sesión, permite
ingresar, asignar y actualizar drones, consultar la flota, cerrar sesión o salir.
Cerrar sesión vuelve al primer menú; salir termina el proceso. Una entrada agotada
también finaliza, evitando un bucle que imprima menús indefinidamente.

`leer` obtiene una línea conservando espacios y barras con `IFS= read -r`.
Los mensajes se muestran con `echo`.
`pedir_texto`, `pedir_bateria` y `pedir_disponibilidad` repiten la pregunta ante
entradas inválidas. Las variables `local` limitan los datos auxiliares a su función.
`RESPUESTA`, los datos encontrados del dron y los valores nuevos de batería y
disponibilidad permiten pasar resultados entre las funciones y sus llamadas.

`buscar_usuario` compara nombres como texto exacto. `registrar` impide duplicados
y guarda usuario y contraseña. `iniciar_sesion` exige que ambos coincidan y recién
entonces establece `USUARIO_ACTUAL`. Las contraseñas se almacenan en texto simple
para este ejercicio local: no es un sistema de autenticación para uso real.

`buscar_dron` recorre las filas y compara el ID completo; un ID inexistente se
informa antes de asignar o pedir nuevos valores. El texto ingresado no se interpreta
como expresión regular ni como comandos.

`ingresar_dron` ofrece las cinco categorías. La variable `categoria_valida` empieza en 0 y el `while` repite la pregunta mientras siga en 0. Una opción válida establece la categoría, el prefijo y el valor 1; una inválida muestra el mensaje y vuelve a preguntar. No se usan `break` ni `continue`.

Para generar el ID, se extrae el sufijo con `cut`, se busca el mayor de la categoría y se suma uno. Así, con la flota inicial, el siguiente Cargo es `CAR-006`. Un contador comienza en cero y aumenta con un `while` hasta igualar el sufijo; así se obtiene el valor decimal sin evaluar directamente el texto con ceros iniciales dentro de una expresión aritmética. Los condicionales anteponen `00` si el número es menor a 10 y `0` si es menor a 100; desde 100 se usa el número completo, sin truncarlo. El mismo criterio continúa después
de reiniciar porque lee los IDs persistidos.

`guardar_actualizacion` usa `sed -i`, como el script original. Selecciona la fila
por ID, conserva categoría y modelo mediante grupos, y sustituye batería y
disponibilidad. El script no administra un archivo temporal. Se usa para asignar
y actualizar. El alcance sigue siendo una instancia a la vez.

## Reutilización de la parte a y validaciones

`asignar_dron` conserva las dos condiciones de la solución corregida: disponibilidad
`Si` y batería numéricamente mayor a 20 (`-gt`). Una asignación exitosa cambia la
disponibilidad a `No`, sin descontar batería porque la letra no lo pide.
Con batería exactamente 20 no se asigna; no se cambió el umbral a `-ge`.

`reporte_flota` mantiene el contador fuera de un pipeline. Un primer recorrido
con `while IFS=, read -r` cuenta las filas con batería menor a 20 y muestra el total.
Un segundo recorrido muestra cada dron crítico mediante `mostrar_dron`. No se
acumula un listado en una variable. Se cuentan también los drones no disponibles,
porque el criterio es la batería. Con cero críticos se muestra cero sin detalle.

Las validaciones de número y texto usan `grep -E` y condicionales. El resultado
del filtro se captura mediante sustitución de comandos, como las consultas con
`grep` del script original. Los menús conservan `case`, que ya figura en ese
original. Las decisiones antes encadenadas con operadores lógicos se expresan
mediante condicionales. No se anteponen caracteres artificiales a las entradas.

Se admiten baterías enteras de 0 a 100, con hasta tres dígitos. Después de validar los dígitos, un contador empieza en cero y aumenta hasta alcanzar el valor ingresado: `008` se guarda como 8, sin usar `10#`. No se admiten modelos, usuarios o contraseñas vacíos o compuestos solo por
espacios. Se rechazan comas porque el CSV simple no implementa
campos entrecomillados. La disponibilidad admite Si/No en las variantes indicadas
en el código y guarda siempre `Si` o `No`. Categorías y menús se eligen por número.
Se supone una flota inicial válida como la provista; no se reparan archivos editados
manualmente con columnas o identificadores inválidos.

Los auxiliares de búsqueda y validación usan `return 0` para indicar éxito y
`return 1` para indicar que no se encontró o no se aceptó el dato. Una llamada
como `if buscar_usuario ...` decide según ese estado. `if ! ...` invierte la
condición. Los `while true` de los menús y solicitudes repiten hasta que se
alcanza un `return` o un `exit`, según corresponda. Se conservan como usos básicos
de control acordados con Fede; no se atribuye al material un ejemplo idéntico.

`local` mantiene separados los datos auxiliares durante la llamada. El patrón
`[^[:space:]]` requiere al menos un carácter que no sea espacio en blanco. Ambos
usos se conservan con autorización explícita. No se incorporan caracteres
artificiales a las entradas. La disponibilidad leída del CSV se limpia como se explica al final para admitir LF y CRLF.
El valor `-n` no supera la validación de texto actual; no se agregó un caso especial.

## Ejemplo completo desde los datos iniciales

1. Iniciar el programa, elegir **1. Registrarse**, usuario `fede`, contraseña
   `clave123`. Informa que el usuario quedó registrado.
2. Elegir **2. Iniciar sesión** e ingresar esos datos. Aparece el menú principal.
3. Elegir **1. Ingresar dron**, categoría **2 (Cargo)**, modelo `Sky Test`, batería
   `8`, disponibilidad `Si`. Muestra:

   ```text
   CAR-006 - Cargo - Sky Test - 8% - Disponible
   ```

4. Elegir **4. Reporte de flota**. Indica **8** drones críticos: los siete originales
   y `CAR-006`, que aparece con batería 8 %.
5. Elegir **2. Asignar dron a reparto**, ID `CAR-006`. Informa batería insuficiente
   y conserva el registro.
6. Elegir **3. Actualizar dron**, ID `CAR-006`, batería `80`, disponibilidad `Si`.
   Informa la actualización.
7. Elegir **2. Asignar dron a reparto**, ID `CAR-006`. Informa asignación exitosa y
   guarda `CAR-006,Cargo,Sky Test,80,No`.
8. Consultar el reporte: vuelve a haber **7** críticos. Elegir **5. Cerrar sesión**.
   Volver a entrar con el mismo usuario y elegir **6. Salir**.
9. Reiniciar: el usuario y el dron siguen guardados. Otra alta de Cargo recibe
   `CAR-007`. El usuario inicial `admin` / `admin` también permite ingresar.

## Fuentes y decisiones

- Letra `Infraestructura Obligatorio Agosto 2026 (1).pdf`, páginas 3–5: reutilización
  de 1.a, menús, usuarios, operaciones, persistencia y documentación.
- `Apuntes/09-08 Infraestructura y Procesos en C.md`, sección 3, «Automatización
  mediante Scripts en Bash»: funciones, variables, `read`, `if`, operadores
  numéricos y bucles. Es un apunte del curso, no una implementación oficial.
- `Material de clase/Laboratorios Infra (1).pdf`, páginas 13–16, parte 3:
  funciones, lectura desde teclado y escritura en archivos. El documento se titula
  «Solución laboratorio 1», pero no se comprobó la autoría de sus soluciones;
  no se presenta como una solución oficial del docente ni del obligatorio.
- `Transcripciones/Infra 09-29.txt`, sección de Parte 1: el docente explica que el
  material es una base y permite investigar mecanismos adicionales. La transcripción
  dice 90 % al leer batería crítica; se usa el 20 % explícito del PDF y del script
  base, sin tratar ese pasaje transcrito como una modificación oficial.
- `Material de clase/2. Sistema de archivos.pptx (3).pdf`, diapositivas 79-85,
  87 y 89-100: salida con echo, funciones, condicionales, bucles, lectura y regex
  con grep -E. Se adaptan estos mecanismos a menús, validaciones y correlativos.
- `Transcripciones/Infra 08-18.txt`, líneas 1180-1185: rutas relativas para
  conjuntos de archivos que se trasladan juntos. Aquí se requiere ejecutar desde
  la carpeta que contiene el script y los CSV.
- `Parte 1a/don_drones_manager.sh`: referencia provista para case, sustitución de
  comandos, lectura CSV, cut y actualización con sed -i.
- `Parte 1a/don_drones_manager_fix.sh` y `parte1a_problema1_Fede.md`: base corregida
  del equipo para el contador y la comparación. No se modifican desde la extensión.

La distribución en funciones, el archivo de usuarios, el cálculo del mayor ID y
la actualización con sed -i son decisiones de esta implementación,
no soluciones atribuidas al docente. `help read`, `help echo` y `help local` permiten consultar la ayuda incorporada de Bash sobre las construcciones
usadas.

## Uso de IA y estado

Codex (modelo identificado en la sesión como GPT-6) se utilizó para implementar,
documentar y verificar esta propuesta. La revisión y comprensión por los integrantes
del equipo quedan pendientes; no se atribuye el contenido generado a una revisión
humana ya realizada. Este Markdown es la fuente editable de la documentación; el
PDF acompaña la propuesta para la entrega.

## Estado de la documentación

Este Markdown corresponde al código actual. El PDF de implementación queda pendiente de actualización por indicación de Fede.
La revisión de respaldo quedó cerrada considerando el material, el script original
y las decisiones explícitas tomadas con Fede. Las combinaciones de mecanismos y
la organización del programa son adaptaciones propias, no una solución docente
textual. No quedan pendientes las sustituciones discutidas de dirname, mktemp,
10#, printf ni los controles con break/continue de la categoría.

Las comprobaciones realizadas en mi_ubuntu sobre copias temporales cubrieron
sintaxis, registro y login, entradas inválidas, las cinco categorías, operaciones,
reportes y persistencia. Se comprobaron también correlativos con ceros iniciales
y cambios de cantidad de cifras, y los límites de asignación con batería 20 y 21.
No se presenta esa verificación como una revisión humana del equipo.

## Lectura de disponibilidad con LF y CRLF

buscar_dron y mostrar_dron eliminan del valor de disponibilidad únicamente el retorno de carro final mediante `sed 's/\r$//'`. Esto permite interpretar Si/No en ambos finales de línea sin convertir el CSV original. sed proviene del script suministrado; esta aplicación concreta es una adaptación acordada. Comprobado en Git Bash y Ubuntu WSL con copias LF/CRLF el 25/11/2026; la lectura no reescribe el archivo.
