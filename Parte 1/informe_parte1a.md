# Parte 1 a) – Informe de diagnóstico: `don_drones_manager.sh`

## Problema 1 – "0 drones con batería crítica"

**Línea del fallo:** línea 16, `tail -n +2 "$ARCHIVO_FLOTA" | while IFS=, read -r ID CAT MODELO BATERIA DISP; do`
(el incremento está en la línea 18, `CONTADOR=$((CONTADOR + 1))`, y el `echo` en la 21).

**Qué hace Bash:**
1. En la línea 15 `CONTADOR=0` se crea en el shell principal.
2. El operador `|` ejecuta cada comando del pipeline en su **propio subshell** (un proceso hijo creado con `fork`). Por eso el `while` completo corre en un proceso hijo.
3. El hijo recibe una **copia** de las variables. Cada `CONTADOR=$((CONTADOR + 1))` modifica la copia del hijo (llega a 7 con `flota.csv`).
4. Cuando el `while` termina, el hijo muere y su copia de `CONTADOR` desaparece. Un proceso hijo no puede modificar las variables de su padre.
5. En la línea 21 el `echo` corre en el shell principal, donde `CONTADOR` sigue valiendo 0. Imprime "0".

La comparación `[ "$BATERIA" -lt "20" ]` está bien: el conteo se hace, pero en el proceso equivocado.

**Solución:** que el `while` corra en el shell principal, alimentándolo con *process substitution* en lugar de un pipe:
```bash
while IFS=, read -r ID CAT MODELO BATERIA DISP; do
    ...
done < <(tail -n +2 "$ARCHIVO_FLOTA")
```
`<(...)` ejecuta `tail` en segundo plano y expone su salida como un archivo; `< <(...)` redirige ese archivo a la entrada del `while`, que ya no es parte de un pipeline.

## Problema 2 – dron con 5 % asignado a un reparto

**Línea del fallo:** línea 34, `if [ "$BATERIA_ACTUAL" > "20" ]; then`

**Qué hace Bash:**
1. Dentro de `[ ... ]` el `>` **no es un operador de comparación**. Bash lo interpreta, antes de ejecutar `[`, como **redirección de la salida estándar** hacia un archivo llamado `20`.
2. Bash crea (o trunca) un archivo vacío `20` en el directorio actual. Se puede comprobar con `ls -la 20`.
3. El comando que realmente se ejecuta es `[ "$BATERIA_ACTUAL" ]` (la redirección se elimina de los argumentos). Con un solo argumento, `[` es una prueba de *cadena no vacía*.
4. `"5"` no está vacía → el test devuelve 0 (verdadero) → entra al `if` y marca el dron como `No` disponible.
5. Resultado: la condición es verdadera para **cualquier** dron que exista, sin importar su batería. El `else` ("Batería insuficiente") nunca se ejecuta.

**Solución:** usar el operador numérico: `[ "$BATERIA_ACTUAL" -gt "20" ]`. (`>` solo compara como texto dentro de `[[ ]]`, y aun así sería una comparación alfabética: `"5" > "20"` daría verdadero.)

## Efectos secundarios detectados
- Cada ejecución de `asignar` deja un archivo vacío `20` en el directorio actual (consecuencia de la redirección).
- El script entregado tiene finales de línea CRLF (Windows). En Linux esto rompe el shebang (`/bin/bash^M`). El `_fix.sh` se entrega con LF.

## Cambios en `don_drones_manager_fix.sh` (solo 3 líneas)
| Línea | Antes | Después |
|---|---|---|
| 16 | `tail -n +2 "$ARCHIVO_FLOTA" \| while IFS=, read -r ...; do` | `while IFS=, read -r ...; do` |
| 20 | `done` | `done < <(tail -n +2 "$ARCHIVO_FLOTA")` |
| 34 | `[ "$BATERIA_ACTUAL" > "20" ]` | `[ "$BATERIA_ACTUAL" -gt "20" ]` |

## Verificación (sobre `flota.csv` provisto)
- `bateria_critica` → antes `0`, ahora `7` (SCO-002 15, CAR-003 8, HEA-002 19, COO-002 12, RAC-002 5, HEA-004 3, RAC-004 18).
- `asignar RAC-002` (5 %) → antes "asignado exitosamente", ahora "Error: Batería insuficiente."
- `asignar COO-003` (88 %) → asignado y pasa a `No`.
- `asignar CAR-004` (ya `No`) → "no está disponible".
