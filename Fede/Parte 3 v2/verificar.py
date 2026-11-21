"""Pruebas del torneo: ejecutar con python3 verificar.py en Linux con GNAT.

Compila copias temporales con comprobaciones activas. La simulación no requiere
Python. Las variantes rápidas modifican solo la unidad temporal en esas copias;
las variantes sin azar cambian exclusivamente las dos funciones de elección.
"""
from pathlib import Path
import re
import subprocess
import tempfile


def comprobar(texto, duracion_fija=None, ganador_fijo=None):
    estados = {i: "libre" for i in range(1, 4)}
    asignados, finales, recibidos = {}, {}, {}
    ocupadas = {}
    jugando = set()
    maximo = 0
    tiempos = set()
    anuncio = False
    for linea in texto.splitlines():
        if m := re.fullmatch(r"Cancha (\d+) solicita un partido\.", linea):
            cancha = int(m[1])
            assert estados[cancha] == "libre", linea
            estados[cancha] = "solicitando"
        elif m := re.fullmatch(r"Coordinador: Partido (\d+) asignado a Cancha (\d+)\. Pareja (\d+) vs Pareja (\d+)\.", linea):
            numero, cancha, a, b = map(int, m.groups())
            assert estados[cancha] == "solicitando" and numero not in asignados
            assert 1 <= numero <= 8 and (a, b) == (2 * numero - 1, 2 * numero)
            assert cancha not in ocupadas
            asignados[numero] = (cancha, a, b)
            ocupadas[cancha] = numero
            estados[cancha] = "asignada"
        elif m := re.fullmatch(r"Cancha (\d+) disputa Partido (\d+) durante (\d+) segundos\.", linea):
            cancha, numero, segundos = map(int, m.groups())
            assert estados[cancha] == "asignada" and ocupadas[cancha] == numero
            assert 0 <= segundos <= 4
            if duracion_fija is not None:
                assert segundos == duracion_fija
            estados[cancha] = "jugando"
            jugando.add(cancha)
            tiempos.add(segundos)
            maximo = max(maximo, len(jugando))
            assert maximo <= 3
        elif m := re.fullmatch(r"Cancha (\d+) finalizó Partido (\d+)\. Ganador: Pareja (\d+)\.", linea):
            cancha, numero, ganador = map(int, m.groups())
            assert estados[cancha] == "jugando" and ocupadas[cancha] == numero
            assert numero not in finales
            _, a, b = asignados[numero]
            assert ganador in (a, b)
            if ganador_fijo is not None:
                assert ganador == (a if ganador_fijo == "A" else b)
            finales[numero] = ganador
            jugando.remove(cancha)
            estados[cancha] = "informando"
        elif m := re.fullmatch(r"Coordinador recibió resultado de Cancha (\d+): Partido (\d+), ganador Pareja (\d+)\.", linea):
            cancha, numero, ganador = map(int, m.groups())
            assert estados[cancha] == "informando" and ocupadas.pop(cancha) == numero
            assert numero not in recibidos and finales[numero] == ganador
            recibidos[numero] = ganador
            estados[cancha] = "libre"
        elif m := re.fullmatch(r"Coordinador: sin partidos pendientes para Cancha (\d+)\.", linea):
            cancha = int(m[1])
            assert estados[cancha] == "solicitando" and len(asignados) == 8
            assert cancha not in ocupadas
            estados[cancha] = "cerrando"
        elif m := re.fullmatch(r"Cancha (\d+) termina su ejecución\.", linea):
            cancha = int(m[1])
            assert estados[cancha] == "cerrando"
            estados[cancha] = "cerrada"
        elif linea == "Todos los partidos han finalizado.":
            assert not anuncio and len(recibidos) == 8 and not ocupadas
            assert all(e in ("cerrando", "cerrada") for e in estados.values())
            anuncio = True
        else:
            assert linea == "Torneo terminado." and anuncio, linea
            assert all(e == "cerrada" for e in estados.values())
    assert texto.splitlines()[-1] == "Torneo terminado."
    assert set(asignados) == set(finales) == set(recibidos) == set(range(1, 9))
    assert all(e == "cerrada" for e in estados.values()) and not jugando
    return maximo, tiempos, tuple(asignados[n][0] for n in range(1, 9))


def compilar(carpeta, fuente):
    (carpeta / "torneo.adb").write_text(fuente, encoding="utf-8")
    resultado = subprocess.run(
        ["gnatmake", "-q", "-f", "-gnat2012", "-gnatwa", "-gnatwe", "-gnata", "-gnato", "torneo.adb"],
        cwd=carpeta, capture_output=True, text=True,
    )
    assert resultado.returncode == 0, resultado.stderr
    assert not resultado.stderr, resultado.stderr


def ejecutar(carpeta):
    resultado = subprocess.run([str(carpeta / "torneo")], capture_output=True,
                              text=True, encoding="utf-8", timeout=45)
    assert resultado.returncode == 0 and not resultado.stderr, resultado.stderr
    return resultado.stdout


def main():
    fuente = Path(__file__).with_name("torneo.adb").read_text(encoding="utf-8")
    unidad = "Unidad_Tiempo  : constant Duration := 1.0;"
    assert fuente.count(unidad) == 1
    rapida = fuente.replace(unidad, "Unidad_Tiempo  : constant Duration := 0.01;")
    with tempfile.TemporaryDirectory(prefix="padel-pruebas-") as temporal:
        carpeta = Path(temporal)
        compilar(carpeta, rapida)
        ordenes, duraciones, maximo = set(), set(), 0
        for _ in range(20):
            activos, tiempos, orden = comprobar(ejecutar(carpeta))
            ordenes.add(orden)
            duraciones.update(tiempos)
            maximo = max(maximo, activos)
        print(f"20 ejecuciones rápidas: correctas. Hasta {maximo} canchas jugando, {len(ordenes)} distribuciones de partidos, duraciones observadas {sorted(duraciones)}.", flush=True)

        for segundos, ganador in [(0, "A"), (4, "B")]:
            # Variantes de defensa: solo se sustituyen las funciones auxiliares.
            variante, cambios = re.subn(
                r"   function Elegir_Duracion\n.*?   end Elegir_Duracion;",
                "   function Elegir_Duracion\n"
                "     (Generador : Azar_Duracion.Generator) return Segundos\n"
                "   is\n      pragma Unreferenced (Generador);\n   begin\n"
                f"      return {segundos};\n   end Elegir_Duracion;", rapida, flags=re.S)
            assert cambios == 1
            variante, cambios = re.subn(
                r"   function Elegir_Ganador\n.*?   end Elegir_Ganador;",
                "   function Elegir_Ganador\n"
                "     (Encuentro : Partido; Generador : Azar_Ganador.Generator) return Id_Pareja\n"
                "   is\n      pragma Unreferenced (Generador);\n   begin\n"
                f"      return Encuentro.Pareja_{ganador};\n   end Elegir_Ganador;", variante, flags=re.S)
            assert cambios == 1
            compilar(carpeta, variante)
            comprobar(ejecutar(carpeta), segundos, ganador)
            print(f"Variante sin azar: duración {segundos}, ganador siempre pareja {ganador}: correcta, sin cambiar tasks ni citas.", flush=True)

        compilar(carpeta, fuente)
        for i in range(2):
            activos, tiempos, _ = comprobar(ejecutar(carpeta))
            print(f"Ejecución real {i + 1}: ocho resultados únicos, tres canchas cerradas, hasta {activos} jugando; duraciones {sorted(tiempos)}.", flush=True)


if __name__ == "__main__":
    main()
