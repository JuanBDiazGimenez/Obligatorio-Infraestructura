"""Ejecutar dentro de mi_ubuntu, en la carpeta de la prueba, con Redis iniciado."""
from pathlib import Path
import subprocess
import time
import re

CARPETA = Path(__file__).resolve().parent


def ejecutar(*args):
    r = subprocess.run(args, cwd=CARPETA, capture_output=True, text=True, timeout=20)
    assert r.returncode == 0, (args, r.stdout, r.stderr)
    return r.stdout


def main():
    for nombre in ['emisor', 'receptor']:
        ejecutar('gnatmake', '-f', '-gnat2012', '-gnatwa', '-gnatwe', '-gnata', nombre + '.adb')
    # Solo se borra la cola exclusiva de esta prueba, no otros datos de Redis.
    ejecutar('redis-cli', '-h', 'infra-test-redis-ada', '-p', '6739', 'DEL',
             'infra:test:redis_ada:mensajes')

    def consultas_lpop():
        info = ejecutar('redis-cli', '-h', 'infra-test-redis-ada', '-p', '6739',
                        'INFO', 'commandstats')
        coincidencia = re.search(r'cmdstat_lpop:calls=(\d+)', info)
        return int(coincidencia[1]) if coincidencia else 0

    consultas_iniciales = consultas_lpop()

    receptor = subprocess.Popen(['./receptor'], cwd=CARPETA, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True)
    try:
        time.sleep(1)
        assert receptor.poll() is None, 'El receptor no espero la llegada del mensaje'
        assert consultas_lpop() - consultas_iniciales >= 2, 'No se observaron consultas LPOP periodicas'
        ejecutar('./emisor', 'hola desde otro proceso Ada')
        salida, errores = receptor.communicate(timeout=15)
        assert receptor.returncode == 0 and not errores, errores
        assert 'Recibido: hola desde otro proceso Ada' in salida, salida
    finally:
        if receptor.poll() is None:
            receptor.kill()
            receptor.communicate()
    print('OK: consultas LPOP periodicas, receptor esperando y mensaje recibido desde otro proceso Ada.', flush=True)

    mensajes = ['primero', 'segundo con espacios', 'literal ; $(echo NO_EJECUTAR)']
    for mensaje in mensajes:
        ejecutar('./emisor', mensaje)
    for mensaje in mensajes:
        salida = ejecutar('./receptor')
        assert 'Recibido: ' + mensaje in salida, salida
    print('OK: FIFO, espacios y caracteres de shell transmitidos como texto.', flush=True)

    inicio = time.monotonic()
    r = subprocess.run(['./receptor'], cwd=CARPETA, capture_output=True, text=True, timeout=20)
    assert 9.8 <= time.monotonic() - inicio < 20
    assert r.returncode != 0 and 'TIEMPO_AGOTADO' in r.stderr.upper(), (r.stdout, r.stderr)
    print('OK: cola vacia termina con Tiempo_Agotado tras diez segundos.', flush=True)
    assert ejecutar('redis-cli', '-h', 'infra-test-redis-ada', '-p', '6739', 'LLEN',
                    'infra:test:redis_ada:mensajes').strip() == '0'
    print('PRUEBA COMPLETA: ningun archivo utilizado para intercambiar mensajes.', flush=True)


if __name__ == '__main__':
    main()
