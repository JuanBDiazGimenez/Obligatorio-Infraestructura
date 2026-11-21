# Parte 1.b — Sistema Don Drones

## Ejecución y archivos

Ejecutar con Bash en Linux o Git Bash:

```bash
bash "Fede/Parte 1/don_drones.sh"
```

También se puede entrar en la carpeta del script y ejecutar `bash don_drones.sh`.
Para ejecución directa en Linux: `chmod +x don_drones.sh` y `./don_drones.sh`.
El script se entrega con finales LF. Usa Bash y utilidades habituales: `dirname`,
`mktemp`, `mv` y `rm`. No requiere Python ni otro lenguaje para funcionar.

- `don_drones.sh`: extensión independiente de los scripts de la parte a.
- `flota.csv`: copia inicial de la flota provista, con las mismas cinco columnas.
- `usuarios.csv`: se crea en el primer arranque, con `admin,admin`. Persiste los
  registros posteriores. No se regenera en cada inicio.

Los archivos se buscan junto al script mediante `cd` y `dirname`, por lo que la
carpeta desde la que se lanza el comando no cambia qué flota se modifica.
Si falta `flota.csv`, el programa informa el problema y termina sin inventar datos.
Para experimentar sin alterar la versión de trabajo, copiar el script y el CSV a
otra carpeta. Las operaciones de alta, asignación y actualización cambian ese CSV.

## Menús y responsabilidades

Sin sesión, el menú permite registrarse, iniciar sesión o salir. Con sesión, permite
ingresar, asignar y actualizar drones, consultar la flota, cerrar sesión o salir.
Cerrar sesión vuelve al primer menú; salir termina el proceso. Una entrada agotada
también finaliza, evitando un bucle que imprima menús indefinidamente.

`leer` obtiene una línea conservando espacios y barras con `IFS= read -r`.
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

`ingresar_dron` ofrece las cinco categorías. Busca el mayor sufijo de esa categoría
y suma uno. Así, con la flota inicial, el siguiente Cargo es `CAR-006`. `10#` trata
el sufijo como decimal aunque tenga ceros iniciales. `printf` con `%03d` da al menos
tres cifras; no trunca números mayores a 999. El mismo criterio continúa después
de reiniciar porque lee los IDs persistidos.

`guardar_actualizacion` reconstruye el CSV en un archivo temporal creado con
`mktemp` y reemplaza la flota con `mv` cuando termina. Cambia batería y disponibilidad
de la fila buscada, conserva categoría, modelo, orden y encabezado, y evita usar
texto del usuario como una expresión de sustitución. Se usa en asignación y
actualización. El alcance es una sesión del programa a la vez; no se implementó
coordinación de escrituras entre varias instancias.

## Reutilización de la parte a y validaciones

`asignar_dron` conserva las dos condiciones de la solución corregida: disponibilidad
`Si` y batería numéricamente mayor a 20 (`-gt`). Una asignación exitosa cambia la
disponibilidad a `No`, sin descontar batería porque la letra no lo pide.
Con batería exactamente 20 no se asigna; no se cambió el umbral a `-ge`.

`reporte_flota` mantiene el contador fuera de un pipeline. El bloque con llaves
recibe la flota mediante `<`, consume el encabezado y recorre las filas en el shell
actual, igual que la corrección de Fede en 1.a. Cuenta y reúne las filas con batería
menor a 20 (`-lt`), mostrando primero el total y luego el detalle mediante
`mostrar_dron`. Cuenta también los drones no disponibles, porque el criterio es la
batería. La sustitución de comandos usada para formatear cada fila no modifica el
contador. Con cero críticos, muestra cero sin filas adicionales.

Se admiten baterías enteras de 0 a 100, con hasta tres dígitos; `08` se guarda como
8. No se admiten modelos, usuarios o contraseñas vacíos o compuestos solo por
espacios. Se rechazan comas y retornos de carro porque el CSV simple no implementa
campos entrecomillados. La disponibilidad admite Si/No en las variantes indicadas
en el código y guarda siempre `Si` o `No`. Categorías y menús se eligen por número.
Se supone una flota inicial válida como la provista; no se reparan archivos editados
manualmente con columnas o identificadores inválidos.

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
- `Parte 1/don_drones_manager_fix.sh` y `parte1a_problema1_Fede.md`: base corregida
  del equipo para el contador y la comparación. No se modifican desde la extensión.

La distribución en funciones, el archivo de usuarios, el cálculo del mayor ID y
la actualización por archivo temporal son decisiones de esta implementación,
no soluciones atribuidas al docente. `help read`, `help printf`, `help local` y
`help [[` permiten consultar la ayuda incorporada de Bash sobre las construcciones
usadas. `mktemp` evita elegir un nombre temporal fijo.

## Uso de IA y estado

Codex (modelo identificado en la sesión como GPT-6) se utilizó para implementar,
documentar y verificar esta propuesta. La revisión y comprensión por los integrantes
del equipo quedan pendientes; no se atribuye el contenido generado a una revisión
humana ya realizada. Este Markdown es la fuente editable de la documentación; el
PDF acompaña la propuesta para la entrega.
