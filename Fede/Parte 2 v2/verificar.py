"""Verificacion local: requiere Linux, GCC y Python 3; no instala dependencias.

python3 verificar.py          # distintas semillas, sin demoras
python3 verificar.py --real   # ademas ejecuta los tiempos de la letra
Las semillas, las trazas y la omision de demoras se aplican solo a copias
temporales. main.c no tiene opciones de prueba y no necesita Python.
"""
from collections import Counter, deque
from pathlib import Path
import re
import subprocess
import sys
import tempfile


INICIO = re.compile(r"Despachador (\d+) inició despacho de paquete (\d+) - prioridad (ALTA|NORMAL) - normales esperando al elegir (\d+) - contador prioridad (\d+)")
FIN = re.compile(r"Despachador (\d+) despachó paquete (\d+) - peso (\d+) - prioridad (ALTA|NORMAL) - costo (\d+)")


def comprobar_despachos(texto):
    """Comprueba los mensajes visibles, también sin trazas internas."""
    activos = {}
    inicios, finales = Counter(), Counter()
    prioridades = {}
    contador = 0
    maximos_activos = 0
    for linea in texto.splitlines():
        if m := INICIO.fullmatch(linea):
            trabajador, numero, prioridad, normales, publicado = m.groups()
            trabajador, numero, normales, publicado = map(int, (trabajador, numero, normales, publicado))
            assert 1 <= trabajador <= 3 and 1 <= numero <= 300
            assert trabajador not in activos and 0 <= normales <= 15
            if prioridad == "ALTA":
                assert contador < 3 or normales == 0, linea
                contador = min(3, contador + 1)
            else:
                assert normales > 0, linea
                contador = 0
            assert publicado == contador, linea
            activos[trabajador] = numero
            prioridades[numero] = prioridad
            inicios[numero] += 1
            maximos_activos = max(maximos_activos, len(activos))
        elif m := FIN.fullmatch(linea):
            trabajador, numero, _, prioridad, _ = m.groups()
            trabajador, numero = int(trabajador), int(numero)
            assert activos.pop(trabajador, None) == numero, linea
            assert prioridades[numero] == prioridad, linea
            finales[numero] += 1
    assert inicios == finales == Counter(range(1, 301)) and not activos
    assert maximos_activos >= 2, "No se observaron despachos superpuestos"
    return maximos_activos


def comprobar(texto):
    capacidades = {"ZONA1": 15, "ZONA2": 15, "PRIORIDAD": 10, "NORMAL": 15}
    colas = {nombre: deque() for nombre in capacidades}
    maximos = dict.fromkeys(capacidades, 0)
    etapas = [Counter() for _ in range(4)]
    pesos = {}
    entradas = {nombre: Counter() for nombre in capacidades}
    salidas = {nombre: Counter() for nombre in capacidades}
    decisiones = deque()
    pendientes_inicio = deque()
    racha = 0
    turnos_normales_forzados = 0
    resumen = False
    for linea in texto.splitlines():
        if linea.startswith("TRAZA ELEGIR "):
            _, _, elegida, p, n, anterior = linea.split()
            p, n, anterior = int(p), int(n), int(anterior)
            assert (p, n, anterior) == (len(colas["PRIORIDAD"]), len(colas["NORMAL"]), racha)
            esperada = "PRIORIDAD" if p > 0 and (n == 0 or racha < 3) else "NORMAL"
            assert elegida == esperada, linea
            if p and n and racha == 3:
                turnos_normales_forzados += 1
            decisiones.append(elegida)
            racha = min(3, racha + 1) if elegida == "PRIORIDAD" else 0
        elif linea.startswith("TRAZA "):
            _, accion, nombre, numero, cantidad = linea.split()
            numero, cantidad = int(numero), int(cantidad)
            assert 1 <= numero <= 300
            cola = colas[nombre]
            if accion == "ENTRA":
                assert len(cola) < capacidades[nombre], linea
                cola.append(numero)
                entradas[nombre][numero] += 1
                if nombre in ("PRIORIDAD", "NORMAL"):
                    assert salidas["ZONA2"][numero] == 1 and etapas[1][numero] == 1, linea
                else:
                    etapa = 0 if nombre == "ZONA1" else 1
                    assert etapas[etapa][numero] == 1, linea
            else:
                assert accion == "SALE" and cola and cola.popleft() == numero, linea
                salidas[nombre][numero] += 1
                if nombre in ("PRIORIDAD", "NORMAL"):
                    assert decisiones.popleft() == nombre
                    pendientes_inicio.append((numero, nombre))
            assert len(cola) == cantidad, linea
            maximos[nombre] = max(maximos[nombre], cantidad)
        elif m := re.fullmatch(r"Receptor (\d+) generó paquete (\d+) con peso (\d+)", linea):
            trabajador, numero, peso = map(int, m.groups())
            assert 1 <= trabajador <= 4 and 1 <= numero <= 300 and 1 <= peso <= 20
            etapas[0][numero] += 1
            pesos[numero] = peso
        elif m := re.fullmatch(r"Escáner (\d+) procesó paquete (\d+)", linea):
            trabajador, numero = map(int, m.groups())
            assert 1 <= trabajador <= 4 and salidas["ZONA1"][numero] == 1
            etapas[1][numero] += 1
        elif m := re.fullmatch(r"Clasificador (\d+) envió paquete (\d+) a cola (PRIORIDAD|NORMAL)", linea):
            trabajador, numero, cola = m.groups()
            trabajador, numero = int(trabajador), int(numero)
            assert 1 <= trabajador <= 4 and salidas["ZONA2"][numero] == 1
            assert cola == ("PRIORIDAD" if pesos[numero] > 10 else "NORMAL")
            etapas[2][numero] += 1
        elif m := INICIO.fullmatch(linea):
            _, numero, prioridad, normales, contador = m.groups()
            numero, normales, contador = int(numero), int(normales), int(contador)
            cola = "PRIORIDAD" if prioridad == "ALTA" else "NORMAL"
            assert pendientes_inicio.popleft() == (numero, cola), linea
            assert normales == len(colas["NORMAL"]) + (cola == "NORMAL"), linea
            assert contador == racha and etapas[2][numero] == 1, linea
        elif m := FIN.fullmatch(linea):
            trabajador, numero, peso, prioridad, costo = m.groups()
            trabajador, numero, peso, costo = map(int, (trabajador, numero, peso, costo))
            assert 1 <= trabajador <= 3 and peso == pesos[numero] and costo == peso * 100
            assert prioridad == ("ALTA" if peso > 10 else "NORMAL")
            cola = "PRIORIDAD" if prioridad == "ALTA" else "NORMAL"
            assert salidas[cola][numero] == 1 and etapas[2][numero] == 1
            etapas[3][numero] += 1
        else:
            assert linea == "Finalizado: 300 paquetes generados y 300 despachados.", linea
            assert etapas[3] == Counter(range(1, 301))
            resumen = True
    esperado = Counter(range(1, 301))
    assert resumen and all(etapa == esperado for etapa in etapas)
    assert all(not cola for cola in colas.values()) and not decisiones
    assert not pendientes_inicio
    assert all(entradas[nombre] == salidas[nombre] for nombre in colas)
    assert entradas["ZONA1"] == entradas["ZONA2"] == esperado
    assert entradas["PRIORIDAD"] + entradas["NORMAL"] == esperado
    comprobar_despachos(texto)
    return maximos, turnos_normales_forzados


