#!/bin/bash
# Don Drones - Sistema de gestion de flota (Parte 1 b). Requiere Bash 4+.

DIR=$(dirname "$0")
ARCHIVO_FLOTA="$DIR/flota.csv"
ARCHIVO_USUARIOS="$DIR/usuarios.csv"   # formato usuario:clave
CATEGORIAS=(Scout Cargo Heavy Cooler Racer)

# Si los archivos no existen se crean (usuario admin por defecto)
[ -f "$ARCHIVO_FLOTA" ] || echo "ID,Categoria,Modelo,Bateria,Disponible" > "$ARCHIVO_FLOTA"
# shortcut: claves en texto plano, aceptable para el obligatorio; en produccion usar hash (sha256sum)
[ -f "$ARCHIVO_USUARIOS" ] || echo "admin:admin" > "$ARCHIVO_USUARIOS"

# ---------- Utilidades ----------

# Imprime la linea del CSV del dron $1; devuelve 1 si el ID es invalido o no existe
buscar_dron() {
    [[ "$1" =~ ^[A-Z]{3}-[0-9]+$ ]] && grep "^$1," "$ARCHIVO_FLOTA"
}

# Formato de salida: CAR-001 - Cargo - SkyHauler X2 - 98% - Disponible
mostrar_dron() {
    local estado="Disponible"
    [ "$5" = "No" ] && estado="No disponible"
    echo "$1 - $2 - $3 - $4% - $estado"
}

# Pide la bateria hasta que sea un entero entre 0 y 100 (resultado en $BATERIA)
leer_bateria() {
    while true; do
        echo -n "Bateria (0-100): "
        read -r BATERIA || exit 1
        if [[ "$BATERIA" =~ ^[0-9]{1,3}$ ]] && [ "$((10#$BATERIA))" -le 100 ]; then
            BATERIA=$((10#$BATERIA))   # normaliza "08" a "8"
            return
        fi
        echo "Error: ingrese un numero entero entre 0 y 100."
    done
}

# Pide Si/No hasta que sea valido (resultado en $DISPONIBLE)
leer_disponible() {
    while true; do
        echo -n "Disponible (Si/No): "
        read -r RESPUESTA || exit 1
        case $RESPUESTA in
            [Ss][Ii]) DISPONIBLE="Si"; return ;;
            [Nn][Oo]) DISPONIBLE="No"; return ;;
            *) echo "Error: responda Si o No." ;;
        esac
    done
}

# Pide un ID, lo pasa a mayusculas y verifica que exista (resultado en $ID y $LINEA)
pedir_dron_existente() {
    echo -n "ID del dron: "
    read -r ID
    ID=${ID^^}
    LINEA=$(buscar_dron "$ID") && return 0
    echo "Error: el dron $ID no existe."
    return 1
}

# ---------- Requisitos 3 a 6 ----------

# ID = 3 primeras letras de la categoria en mayuscula + correlativo (maximo existente + 1)
generar_id() {
    local prefijo=${1^^}
    prefijo=${prefijo:0:3}
    local ultimo
    ultimo=$(grep "^$prefijo-" "$ARCHIVO_FLOTA" | cut -d',' -f1 | cut -d'-' -f2 | sort -n | tail -n 1)
    printf "%s-%03d" "$prefijo" "$((10#${ultimo:-0} + 1))"
}

ingresar_dron() {
    local i opcion modelo categoria id
    echo "Categorias:"
    for i in "${!CATEGORIAS[@]}"; do
        echo "  $((i + 1))) ${CATEGORIAS[$i]}"
    done
    while true; do
        echo -n "Categoria (1-5): "
        read -r opcion || exit 1
        [[ "$opcion" =~ ^[1-5]$ ]] && break
        echo "Error: elija un numero entre 1 y 5."
    done
    categoria=${CATEGORIAS[$((opcion - 1))]}

    while true; do
        echo -n "Modelo: "
        read -r modelo || exit 1
        # la coma romperia el formato CSV
        if [[ "$modelo" =~ ^[[:space:]]*$ ]] || [[ "$modelo" == *,* ]]; then
            echo "Error: el modelo no puede estar vacio ni contener comas."
        else
            break
        fi
    done
    leer_bateria
    leer_disponible

    id=$(generar_id "$categoria")
    echo "$id,$categoria,$modelo,$BATERIA,$DISPONIBLE" >> "$ARCHIVO_FLOTA"
    mostrar_dron "$id" "$categoria" "$modelo" "$BATERIA" "$DISPONIBLE"
}

