#!/bin/bash
# Don Drones - Sistema de gestion de flota (Parte 1 b). Requiere Bash 4+.

# INICIO CAMBIO 01: RUTAS RELATIVAS SIN DIRNAME
ARCHIVO_FLOTA="flota.csv"
ARCHIVO_USUARIOS="usuarios.csv"   # formato usuario:clave
# EJECUTAR DESDE LA CARPETA QUE CONTIENE LOS CSV.
# FIN CAMBIO 01
CATEGORIAS=(Scout Cargo Heavy Cooler Racer)

# Si los archivos no existen se crean (usuario admin por defecto)
# INICIO CAMBIO 02: INICIALIZACION DE FLOTA CON IF
if [ ! -f "$ARCHIVO_FLOTA" ]; then
    echo "ID,Categoria,Modelo,Bateria,Disponible" > "$ARCHIVO_FLOTA"
fi
# FIN CAMBIO 02
# shortcut: claves en texto plano, aceptable para el obligatorio; en produccion usar hash (sha256sum)
# INICIO CAMBIO 03: INICIALIZACION DE USUARIOS CON IF
if [ ! -f "$ARCHIVO_USUARIOS" ]; then
    echo "admin:admin" > "$ARCHIVO_USUARIOS"
fi
# FIN CAMBIO 03

# ---------- Utilidades ----------

# Imprime la linea del CSV del dron $1; devuelve 1 si el ID es invalido o no existe
# INICIO CAMBIO 04: VALIDACION DE ID CON GREP E IF
buscar_dron() {
    local coincidencia
    if coincidencia=$(printf '%s\n' "$1" | grep -E '^[A-Z]{3}-[0-9]+$'); then
        grep "^$1," "$ARCHIVO_FLOTA"
    else
        return 1
    fi
}
# FIN CAMBIO 04

# Formato de salida: CAR-001 - Cargo - SkyHauler X2 - 98% - Disponible
mostrar_dron() {
    local estado="Disponible"
# INICIO CAMBIO 21: DISPONIBILIDAD SIN RETORNO DE CARRO EN EL REPORTE
    local disponible
    disponible=$(echo "$5" | sed 's/\r$//')
# FIN CAMBIO 21
# INICIO CAMBIO 05: ESTADO CON IF
    # INICIO CAMBIO 22: COMPARAR LA DISPONIBILIDAD LIMPIA
    if [ "$disponible" = "No" ]; then
    # FIN CAMBIO 22
        estado="No disponible"
    fi
# FIN CAMBIO 05
    echo "$1 - $2 - $3 - $4% - $estado"
}

# Pide la bateria hasta que sea un entero entre 0 y 100 (resultado en $BATERIA)
# INICIO CAMBIO 06: BATERIA CON GREP, IF Y CONVERSION SIN BASE EXPLICITA
leer_bateria() {
    local coincidencia numero
    while true; do
        echo -n "Bateria (0-100): "
        if ! read -r BATERIA; then
            exit 1
        fi
        if coincidencia=$(printf '%s\n' "$BATERIA" | grep -E '^[0-9]{1,3}$'); then
            numero=0
            while [ "$numero" -lt "$BATERIA" ]; do
                numero=$((numero + 1))
            done
            if [ "$numero" -le 100 ]; then
                BATERIA=$numero
                return
            fi
        fi
        echo "Error: ingrese un numero entero entre 0 y 100."
    done
}
# FIN CAMBIO 06

# Pide Si/No hasta que sea valido (resultado en $DISPONIBLE)
leer_disponible() {
    while true; do
        echo -n "Disponible (Si/No): "
# INICIO CAMBIO 07: FIN DE ENTRADA CON IF
        if ! read -r RESPUESTA; then
            exit 1
        fi
# FIN CAMBIO 07
        case $RESPUESTA in
            [Ss][Ii]) DISPONIBLE="Si"; return ;;
            [Nn][Oo]) DISPONIBLE="No"; return ;;
            *) echo "Error: responda Si o No." ;;
        esac
    done
}

# INICIO CAMBIO 08: ID SIN CONVERSION A MAYUSCULAS Y BUSQUEDA CON IF
# Pide un ID y verifica que exista (resultado en $ID y $LINEA)
pedir_dron_existente() {
    echo -n "ID del dron: "
    read -r ID
    if LINEA=$(buscar_dron "$ID"); then
        return 0
    fi
    echo "Error: el dron $ID no existe."
    return 1
}
# FIN CAMBIO 08

# ---------- Requisitos 3 a 6 ----------

