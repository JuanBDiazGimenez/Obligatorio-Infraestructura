# Parte 1 b) – Sistema "Don Drones": guía para entender y explicar el código

Script: `don_drones_sistema.sh` (Bash 4+). Datos: `flota.csv` (drones) y `usuarios.csv` (`usuario:clave`). Si no existen, el script los crea (el de usuarios con `admin:admin`).

```bash
chmod +x don_drones_sistema.sh
./don_drones_sistema.sh
```

## 0. Qué se hizo y cómo (proceso)

1. Se leyeron los requisitos 1 a 7 del PDF y se armó una lista de funciones, una por requisito.
2. Se **reutilizó la lógica corregida de la parte a)**: la regla de `asignar` (disponible y batería `-gt 20`) y el `while ... < <(tail ...)` del conteo crítico, ahora dentro de funciones.
3. Se agregó lo nuevo: menús, usuarios, alta de dron con ID autogenerado, actualizar, y verificar que el dron exista.
4. Se probó una sesión completa (usuarios, altas, errores de validación, asignaciones, reporte) y se guardó la salida en `ejemplo_de_uso_salida.txt`.

## 1. Cómo está armado (mapa del script)
```
menu_sesion  ──(Sign Up)──> sign_up
     │
     └──(Log In)──> log_in ──ok──> menu_principal
                                      ├─ 1 ingresar_dron   (usa generar_id, leer_bateria, leer_disponible, mostrar_dron)
                                      ├─ 2 asignar_dron    (usa pedir_dron_existente)
                                      ├─ 3 actualizar_dron (usa pedir_dron_existente, leer_bateria, leer_disponible)
                                      ├─ 4 reporte_flota   (usa mostrar_dron)
                                      ├─ 5 Log Out  → vuelve a menu_sesion
                                      └─ 6 Salir    → termina el script
```
La última línea del script (`menu_sesion`) es la que arranca todo: antes solo se *definen* funciones.

## 2. Qué hay que saber de Bash para leerlo
| Cosa | Qué significa |
|---|---|
| `función() { ... }` | Agrupa comandos. Se llama escribiendo su nombre. Dentro, `$1`, `$2`... son sus argumentos. |
| `local x` | La variable existe solo dentro de la función. Sin `local` es global (por eso `$ID` y `$LINEA` se ven desde afuera). |
| `a && b` / `a \|\| b` | `b` corre solo si `a` tuvo éxito / falló. |
| `return` / `exit` | `return` sale de la función; `exit` termina todo el script. |
| `$(comando)` | Reemplaza por la salida del comando. |
| `$(( ))` | Aritmética entera. |
| `[ ]` vs `[[ ]]` | `[ ]` para números (`-gt`, `-lt`, `-le`) y archivos (`-f`); `[[ ]]` permite regex con `=~` y comparar con patrones. |
| `>` / `>>` | Redirige al archivo pisándolo / agregando al final. |
| `< <(comando)` | Alimenta un bucle con la salida de un comando **sin pipe** (el bucle queda en el shell principal). |

## 3. El script explicado por bloques

### 3.1 Inicio (líneas 4-12)
| Línea | Qué hace |
|---|---|
| 4 | `dirname "$0"`: carpeta del script. Así los CSV se buscan junto a él, no donde se ejecute. |
| 5-6 | Rutas de los dos archivos. |
| 7 | Arreglo con las 5 categorías. |
| 10 | Si `flota.csv` no existe (`-f`), lo crea con el encabezado. |
| 12 | Si `usuarios.csv` no existe, lo crea con `admin:admin` (requisito: admin por defecto). |