def ejecutar(orden, limite=30):
    resultado = subprocess.run(orden, capture_output=True, text=True, encoding="utf-8", timeout=limite)
    assert resultado.returncode == 0, (orden, resultado.returncode, resultado.stderr)
    assert not resultado.stderr, resultado.stderr
    return resultado.stdout


def preparar_copia(origen, destino, semilla=None, trazas=False, sin_demoras=False):
    texto = origen.read_text(encoding="utf-8")
    if semilla is not None:
        texto = texto.replace("srand(time(NULL));", f"srand({semilla});")
    if sin_demoras:
        texto = texto.replace("sleep(segundos);", "sleep(0 * segundos);")
    if trazas:
        texto = texto.replace('    cola->cantidad++;', '    cola->cantidad++;\n    printf("TRAZA ENTRA %s %d %d\\n", cola->nombre, paquete.id, cola->cantidad);')
        texto = texto.replace('    cola->cantidad--;', '    cola->cantidad--;\n    printf("TRAZA SALE %s %d %d\\n", cola->nombre, paquete.id, cola->cantidad);')
        texto = texto.replace('    *paquete = extraer(origen);', '    printf("TRAZA ELEGIR %s %d %d %d\\n", origen->nombre, prioridad.cantidad, normal.cantidad, prioritarios_consecutivos);\n    *paquete = extraer(origen);')
    destino.write_text(texto, encoding="utf-8")


def main():
    origen = Path(__file__).resolve().with_name("main.c")
    with tempfile.TemporaryDirectory(prefix="springfield-") as temporal:
        copia = Path(temporal) / "main.c"
        binario = str(Path(temporal) / "springfield")
        base = ["gcc", "-std=c11", "-Wall", "-Wextra", "-Wpedantic", "-Werror", "-pthread"]
        ejecutar(base + [str(origen.with_name("pruebas_prioridad.c")), "-o", binario])
        print(ejecutar([binario]).strip(), flush=True)
        for semilla in range(1, 13):
            preparar_copia(origen, copia, semilla, trazas=True, sin_demoras=True)
            ejecutar(base + [str(copia), "-o", binario])
            maximos, forzados = comprobar(ejecutar([binario]))
            print(f"Semilla {semilla}: 300 por etapa, FIFO/capacidades/prioridad correctos; máximos={maximos}, turnos normales forzados={forzados}", flush=True)
        preparar_copia(origen, copia, 100, trazas=True, sin_demoras=True)
        ejecutar(base + ["-g", "-fsanitize=address,undefined", "-fno-omit-frame-pointer", str(copia), "-o", binario])
        comprobar(ejecutar([binario]))
        print("AddressSanitizer y UndefinedBehaviorSanitizer: ejecución correcta.", flush=True)
        ejecutar(base + [str(origen), "-o", binario])
        print("Versión normal: compila sin advertencias.", flush=True)
        preparar_copia(origen, copia, sin_demoras=True)
        ejecutar(base + [str(copia), "-o", binario])
        salida = ejecutar([binario])
        activos = comprobar_despachos(salida)
        assert len(salida.splitlines()) == 1501
        print(f"Salida sin trazas: 1501 líneas, 300 pares inicio/fin y hasta {activos} despachos simultáneos.", flush=True)
        if "--real" in sys.argv:
            preparar_copia(origen, copia, trazas=True)
            ejecutar(base + [str(copia), "-o", binario])
            maximos, forzados = comprobar(ejecutar([binario], limite=600))
            print(f"Tiempos reales: correcto; máximos={maximos}, turnos normales forzados={forzados}", flush=True)


if __name__ == "__main__":
    main()
