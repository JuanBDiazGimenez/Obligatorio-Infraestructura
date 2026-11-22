#!/bin/bash

# Ejecutar desde esta carpeta: los CSV se buscan mediante rutas relativas.
ARCHIVO_FLOTA="flota.csv"
ARCHIVO_USUARIOS="usuarios.csv"
USUARIO_ACTUAL=""

leer() {
    echo -n "$1"
    if ! IFS= read -r RESPUESTA; then
        echo
        echo "Fin de entrada."
        exit 0
    fi
}

texto_valido() {
    # El formato CSV simple no admite comas ni saltos de línea en campos.
    if ! COINCIDENCIA_TEXTO=$(echo "$1" | grep -E '[^[:space:]]'); then
        return 1
    fi
    if COINCIDENCIA_TEXTO=$(echo "$1" | grep ','); then
        return 1
    fi
    return 0
}

pedir_texto() {
    while true; do
        leer "$1"
        if texto_valido "$RESPUESTA"; then
            return
        fi
        echo "Ingresá texto no vacío, sin comas."
    done
}

pedir_bateria() {
    while true; do
        leer "Batería (0 a 100): "
        if COINCIDENCIA_BATERIA=$(echo "$RESPUESTA" | grep -E '^[0-9]{1,3}$'); then
            BATERIA_NUEVA=0
            while [ "$BATERIA_NUEVA" -lt "$RESPUESTA" ]; do
                BATERIA_NUEVA=$((BATERIA_NUEVA + 1))
            done
            if [ "$BATERIA_NUEVA" -le 100 ]; then
                return
            fi
        fi
        echo "Ingresá un número entero entre 0 y 100."
    done
}

pedir_disponibilidad() {
    while true; do
        leer "Disponible (Si/No): "
        case "$RESPUESTA" in
            Si|si|SI) DISP_NUEVA="Si"; return ;;
            No|no|NO) DISP_NUEVA="No"; return ;;
            *) echo "Ingresá Si o No." ;;
        esac
    done
}

buscar_usuario() {
    local nombre clave
    while IFS=, read -r nombre clave; do
        if [ "$nombre" = "$1" ]; then
            CLAVE_GUARDADA="$clave"
            return 0
        fi
    done < "$ARCHIVO_USUARIOS"
    return 1
}

registrar() {
    local usuario clave
    pedir_texto "Nuevo usuario: "; usuario="$RESPUESTA"
    if buscar_usuario "$usuario"; then
        echo "Ese usuario ya existe. Elegí otro nombre."
        return
    fi
    pedir_texto "Nueva contraseña: "; clave="$RESPUESTA"
    if echo "$usuario,$clave" >> "$ARCHIVO_USUARIOS"; then
        echo "Usuario registrado. Ya podés iniciar sesión."
    else
        echo "Error al guardar el usuario."
    fi
}

iniciar_sesion() {
    local usuario clave
    leer "Usuario: "; usuario="$RESPUESTA"
    leer "Contraseña: "; clave="$RESPUESTA"
    if buscar_usuario "$usuario"; then
        if [ "$clave" = "$CLAVE_GUARDADA" ]; then
            USUARIO_ACTUAL="$usuario"
            echo "Sesión iniciada: $USUARIO_ACTUAL"
            return
        fi
    fi
    echo "Usuario o contraseña incorrectos."
}

buscar_dron() {
    local encabezado
    {
        read -r encabezado
        while IFS=, read -r ID CAT MODELO BATERIA DISP; do
            if [ "$ID" = "$1" ]; then
                return 0
            fi
        done
    } < "$ARCHIVO_FLOTA"
    return 1
}

mostrar_dron() {
    local estado="No disponible"
    if [ "$5" = "Si" ]; then estado="Disponible"; fi
    echo "$1 - $2 - $3 - $4% - $estado"
}