### 3.2 Funciones auxiliares (líneas 17-62)
| Función | Qué hace |
|---|---|
| `buscar_dron` (17-19) | Primero valida con regex que el ID tenga forma `ABC-123` (`^[A-Z]{3}-[0-9]+$`). Si sí, `grep "^$1,"` imprime la línea del CSV que empieza con ese ID. Si no existe, `grep` devuelve 1: la función "falla" y los demás lo usan para saber que el dron no existe. |
| `mostrar_dron` (22-26) | Imprime el formato pedido. Por defecto "Disponible"; si el 5º argumento es `No`, "No disponible". |
| `leer_bateria` (29-39) | Bucle que pide la batería hasta que cumpla `^[0-9]{1,3}$` (1 a 3 dígitos) y sea ≤ 100. `10#$BATERIA` fuerza base 10 (si no, `08` se tomaría como octal). Guarda el resultado en `$BATERIA`. |
| `leer_disponible` (42-52) | Bucle con `case`: `[Ss][Ii]` acepta si/SI/Si…, `[Nn][Oo]` acepta no/NO/No… y normaliza a `Si` o `No`. Cualquier otra cosa vuelve a preguntar. |
| `pedir_dron_existente` (55-62) | Pide el ID, lo pasa a mayúsculas (`${ID^^}`) y llama a `buscar_dron`. Si existe, guarda la línea en `$LINEA`; si no, muestra error y devuelve 1. Es la **verificación de existencia** que piden los requisitos 4 y 5. |

`|| exit 1` después de algunos `read`: si se cierra la entrada (Ctrl+D), el script termina en vez de repetir el prompt para siempre.

### 3.3 Requisito 3 – Ingresar dron (líneas 67-105)
| Líneas | Qué hace |
|---|---|
| 68-69 | `generar_id`: `${1^^}` pone la categoría en mayúsculas y `${prefijo:0:3}` toma las 3 primeras letras (Cargo → `CAR`). |
| 71 | Busca los IDs con ese prefijo, se queda con el número (`cut -d'-' -f2`), los ordena numéricamente y toma el mayor (`sort -n \| tail -n 1`). |
| 72 | `printf "%s-%03d"` arma `CAR-006` (mayor + 1, con ceros a la izquierda). `${ultimo:-0}` usa 0 si no había ninguno. |
| 78-80 | Muestra las categorías numeradas recorriendo el arreglo (`${!CATEGORIAS[@]}` son los índices). |
| 81-87 | Pide un número 1-5 hasta que sea válido y toma la categoría del arreglo. |
| 89-98 | Pide el modelo: no puede estar vacío ni tener coma (la coma rompería el CSV). |
| 99-100 | Reutiliza `leer_bateria` y `leer_disponible`. |
| 102-104 | Genera el ID, agrega la línea al CSV con `>>` y la muestra con `mostrar_dron`. |

### 3.4 Requisito 4 – Asignar (líneas 108-123) → lógica de la parte a)
| Líneas | Qué hace |
|---|---|
| 110 | Pide el dron y verifica que exista; si no, `return` (**novedad respecto a la parte a**). |
| 111-115 | `cut -d',' -f5` toma el campo 5; si no es `Si`, error. |
| 116-117 | Toma el campo 4 y lo compara con **`-gt`** (la corrección del problema 2). |
| 118 | `sed -i` cambia el `Si` final por `No` en la línea de ese dron. |

### 3.5 Requisito 5 – Actualizar (líneas 125-132)
Verifica que exista, pide batería y disponibilidad (con sus validaciones) y reescribe solo esos dos campos:
`sed -i "s/^$ID,\([^,]*\),\([^,]*\),[^,]*,[^,]*$/$ID,\1,\2,$BATERIA,$DISPONIBLE/"`
Cada `\([^,]*\)` captura un campo (categoría, modelo); `\1` y `\2` los vuelven a poner igual; los dos `[^,]*` finales (batería y disponible viejos) se reemplazan por los nuevos.

### 3.6 Requisito 6 – Reporte (líneas 136-147) → lógica de la parte a)
| Líneas | Qué hace |
|---|---|
| 138 y 144 | `while IFS=, read -r ... done < <(tail -n +2 archivo)`: **la corrección del problema 1**. Sin pipe, el bucle corre en el shell principal y `contador` no se pierde. |
| 139 | Salta líneas vacías (`continue`). |
| 140-143 | Si la batería es `-lt 20`, suma 1 al contador y agrega la línea formateada a `lista` (`+=` concatena; `$'\n'` es un salto de línea). |
| 145-146 | Imprime primero el conteo y después la lista (por eso se junta en una variable en vez de imprimir dentro del bucle). |

