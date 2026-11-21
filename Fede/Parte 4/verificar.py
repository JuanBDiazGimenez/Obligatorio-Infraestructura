"""Ejecutar en el equipo con Python 3 y Docker; antes: docker compose up -d --build.
Solo opera sobre el proyecto atracadero de esta carpeta. Guarda evidencia y lo
detiene al terminar. No requiere IA ni instala paquetes Python.
"""
from collections import Counter, deque
from pathlib import Path
import subprocess
import time

CARPETA = Path(__file__).resolve().parent


def compose(*args):
    r = subprocess.run(['docker', 'compose', *args], cwd=CARPETA,
                       capture_output=True, text=True, encoding='utf-8', timeout=60)
    if r.returncode:
        raise RuntimeError(r.stdout + r.stderr)
    return r.stdout


def redis(*args):
    return compose('exec', '-T', 'redis', 'redis-cli', '-p', '6739', '--raw', *args).strip()


def log_coordinador():
    return compose('logs', '--no-color', '--no-log-prefix', 'coordinador')


def comprobar(texto):
    pendientes = deque()
    ocupante = None
    solicitudes, permisos, liberaciones = Counter(), Counter(), Counter()
    maximo = 0
    listo = False
    for linea in texto.splitlines():
        if linea == 'PUERTO LISTO':
            assert not listo, 'El Coordinador se reinicio durante la prueba'
            listo = True
            continue
        accion, valor = linea.split()
        barco = int(valor)
        assert listo and 1 <= barco <= 3
        if accion == 'SOLICITUD':
            assert barco != ocupante and barco not in pendientes
            solicitudes[barco] += 1
            pendientes.append(barco)
            maximo = max(maximo, len(pendientes))
        elif accion == 'AUTORIZACION':
            assert ocupante is None, 'Dos barcos autorizados simultaneamente'
            assert pendientes.popleft() == barco, 'No se respeto FIFO'
            ocupante = barco
            permisos[barco] += 1
        else:
            assert accion == 'LIBERACION' and ocupante == barco
            ocupante = None
            liberaciones[barco] += 1
    return solicitudes, permisos, liberaciones, maximo


def esperar_condicion(condicion):
    limite = time.monotonic() + 120
    while time.monotonic() < limite:
        if condicion():
            return
        time.sleep(1)
    raise AssertionError('No se completo el escenario en 120 segundos')


def main():
    evidencia = CARPETA / 'evidencia'
    evidencia.mkdir(exist_ok=True)
    try:
        # Simulacion real: tres programas Ada en tres contenedores distintos.
        def completos():
            _, _, liberaciones, _ = comprobar(log_coordinador())
            return all(liberaciones[i] >= 3 for i in (1, 2, 3))
        esperar_condicion(completos)
        texto = log_coordinador()
        comprobar(texto)
        (evidencia / 'simulacion_coordinador.txt').write_text(texto, encoding='utf-8')
        for i in (1, 2, 3):
            texto_barco = compose('logs', '--no-color', '--no-log-prefix', f'barco{i}')
            assert texto_barco.count(f'BARCO {i} ENTRA') >= 3
            assert texto_barco.count(f'BARCO {i} SALE') >= 3
            assert 'raised ' not in texto_barco
            (evidencia / f'simulacion_barco{i}.txt').write_text(texto_barco, encoding='utf-8')
        print('OK: tres ciclos por barco, FIFO y ninguna autorizacion superpuesta.', flush=True)

        # Proyecto nuevo y limpio; no se reinicia el arbitro con barcos activos.
        compose('down')
        compose('up', '-d', '--pull', 'never', 'redis')
        esperar_condicion(lambda: redis('PING') == 'PONG')
        redis('RPUSH', 'puerto:permiso:1', 'AUTORIZADO')
        redis('RPUSH', 'puerto:eventos', 'SOLICITAR 1')
        compose('up', '-d', '--pull', 'never', 'coordinador')
        esperar_condicion(lambda: redis('GET', 'puerto:listo') == '1')
        assert redis('LLEN', 'puerto:permiso:1') == redis('LLEN', 'puerto:eventos') == '0'
        print('OK: el inicio descarta mensajes anteriores antes de admitir barcos.', flush=True)
        # Inyectar tres eventos juntos como fixture, sin ejecutar los barcos.
        redis('RPUSH', 'puerto:eventos', 'SOLICITAR 2', 'SOLICITAR 3', 'SOLICITAR 1')
        esperar_condicion(lambda: len(log_coordinador().splitlines()) >= 5)
        assert redis('LRANGE', 'puerto:permiso:2', '0', '-1') == 'AUTORIZADO'
        assert redis('LLEN', 'puerto:permiso:3') == redis('LLEN', 'puerto:permiso:1') == '0'
        for ocupante, siguiente in [(2, 3), (3, 1), (1, None)]:
            assert redis('LPOP', f'puerto:permiso:{ocupante}') == 'AUTORIZADO'
            redis('RPUSH', 'puerto:eventos', f'LIBERAR {ocupante}')
            if siguiente is not None:
                esperar_condicion(lambda: redis('LLEN', f'puerto:permiso:{siguiente}') == '1')
        esperar_condicion(lambda: log_coordinador().count('LIBERACION') == 3)
        dirigido = log_coordinador()
        comprobar(dirigido)
        assert [l for l in dirigido.splitlines() if l.startswith('AUTORIZACION')] == [
            'AUTORIZACION 2', 'AUTORIZACION 3', 'AUTORIZACION 1']
        (evidencia / 'solicitudes_juntas.txt').write_text(dirigido, encoding='utf-8')
        print('OK: solicitudes juntas 2,3,1; permisos uno por uno en ese orden.', flush=True)
    finally:
        compose('down')
    print('PRUEBA COMPLETA; servicios del proyecto detenidos y retirados.', flush=True)


if __name__ == '__main__':
    main()
