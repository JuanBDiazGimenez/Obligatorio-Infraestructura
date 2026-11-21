# Parte 1 a) – Informe de diagnóstico: `don_drones_manager.sh`

## Problema 1 – «0 drones con batería crítica»

**Línea del fallo:** en el script original, la línea 16:

```bash
tail -n +2 "$ARCHIVO_FLOTA" | while IFS=, read -r ID CAT MODELO BATERIA DISP; do
```

El contador se incrementa dentro del `while`, pero al finalizar se imprime `0`.

### Qué hace Bash

1. `CONTADOR=0` inicializa la variable en el shell principal.
2. El operador `|` conecta la salida de `tail` con la entrada del `while`. En este caso, el `while` se ejecuta en un **subshell**, con una copia de las variables del shell principal.
3. Cuando encuentra un dron con batería menor a 20, `CONTADOR=$((CONTADOR + 1))` incrementa el contador **dentro del subshell**. Con el CSV proporcionado, allí llega a 7.
4. Al terminar el `while`, esos cambios no se trasladan al shell principal.
5. Por eso, el `echo` posterior utiliza el `CONTADOR` original, que sigue valiendo `0`.

La comparación `[ "$BATERIA" -lt "20" ]` es correcta; el problema está en el contexto en el que se actualiza la variable.

### Solución implementada

Se eliminó el pipeline y se hizo que el bloque de lectura reciba directamente el archivo CSV mediante una redirección de entrada:

```bash
bateria_critica)
    CONTADOR=0
    {
        read -r LINEA
        while IFS=, read -r ID CAT MODELO BATERIA DISP; do
            if [ "$BATERIA" -lt "20" ]; then
                CONTADOR=$((CONTADOR + 1))
            fi
        done
    } < "$ARCHIVO_FLOTA"
    echo "Drones con batería crítica: $CONTADOR"
    ;;
```

- `{ ...; }` agrupa las instrucciones para que compartan la misma entrada estándar, sin crear un subshell por sí mismo.
- `< "$ARCHIVO_FLOTA"` redirige el contenido del CSV a ese bloque.
- `read -r LINEA` consume la primera línea, correspondiente al encabezado. `LINEA` es solamente el nombre de una variable.
- El `while` procesa las filas restantes y actualiza `CONTADOR` en el shell principal, por lo que el valor se conserva al llegar al `echo`.

### Cambios realizados

- Se reemplazó `tail -n +2 "$ARCHIVO_FLOTA" | while ...` por un bloque `{ ...; }` con redirección de entrada desde `"$ARCHIVO_FLOTA"`.
- Se agregó `read -r LINEA` para omitir el encabezado sin usar `tail`.
- Se mantuvieron la condición de batería crítica y el incremento del contador.

### Verificación

Al ejecutar:

```bash
bash don_drones_manager_fix.sh bateria_critica
```

con el archivo `flota.csv` provisto, el resultado fue:

```text
Drones con batería crítica: 7
```

El resultado coincide con los siete drones con batería menor a 20 identificados en el archivo.