ingresar_dron() {
    local categoria prefijo modelo mayor=0 numero nuevo_id encabezado
    local id cat mod bat disp sufijo
    local categoria_valida=0
    while [ "$categoria_valida" -eq 0 ]; do
        leer "Categoría (1 Scout, 2 Cargo, 3 Heavy, 4 Cooler, 5 Racer): "
        case "$RESPUESTA" in
            1) categoria="Scout"; prefijo="SCO"; categoria_valida=1 ;;
            2) categoria="Cargo"; prefijo="CAR"; categoria_valida=1 ;;
            3) categoria="Heavy"; prefijo="HEA"; categoria_valida=1 ;;
            4) categoria="Cooler"; prefijo="COO"; categoria_valida=1 ;;
            5) categoria="Racer"; prefijo="RAC"; categoria_valida=1 ;;
            *) echo "Elegí una categoría entre 1 y 5." ;;
        esac
    done
    pedir_texto "Modelo: "; modelo="$RESPUESTA"
    pedir_bateria
    pedir_disponibilidad
    {
        read -r encabezado
        while IFS=, read -r id cat mod bat disp; do
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
    numero=$((mayor + 1))
    if [ "$numero" -lt 10 ]; then
        nuevo_id="$prefijo-00$numero"
    elif [ "$numero" -lt 100 ]; then
        nuevo_id="$prefijo-0$numero"
    else
        nuevo_id="$prefijo-$numero"
    fi
    if echo "$nuevo_id,$categoria,$modelo,$BATERIA_NUEVA,$DISP_NUEVA" >> "$ARCHIVO_FLOTA"; then
        mostrar_dron "$nuevo_id" "$categoria" "$modelo" "$BATERIA_NUEVA" "$DISP_NUEVA"
    else
        echo "Error al guardar el dron."
    fi
}

guardar_actualizacion() {
    local buscado="$1" bateria="$2" disponible="$3"
    # Conserva categoria y modelo, y sustituye bateria y disponibilidad.
    sed -i "s/^$buscado,\([^,]*\),\([^,]*\),[^,]*,[^,]*$/$buscado,\1,\2,$bateria,$disponible/" "$ARCHIVO_FLOTA"
}

asignar_dron() {
    leer "ID del dron: "
    if ! buscar_dron "$RESPUESTA"; then
        echo "El dron no existe. Revisá el ID."
        return
    fi
    if [ "$DISP" != "Si" ]; then
        echo "Error: el dron $ID no está disponible."
    elif [ "$BATERIA" -gt 20 ]; then
        if guardar_actualizacion "$ID" "$BATERIA" "No"; then
            echo "Dron $ID asignado exitosamente."
        else
            echo "Error al guardar la asignación."
        fi
    else
        echo "Error: batería insuficiente. Se requiere más de 20%."
    fi
}

actualizar_dron() {
    leer "ID del dron: "
    if ! buscar_dron "$RESPUESTA"; then
        echo "El dron no existe. Revisá el ID."
        return
    fi
    pedir_bateria
    pedir_disponibilidad
    if guardar_actualizacion "$ID" "$BATERIA_NUEVA" "$DISP_NUEVA"; then
        echo "Dron $ID actualizado."
    else
        echo "Error al guardar la actualización."
    fi
}

reporte_flota() {
    local contador=0 encabezado id cat modelo bateria disp
    # Primero se cuenta y despues se vuelve a recorrer para mostrar el detalle.
    {
        read -r encabezado
        while IFS=, read -r id cat modelo bateria disp; do
            if [ "$bateria" -lt 20 ]; then
                contador=$((contador + 1))
            fi
        done
    } < "$ARCHIVO_FLOTA"
    echo "Drones con batería crítica: $contador"
    {
        read -r encabezado
        while IFS=, read -r id cat modelo bateria disp; do
            if [ "$bateria" -lt 20 ]; then
                mostrar_dron "$id" "$cat" "$modelo" "$bateria" "$disp"
            fi
        done
    } < "$ARCHIVO_FLOTA"
}

if [ ! -f "$ARCHIVO_FLOTA" ]; then
    echo "Falta flota.csv en la carpeta actual. Entrá a la carpeta del script antes de iniciar."
    exit 1
fi
if [ ! -f "$ARCHIVO_USUARIOS" ]; then
    if ! echo "admin,admin" > "$ARCHIVO_USUARIOS"; then
        exit 1
    fi
fi

while true; do
    if [ -z "$USUARIO_ACTUAL" ]; then
        echo
        echo "Don Drones - Sesión"
        echo "1. Registrarse"
        echo "2. Iniciar sesión"
        echo "3. Salir"
        leer "Opción: "
        case "$RESPUESTA" in
            1) registrar ;;
            2) iniciar_sesion ;;
            3) exit 0 ;;
            *) echo "Elegí una opción entre 1 y 3." ;;
        esac
    else
        echo
        echo "Don Drones - $USUARIO_ACTUAL"
        echo "1. Ingresar dron"
        echo "2. Asignar dron a reparto"
        echo "3. Actualizar dron"
        echo "4. Reporte de flota"
        echo "5. Cerrar sesión"
        echo "6. Salir"
        leer "Opción: "
        case "$RESPUESTA" in
            1) ingresar_dron ;;
            2) asignar_dron ;;
            3) actualizar_dron ;;
            4) reporte_flota ;;
            5) USUARIO_ACTUAL=""; echo "Sesión cerrada." ;;
            6) exit 0 ;;
            *) echo "Elegí una opción entre 1 y 6." ;;
        esac
    fi
done
