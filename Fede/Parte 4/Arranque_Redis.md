# Preparación y arranque con Redis

Esta nota explica una decisión de la solución: coordinar la preparación del coordinador con el inicio de los barcos. Los comandos descritos pertenecen a Redis; su combinación con Ada y Compose es una adaptación propia al requisito de la parte 4, no un ejemplo docente.

## Secuencia actual

1. Compose arranca Redis y espera que responda a `PING`.
2. Arranca el coordinador, que llama a `Preparar` antes de recibir solicitudes.
3. `Preparar` usa `DEL` para borrar `puerto:listo`, la cola `puerto:eventos` y los tres buzones `puerto:permiso:1`, `puerto:permiso:2` y `puerto:permiso:3`. Solo toca estas claves de la simulación.
4. Al terminar, ejecuta `SET puerto:listo 1` para publicar una marca de preparación completada.
5. El `healthcheck` del servicio coordinador, definido en `docker-compose.yml`, consulta `GET puerto:listo`. Cuando obtiene `1`, Compose permite arrancar los barcos mediante `depends_on` con `condition: service_healthy`.

`DEL` elimina una clave y su contenido; `SET` guarda un valor de texto asociado a una clave; `GET` consulta ese valor. El nombre `puerto:listo` lo elegimos nosotros: no es una función especial de Redis.

## Por qué se conserva

Esperar solamente a que Redis responda no garantiza que el coordinador haya terminado de preparar sus colas. Si los barcos enviaran solicitudes antes de esa limpieza, el coordinador podría borrarlas. La marca ordena el arranque conjunto previsto y evita esa superposición.

`puerto:listo` no autoriza a ocupar el atracadero. Esa autorización se sigue enviando por el buzón individual de cada barco, después de reservar el lugar. Tampoco es una supervisión permanente del coordinador ni un mecanismo de recuperación ante reinicios aislados durante la simulación. No se agregan esos requisitos.

Fede indicó mantener y documentar este mecanismo como parte del uso de Redis, e incluirlo en las consultas al profesor. No se modificó código ni configuración. Las comprobaciones diagnósticas de las respuestas de los comandos se evalúan por separado de las operaciones que estos realizan.

## Referencias

- Letra, `Infraestructura Obligatorio Agosto 2026 (1).pdf`, página 12: comunicación e infraestructura a investigar y seleccionar por el equipo.
- Código actual: `mensajeria.adb`, procedimiento `Preparar`; `coordinador.adb`, llamada inicial a `Preparar`; `docker-compose.yml`, chequeos y dependencias de arranque.
- Documentación externa de Redis: [DEL](https://redis.io/docs/latest/commands/del/), [SET](https://redis.io/docs/latest/commands/set/) y [GET](https://redis.io/docs/latest/commands/get/).
- Documentación externa de Docker: [orden de arranque con Compose](https://docs.docker.com/compose/how-tos/startup-order/).
