# Prueba Ada - Redis

Dos ejecutables Ada independientes (`emisor` y `receptor`) corren en **mi_ubuntu**.
El servidor Redis corre en **otro contenedor**, `infra-test-redis-ada`, en el puerto
interno **6739**. No se publica ningún puerto en Windows y no se usa Compose.

## Qué hace

- `Mensajeria.Enviar` invoca `redis-cli RPUSH` para agregar un mensaje.
- `Mensajeria.Recibir` consulta con `redis-cli LPOP`. Si no obtiene mensaje,
  hace una pausa de 100 ms (0,1 segundos) y vuelve a consultar, hasta unos diez
  segundos como límite de esta prueba.
- `GNAT.Expect.Get_Command_Output` ejecuta el cliente y devuelve su salida como
  texto en memoria. El intercambio usa pipes y Redis, no archivos temporales.
- Los argumentos se pasan por separado, sin ejecutar un shell. `LPOP` devuelve
  el mensaje retirado, o una respuesta vacía si la cola no tiene elementos.
- El límite se mide con el reloj monotónico de `Ada.Real_Time`; la pausa se
  implementa con `delay 0.1`. Cada consulta inicia un proceso cliente.
- La cola exclusiva es `infra:test:redis_ada:mensajes`.

Los diez segundos limitan esta prueba; no son una política de espera para la
parte 4. Esta prueba tampoco implementa el atracadero ni sus autorizaciones.

## Entorno preparado

- GNAT ya estaba instalado en `mi_ubuntu`.
- Se instaló **redis-tools**, que aporta el cliente `/usr/bin/redis-cli`, junto
  con sus dependencias `libjemalloc2` y `liblzf1`. No se instaló un servidor Redis
  dentro de `mi_ubuntu`.
- Se descargó `redis:7.4-alpine` y se creó el contenedor del servidor con
  `redis-server --port 6739 --save "" --appendonly no`.
- `mi_ubuntu` y el servidor están conectados a `infra-test-redis-ada-net`.
- Las fuentes y ejecutables de prueba están también en
  `/home/alumno/test-redis-ada`, dentro de `mi_ubuntu`; no es una carpeta temporal.

## Repetir la prueba automática

En una terminal del equipo, con Docker funcionando y `mi_ubuntu` iniciado:

```powershell
docker start infra-test-redis-ada
docker exec -w /home/alumno/test-redis-ada mi_ubuntu python3 verificar.py
```

El verificador recompila, limpia **solo su cola exclusiva**, comprueba consultas LPOP
periódicas, recepción con espera, FIFO y mensajes con espacios/caracteres de shell, y prueba el timeout
de diez segundos. Debe terminar con `PRUEBA COMPLETA` y código de salida cero.
El timeout se prueba intencionalmente: fuera del verificador, un receptor sin
mensajes terminará con la excepción `Tiempo_Agotado`.

## Probar a mano con dos terminales

Primero iniciar Redis con el comando anterior. Terminal 1:

```powershell
docker exec -w /home/alumno/test-redis-ada mi_ubuntu ./receptor
```

Antes de diez segundos, ejecutar en la terminal 2:

```powershell
docker exec -w /home/alumno/test-redis-ada mi_ubuntu ./emisor "hola desde Ada"
```

El emisor muestra `Enviado: hola desde Ada`. El receptor muestra
`Recibido: hola desde Ada` y termina. Si se envía primero, el mensaje queda en la
cola hasta que se ejecute el receptor.

Para volver a copiar las fuentes desde la raíz del repositorio:

```powershell
docker cp "Fede/Test Redis-ADA/." mi_ubuntu:/home/alumno/test-redis-ada/
```

Para terminar de usar el servidor de esta prueba:

```powershell
docker stop infra-test-redis-ada
```

El contenedor y la red quedan preparados para repetir la prueba. Al estar
desactivada la persistencia, no se conservan mensajes al reiniciar Redis.

## Fuentes y alcance

El laboratorio 8 (`voting-app.zip`) usa una lista Redis con `RPUSH` en Vote y
extracción por la izquierda en Worker. El acceso desde Ada mediante un proceso
cliente es una adaptación propia; no se presenta como código dado por el docente.

- [Redis CLI](https://redis.io/docs/latest/develop/tools/cli/).
- [LPOP](https://redis.io/docs/latest/commands/lpop/).
- [Biblioteca de GNAT: GNAT.Expect](https://docs.adacore.com/gnat_rm-docs/html/gnat_rm/gnat_rm/the_gnat_library.html).

Esto valida la interfaz Ada/cliente/Redis con procesos distintos; para el ejercicio
final todavía falta separar cada barco en su contenedor y resolver el protocolo
de autorización con un único estado del atracadero.