# ID = 3 primeras letras de la categoria en mayuscula + correlativo (maximo existente + 1)
# INICIO CAMBIO 09: PREFIJOS CON CASE Y MAYOR CORRELATIVO POR RECORRIDO DEL CSV
generar_id() {
    local prefijo mayor=0 numero encabezado id cat modelo bateria disp sufijo
    case "$1" in
        Scout) prefijo="SCO" ;;
        Cargo) prefijo="CAR" ;;
        Heavy) prefijo="HEA" ;;
        Cooler) prefijo="COO" ;;
        Racer) prefijo="RAC" ;;
    esac
    {
        read -r encabezado
        while IFS=, read -r id cat modelo bateria disp; do
            if [ "$(echo "$id" | cut -d'-' -f1)" = "$prefijo" ]; then
                sufijo=$(echo "$id" | cut -d'-' -f2)
                numero=0
                while [ "$numero" -lt "$sufijo" ]; do
                    numero=$((numero + 1))
                done
                if [ "$numero" -gt "$mayor" ]; then mayor="$numero"; fi
            fi
        done
    } < "$ARCHIVO_FLOTA"
    numero=$mayor
    printf "%s-%03d" "$prefijo" "$((numero + 1))"
}
# FIN CAMBIO 09

ingresar_dron() {
# INICIO CAMBIO 10: VARIABLE LOCAL PARA VALIDACIONES
    local i opcion modelo categoria id coincidencia
# FIN CAMBIO 10
    echo "Categorias:"
    for i in "${!CATEGORIAS[@]}"; do
        echo "  $((i + 1))) ${CATEGORIAS[$i]}"
    done
    while true; do
        echo -n "Categoria (1-5): "
# INICIO CAMBIO 11: CATEGORIA CON GREP E IF
        if ! read -r opcion; then
            exit 1
        fi
        if coincidencia=$(printf '%s\n' "$opcion" | grep -E '^[1-5]$'); then
            break
        fi
# FIN CAMBIO 11
        echo "Error: elija un numero entre 1 y 5."
    done
    categoria=${CATEGORIAS[$((opcion - 1))]}

    while true; do
        echo -n "Modelo: "
# INICIO CAMBIO 12: MODELO CON GREP E IF
        if ! read -r modelo; then
            exit 1
        fi
        # la coma romperia el formato CSV
        if coincidencia=$(printf '%s\n' "$modelo" | grep -E '^[[:space:]]*$'); then
            echo "Error: el modelo no puede estar vacio ni contener comas."
        else
            if coincidencia=$(printf '%s\n' "$modelo" | grep ','); then
                echo "Error: el modelo no puede estar vacio ni contener comas."
            else
                break
            fi
        fi
# FIN CAMBIO 12
    done
    leer_bateria
    leer_disponible

    id=$(generar_id "$categoria")
    echo "$id,$categoria,$modelo,$BATERIA,$DISPONIBLE" >> "$ARCHIVO_FLOTA"
    mostrar_dron "$id" "$categoria" "$modelo" "$BATERIA" "$DISPONIBLE"
}

# Logica de la parte a (corregida): el dron debe estar disponible y tener bateria > 20
# INICIO CAMBIO 13: VERIFICACION DE EXISTENCIA CON IF EN ASIGNAR_DRON
asignar_dron() {
    local disponible bateria
    if ! pedir_dron_existente; then
        return 1
    fi
    disponible=$(echo "$LINEA" | cut -d',' -f5)
    # INICIO CAMBIO 23: DISPONIBILIDAD SIN RETORNO DE CARRO AL ASIGNAR
    disponible=$(echo "$disponible" | sed 's/\r$//')
    # FIN CAMBIO 23
    if [ "$disponible" != "Si" ]; then
        echo "Error: el dron $ID no esta disponible."
        return
    fi
    bateria=$(echo "$LINEA" | cut -d',' -f4)
    if [ "$bateria" -gt "20" ]; then
        # INICIO CAMBIO 24: GUARDAR LA ASIGNACION CON LF O CRLF
        sed -i "s/^$ID,\(.*\),Si\r*$/$ID,\1,No/" "$ARCHIVO_FLOTA"
        # FIN CAMBIO 24
        echo "Dron $ID asignado exitosamente."
    else
        echo "Error: Bateria insuficiente."
    fi
}
# FIN CAMBIO 13

# INICIO CAMBIO 14: VERIFICACION DE EXISTENCIA CON IF EN ACTUALIZAR_DRON
actualizar_dron() {
    if ! pedir_dron_existente; then
        return 1
    fi
    leer_bateria
    leer_disponible
    # \1 y \2 conservan categoria y modelo; solo cambian bateria y disponibilidad
    sed -i "s/^$ID,\([^,]*\),\([^,]*\),[^,]*,[^,]*$/$ID,\1,\2,$BATERIA,$DISPONIBLE/" "$ARCHIVO_FLOTA"
    echo "Dron $ID actualizado."
}
# FIN CAMBIO 14

