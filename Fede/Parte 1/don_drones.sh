#!/bin/bash

# Los datos pertenecen a esta versión, aunque se ejecute desde otra carpeta.
cd -- "$(dirname -- "$0")" || exit 1
ARCHIVO_FLOTA="flota.csv"
ARCHIVO_USUARIOS="usuarios.csv"
USUARIO_ACTUAL=""

leer() {
    printf '%s' "$1"
    if ! IFS= read -r RESPUESTA; then
        printf '\nFin de entrada.\n'
        exit 0
    fi
}

texto_valido() {
    # El formato CSV simple no admite comas ni saltos de línea en campos.
    [[ "$1" =~ [^[:space:]] && "$1" != *,* && "$1" != *$'\r'* ]]
}

pedir_texto() {
    while true; do
        leer "$1"
        if texto_valido "$RESPUESTA"; then
            return
        fi
        echo "Ingresá texto no vacío, sin comas ni retornos de carro."
    done
}

pedir_bateria() {
    while true; do
        leer "Batería (0 a 100): "
        if [[ "$RESPUESTA" =~ ^[0-9]{1,3}$ ]]; then
            BATERIA_NUEVA=$((10#$RESPUESTA))
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
    if printf '%s,%s\n' "$usuario" "$clave" >> "$ARCHIVO_USUARIOS"; then
        echo "Usuario registrado. Ya podés iniciar sesión."
    else
        echo "Error al guardar el usuario."
    fi
}

iniciar_sesion() {
    local usuario clave
    leer "Usuario: "; usuario="$RESPUESTA"
    leer "Contraseña: "; clave="$RESPUESTA"
    if buscar_usuario "$usuario" && [ "$clave" = "$CLAVE_GUARDADA" ]; then
        USUARIO_ACTUAL="$usuario"
        echo "Sesión iniciada: $USUARIO_ACTUAL"
    else
        echo "Usuario o contraseña incorrectos."
    fi
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
    printf '%s - %s - %s - %s%% - %s\n' "$1" "$2" "$3" "$4" "$estado"
}

ingresar_dron() {
    local categoria prefijo modelo mayor=0 numero nuevo_id encabezado
    local id cat mod bat disp
    while true; do
        leer "Categoría (1 Scout, 2 Cargo, 3 Heavy, 4 Cooler, 5 Racer): "
        case "$RESPUESTA" in
            1) categoria="Scout"; prefijo="SCO" ;;
            2) categoria="Cargo"; prefijo="CAR" ;;
            3) categoria="Heavy"; prefijo="HEA" ;;
            4) categoria="Cooler"; prefijo="COO" ;;
            5) categoria="Racer"; prefijo="RAC" ;;
            *) echo "Elegí una categoría entre 1 y 5."; continue ;;
        esac
        break
    done
    pedir_texto "Modelo: "; modelo="$RESPUESTA"
    pedir_bateria
    pedir_disponibilidad
    {
        read -r encabezado
        while IFS=, read -r id cat mod bat disp; do
            if [[ "$id" == "$prefijo-"* ]]; then
                numero="${id#*-}"
                numero=$((10#$numero))
                if [ "$numero" -gt "$mayor" ]; then mayor="$numero"; fi
            fi
        done
    } < "$ARCHIVO_FLOTA"
    printf -v nuevo_id '%s-%03d' "$prefijo" "$((mayor + 1))"
    if printf '%s,%s,%s,%s,%s\n' "$nuevo_id" "$categoria" "$modelo" "$BATERIA_NUEVA" "$DISP_NUEVA" >> "$ARCHIVO_FLOTA"; then
        mostrar_dron "$nuevo_id" "$categoria" "$modelo" "$BATERIA_NUEVA" "$DISP_NUEVA"
    else
        echo "Error al guardar el dron."
    fi
}

guardar_actualizacion() {
    local buscado="$1" bateria="$2" disponible="$3"
    local temporal encabezado id cat modelo bat disp
    temporal=$(mktemp "${ARCHIVO_FLOTA}.XXXXXX") || return 1
    # Se escribe primero una copia completa; el original cambia solo al terminar.
    if {
        IFS= read -r encabezado
        printf '%s\n' "$encabezado"
        while IFS=, read -r id cat modelo bat disp; do
            if [ "$id" = "$buscado" ]; then
                bat="$bateria"; disp="$disponible"
            fi
            printf '%s,%s,%s,%s,%s\n' "$id" "$cat" "$modelo" "$bat" "$disp" || return 1
        done
    } < "$ARCHIVO_FLOTA" > "$temporal"; then
        if mv -- "$temporal" "$ARCHIVO_FLOTA"; then return 0; fi
    fi
    rm -f -- "$temporal"
    return 1
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
    local contador=0 listado="" encabezado id cat modelo bateria disp
    # Igual que en 1.a, el bucle recibe el archivo sin un pipeline.
    {
        read -r encabezado
        while IFS=, read -r id cat modelo bateria disp; do
            if [ "$bateria" -lt 20 ]; then
                contador=$((contador + 1))
                listado+="$(mostrar_dron "$id" "$cat" "$modelo" "$bateria" "$disp")"$'\n'
            fi
        done
    } < "$ARCHIVO_FLOTA"
    echo "Drones con batería crítica: $contador"
    printf '%s' "$listado"
}

if [ ! -f "$ARCHIVO_FLOTA" ]; then
    echo "Falta flota.csv junto al script. Copiá el archivo provisto antes de iniciar."
    exit 1
fi
if [ ! -f "$ARCHIVO_USUARIOS" ]; then
    printf 'admin,admin\n' > "$ARCHIVO_USUARIOS" || exit 1
fi

while true; do
    if [ -z "$USUARIO_ACTUAL" ]; then
        printf '\nDon Drones - Sesión\n1. Registrarse\n2. Iniciar sesión\n3. Salir\n'
        leer "Opción: "
        case "$RESPUESTA" in
            1) registrar ;;
            2) iniciar_sesion ;;
            3) exit 0 ;;
            *) echo "Elegí una opción entre 1 y 3." ;;
        esac
    else
        printf '\nDon Drones - %s\n1. Ingresar dron\n2. Asignar dron a reparto\n3. Actualizar dron\n4. Reporte de flota\n5. Cerrar sesión\n6. Salir\n' "$USUARIO_ACTUAL"
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
