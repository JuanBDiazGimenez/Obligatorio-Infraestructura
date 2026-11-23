# Verifica sobre el log del puerto (con o sin prefijo de docker compose):
#  1) nunca hay dos barcos autorizados a la vez, 2) cada AUTORIZA es seguido por la liberacion del mismo barco,
#  3) se autoriza en el mismo orden en que se solicito (FIFO), 4) hubo competencia (varios barcos esperando).
{
    linea = $0
    sub(/.*\[puerto\] /, "", linea)            # quita el prefijo de docker compose, si lo hay
}
linea ~ /^Barco [0-9]+ solicita acceso/ {
    split(linea, p, " ")
    q[++pedidos] = p[1] " " p[2]
    if (pedidos - atendidos > maxesp) maxesp = pedidos - atendidos
}
linea ~ /^AUTORIZA a Barco/ {
    split(linea, p, " ")
    barco = p[3] " " p[4]
    if (dentro != "")             bad("autorizado " barco " con " dentro " adentro")
    if (q[++atendidos] != barco)  bad("orden no FIFO: " barco " en vez de " q[atendidos])
    dentro = barco; aut++
}
linea ~ /^Barco [0-9]+ libera/ {
    split(linea, p, " ")
    barco = p[1] " " p[2]
    if (dentro != barco) bad("libera " barco " pero adentro estaba [" dentro "]")
    dentro = ""; lib++
}
linea ~ /^conexion perdida/ { dentro = ""; perdidas++ }   # el puerto libero solo porque un barco se cayo
function bad(m) { print "ERROR:", m; err++ }
END {
    if (maxesp < 2) bad("no hubo competencia (max esperando " maxesp ")")
    print err ? "FALLO" : "OK: " aut " autorizaciones, " lib " liberaciones, nunca 2 barcos a la vez, orden FIFO, hasta " maxesp " barcos solicitando a la vez"
}