# Logica de la parte a (corregida): el dron debe estar disponible y tener bateria > 20
asignar_dron() {
    local disponible bateria
    pedir_dron_existente || return
    disponible=$(echo "$LINEA" | cut -d',' -f5)
    if [ "$disponible" != "Si" ]; then
        echo "Error: el dron $ID no esta disponible."
        return
    fi
    bateria=$(echo "$LINEA" | cut -d',' -f4)
    if [ "$bateria" -gt "20" ]; then
        sed -i "s/^$ID,\(.*\),Si$/$ID,\1,No/" "$ARCHIVO_FLOTA"
        echo "Dron $ID asignado exitosamente."
    else
        echo "Error: Bateria insuficiente."
    fi
}

actualizar_dron() {
    pedir_dron_existente || return
    leer_bateria
    leer_disponible
    # \1 y \2 conservan categoria y modelo; solo cambian bateria y disponibilidad
    sed -i "s/^$ID,\([^,]*\),\([^,]*\),[^,]*,[^,]*$/$ID,\1,\2,$BATERIA,$DISPONIBLE/" "$ARCHIVO_FLOTA"
    echo "Dron $ID actualizado."
}

# Logica de la parte a (corregida): el while lee con < <(...) y no con pipe,
# asi el contador sobrevive porque el bucle corre en el shell principal
reporte_flota() {
    local contador=0 lista="" id cat modelo bateria disp
    while IFS=, read -r id cat modelo bateria disp; do
        [ -z "$id" ] && continue
        if [ "$bateria" -lt "20" ]; then
            contador=$((contador + 1))
            lista+="$(mostrar_dron "$id" "$cat" "$modelo" "$bateria" "$disp")"$'\n'
        fi
    done < <(tail -n +2 "$ARCHIVO_FLOTA")
    echo "Drones con bateria critica: $contador"
    echo -n "$lista"
}

# ---------- Requisito 2: usuarios ----------

sign_up() {
    local usuario clave
    echo -n "Nuevo usuario: "
    read -r usuario
    if [[ "$usuario" =~ ^[[:space:]]*$ ]] || [[ "$usuario" == *:* ]]; then
        echo "Error: el usuario no puede estar vacio ni contener ':'."
        return
    fi
    if cut -d':' -f1 "$ARCHIVO_USUARIOS" | grep -qxF -- "$usuario"; then
        echo "Error: el usuario ya existe."
        return
    fi
    echo -n "Contrasena: "
    read -rs clave
    echo
    if [[ "$clave" =~ ^[[:space:]]*$ ]]; then
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
        if [ "$u" = "$usuario" ] && [ "$c" = "$clave" ]; then
            USUARIO_ACTUAL=$usuario
            return 0
        fi
    done < "$ARCHIVO_USUARIOS"
    echo "Error: usuario o contrasena incorrectos."
    return 1
}

# ---------- Menus (requisito 1) ----------

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
        read -r opcion || exit 1
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

menu_sesion() {
    while true; do
        echo
        echo "=== Don Drones - Sesion ==="
        echo "1) Sign Up"
        echo "2) Log In"
        echo "3) Salir"
        echo -n "Opcion: "
        read -r opcion || exit 1
        case $opcion in
            1) sign_up ;;
            2) log_in && menu_principal ;;
            3) echo "Hasta luego."; exit 0 ;;
            *) echo "Opcion no valida." ;;
        esac
    done
}

menu_sesion