# INICIO CAMBIO 15: REPORTE EN DOS RECORRIDOS CON REDIRECCION E IF PARA FILAS VACIAS
# Logica de la parte a (corregida): el bloque lee el CSV por redireccion,
# asi el contador se actualiza en el shell principal.
reporte_flota() {
    local contador=0 encabezado id cat modelo bateria disp
    {
        read -r encabezado
        while IFS=, read -r id cat modelo bateria disp; do
            if [ -n "$id" ]; then
                if [ "$bateria" -lt "20" ]; then
                    contador=$((contador + 1))
                fi
            fi
        done
    } < "$ARCHIVO_FLOTA"
    echo "Drones con bateria critica: $contador"
    {
        read -r encabezado
        while IFS=, read -r id cat modelo bateria disp; do
            if [ -n "$id" ]; then
                if [ "$bateria" -lt "20" ]; then
                    mostrar_dron "$id" "$cat" "$modelo" "$bateria" "$disp"
                fi
            fi
        done
    } < "$ARCHIVO_FLOTA"
}
# FIN CAMBIO 15

# ---------- Requisito 2: usuarios ----------

sign_up() {
# INICIO CAMBIO 16: USUARIO CON GREP E IF
    local usuario clave coincidencia
    echo -n "Nuevo usuario: "
    read -r usuario
    if coincidencia=$(printf '%s\n' "$usuario" | grep -E '^[[:space:]]*$'); then
        echo "Error: el usuario no puede estar vacio ni contener ':'."
        return
    fi
    if coincidencia=$(printf '%s\n' "$usuario" | grep ':'); then
        echo "Error: el usuario no puede estar vacio ni contener ':'."
        return
    fi
# FIN CAMBIO 16
    if cut -d':' -f1 "$ARCHIVO_USUARIOS" | grep -qxF -- "$usuario"; then
        echo "Error: el usuario ya existe."
        return
    fi
    echo -n "Contrasena: "
    read -rs clave
    echo
# INICIO CAMBIO 17: CLAVE CON GREP
    if coincidencia=$(printf '%s\n' "$clave" | grep -E '^[[:space:]]*$'); then
# FIN CAMBIO 17
        echo "Error: la contrasena no puede estar en blanco."
        return
    fi
    echo "$usuario:$clave" >> "$ARCHIVO_USUARIOS"
    echo "Usuario $usuario registrado. Ahora puede iniciar sesion."
}

# Devuelve 0 si usuario y clave coinciden (sin pipe: no hay subshell)
log_in() {
    local usuario clave u c
    echo -n "Usuario: "
    read -r usuario
    echo -n "Contrasena: "
    read -rs clave
    echo
    while IFS=: read -r u c; do
# INICIO CAMBIO 18: LOGIN CON CONDICIONALES ANIDADOS
        if [ "$u" = "$usuario" ]; then
            if [ "$c" = "$clave" ]; then
                USUARIO_ACTUAL=$usuario
                return 0
            fi
        fi
# FIN CAMBIO 18
    done < "$ARCHIVO_USUARIOS"
    echo "Error: usuario o contrasena incorrectos."
    return 1
}

# ---------- Menus (requisito 1) ----------

# INICIO CAMBIO 19: CONDICIONALES EN MENU_PRINCIPAL
menu_principal() {
    while true; do
        echo
        echo "=== Don Drones - Menu principal (usuario: $USUARIO_ACTUAL) ==="
        echo "1) Ingresar dron"
        echo "2) Asignar dron a reparto"
        echo "3) Actualizar dron"
        echo "4) Reporte de estado de flota"
        echo "5) Log Out"
        echo "6) Salir"
        echo -n "Opcion: "
        if ! read -r opcion; then
            exit 1
        fi
        case $opcion in
            1) ingresar_dron ;;
            2) asignar_dron ;;
            3) actualizar_dron ;;
            4) reporte_flota ;;
            5) USUARIO_ACTUAL=""; echo "Sesion cerrada."; return ;;
            6) echo "Hasta luego."; exit 0 ;;
            *) echo "Opcion no valida." ;;
        esac
    done
}
# FIN CAMBIO 19

# INICIO CAMBIO 20: CONDICIONALES EN MENU_SESION
menu_sesion() {
    while true; do
        echo
        echo "=== Don Drones - Sesion ==="
        echo "1) Sign Up"
        echo "2) Log In"
        echo "3) Salir"
        echo -n "Opcion: "
        if ! read -r opcion; then
            exit 1
        fi
        case $opcion in
            1) sign_up ;;
            2)
                if log_in; then
                    menu_principal
                fi
                ;;
            3) echo "Hasta luego."; exit 0 ;;
            *) echo "Opcion no valida." ;;
        esac
    done
}
# FIN CAMBIO 20

menu_sesion