### 3.7 Requisito 2 – Usuarios (líneas 151-190)
| Función | Qué hace |
|---|---|
| `sign_up` | Rechaza usuario vacío o con `:` (155). Rechaza usuarios repetidos con `cut -d':' -f1 \| grep -qxF` (159): `-q` no imprime, `-x` línea completa, `-F` texto literal. `read -rs` oculta la clave (164). Rechaza clave en blanco (166). Guarda `usuario:clave` (170). |
| `log_in` | Pide usuario y clave y recorre `usuarios.csv` con `IFS=: read -r u c` (182-187). Si coinciden, guarda `USUARIO_ACTUAL` y `return 0`. Se lee con `< archivo` (no pipe) para que `USUARIO_ACTUAL` quede en el shell principal. |

### 3.8 Requisito 1 – Menús (líneas 194-236)

- Los dos menús son `while true` + `read` + `case`.
- `menu_sesion`: `2) log_in && menu_principal` → solo entra al menú principal si el login fue exitoso.
- `menu_principal`: `5)` hace `return` (cierra sesión y vuelve al menú de sesión); `6)` hace `exit 0` (termina el programa). El requisito 7 es esa opción.

## 4. Demo en vivo (5 min)
Elegir una de estas pruebas y mostrarla en el terminal:

1. Sign Up con `admin` → "ya existe"; con clave en blanco → error; crear `noe`/`1234`.
2. Log In con clave incorrecta → error; luego correcto → menú principal.
3. Ingresar dron: batería `150`, `abc`, `08` (el sistema la reintenta) → `CAR-006 - Cargo - SkyHauler X3 - 8% - Disponible`.
4. Asignar `CAR-006` (8 %) → "Bateria insuficiente". Asignar `car-001` → asignado. Asignar `ZZZ-9` → "no existe".
5. Actualizar `CAR-006` a 90 % y asignar → ahora sí.
6. Reporte → conteo y lista de críticos.

Para restaurar los datos entre pruebas, volver a copiar el `flota.csv` original y borrar `usuarios.csv`. La sesión completa de ejemplo está en `ejemplo_de_uso_salida.txt` (por haberse ejecutado con la entrada por pipe, ahí no se ven las teclas escritas, solo los prompts y respuestas).

## 5. Preguntas probables de defensa (responder sin mirar)

1. ¿Qué diferencia hay entre `return` y `exit`? → `return` sale de la función; `exit` termina el script.
2. ¿Por qué `done < <(tail -n +2 ...)` y no un pipe? → Con pipe el `while` corre en un subshell y las variables se pierden (problema 1 de la parte a).
3. ¿Qué hace `${ID^^}`? ¿Y `${prefijo:0:3}`? → Mayúsculas; subcadena desde la posición 0 de largo 3.
4. ¿Para qué sirve `10#`? → Para que `08` se interprete en base 10 y no como octal (error).
5. ¿Cómo se genera el ID? → Prefijo de 3 letras + mayor número existente de esa categoría + 1, con `printf "%03d"`.
6. ¿Cómo se verifica que un dron existe? → `buscar_dron` hace `grep "^ID,"`; si no encuentra, devuelve 1.
7. ¿Qué hace el `\1` del `sed`? → Reinserta lo capturado por el primer `\( \)`.
8. ¿Por qué `read -rs` en la clave? → `-s` no muestra lo escrito; `-r` no interpreta `\`.
9. ¿Qué pasa si se cierra la entrada con Ctrl+D? → `read ... \|\| exit 1` termina el script.
10. ¿Qué pasa con un dron de exactamente 20 %? → No se puede asignar (`-gt 20`) ni se cuenta como crítico (`-lt 20`). Es la regla heredada de la parte a.

## 6. Limitaciones conocidas

- Las claves se guardan en texto plano (alcance del obligatorio; en un sistema real se guardaría un hash).
- Sin control de concurrencia: dos instancias a la vez podrían pisarse el CSV.
- `${var^^}` requiere Bash 4+ (no está en el Bash 3.2 de macOS).

## 7. Declaración de uso de IA

- **Herramienta:** Claude Code (Claude Sonnet 5.5, Anthropic).
- **Contexto de uso:** diseño y redacción inicial del script y de esta documentación, y pruebas de la sesión de ejemplo.
- **Verificación propia:** [completar: qué ejecutó, revisó y modificó cada integrante].
- Somos responsables de cualquier error del contenido generado.
