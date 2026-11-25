# Parte 4 — Instrucciones de ejecución

## Preparación

Se necesita Docker con Compose. En Windows, iniciar Docker Desktop y esperar a que esté listo para usar contenedores Linux. La primera construcción necesita conexión a Internet para descargar las imágenes y los paquetes. No hace falta instalar GNAT, Redis ni Python en el equipo: las dependencias de ejecución están en los contenedores.

Abrir una terminal en la carpeta que contiene `docker-compose.yml`, `Dockerfile` y los archivos Ada de esta parte. Todos los comandos siguientes se ejecutan desde esa carpeta, en el equipo, sin entrar a un contenedor. No dependen del nombre ni de la ubicación de la carpeta.

## Construir e iniciar

Ejecutar cada comando cuando termine el anterior sin errores:

```text
docker compose pull redis
docker compose build
docker compose up -d --pull never
docker compose ps
```

`pull redis` descarga la imagen de Redis. `build` construye la imagen de los programas Ada usando el Dockerfile. `up -d` inicia los servicios en segundo plano; `--pull never` utiliza las imágenes ya preparadas. `ps` muestra su estado. Compose encuentra automáticamente `docker-compose.yml` en la carpeta actual.

Deben aparecer cinco servicios: `redis`, `coordinador`, `barco1`, `barco2` y `barco3`. Redis y el coordinador deben indicar `healthy`; si todavía están iniciándose, esperar y repetir `docker compose ps`.

Los barcos comparten una imagen, pero cada uno se ejecuta como un programa independiente en su propio contenedor. Redis escucha en el puerto 6739 dentro de la red de Compose; no se publica ese puerto al equipo. El coordinador prepara sus claves antes de que Compose permita iniciar los barcos.

## Observar el funcionamiento

```text
docker compose logs -f
```

Cada barco muestra `NAVEGA`, `SOLICITA`, `ENTRA` y `SALE`. Navegar y ocupar el atracadero demoran entre 1 y 3 segundos al azar. Observar varios ciclos: los tres barcos deben solicitar, entrar, salir y volver a navegar. La simulación es continua.

`Ctrl+C` deja de mostrar los logs, pero no detiene los contenedores. Para seguir las decisiones globales del coordinador:

```text
docker compose logs -f coordinador
```

Entre `AUTORIZACION n` y la autorización siguiente debe aparecer `LIBERACION n`. Mientras un barco tiene el permiso pueden aparecer solicitudes de los demás. Estas se guardan y atienden por orden de llegada.

Los logs combinados de distintos contenedores pueden mostrarse intercalados. Para revisar el orden de concesión de permisos se utiliza la secuencia del coordinador, junto con el protocolo explicado en `Comunicacion_microservicios.md`.

## Conservar una ejecución y detener

Se pueden guardar los logs actuales antes de detener los servicios:

```text
docker compose logs --no-color coordinador > coordinador.txt
docker compose logs --no-color barco1 > barco1.txt
docker compose logs --no-color barco2 > barco2.txt
docker compose logs --no-color barco3 > barco3.txt
```

Estos archivos quedan en la carpeta actual; repetir los comandos con los mismos nombres reemplaza su contenido. Son registros para observar la ejecución, no archivos utilizados para comunicar los programas.

Para detener y retirar los contenedores y la red de este proyecto:

```text
docker compose down
```

Para repetir desde el inicio, ejecutar nuevamente `docker compose up -d --pull never`. Reiniciar el conjunto completo: la solución no implementa recuperación ante reinicios aislados de Redis o del coordinador con barcos activos.

## Si aparece un problema

- Docker no conecta: comprobar que Docker Desktop esté iniciado y use contenedores Linux.
- No encuentra la configuración: abrir la terminal en la carpeta que contiene `docker-compose.yml`.
- Falta una imagen: repetir `docker compose pull redis` y `docker compose build`.
- Un servicio termina o no queda saludable: consultar `docker compose ps -a` y `docker compose logs` y conservar el mensaje completo antes de bajar el proyecto.

Las instrucciones corresponden a los archivos de esta parte. La compilación y ejecución ocurren dentro de contenedores Ubuntu; Redis utiliza la imagen `redis:7.4-alpine`.
