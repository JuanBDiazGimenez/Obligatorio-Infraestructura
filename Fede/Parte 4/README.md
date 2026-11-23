# Parte 4 - Atracadero

La solución tiene cinco servicios: tres programas `barco` Ada con identificadores
distintos, un programa `coordinador` Ada y Redis. Se usa una red interna de Compose,
sin publicar puertos al equipo. Redis escucha en **6739**.

El proyecto Compose se llama `atracadero` y los programas Ada usan la imagen
`atracadero-ada:local`.

## Compilar e iniciar

Con Docker Desktop funcionando, desde la raíz del repositorio:

```powershell
cd "Fede/Parte 4"
docker compose build
docker compose up -d --pull never
docker compose logs -f
```

La primera construcción descarga Ubuntu 24.04 e instala GNAT en la etapa de
compilación. La imagen de ejecución contiene `libgnat-13` y `redis-tools` para
ejecutar los programas y el cliente `redis-cli`. Redis usa `redis:7.4-alpine`:
si esa imagen no está disponible localmente, ejecutar primero
`docker compose pull redis`. No hace falta GNAT en Windows ni usar `mi_ubuntu`.

`Ctrl+C` sale del seguimiento de logs; los servicios siguen ejecutándose.
Para detener y retirar **solo este proyecto**:

```powershell
docker compose down
```

La simulación es continua, no tiene un número final de ciclos. Para repetir desde
el comienzo se baja y se levanta el conjunto completo. No se reinicia solamente el
Coordinador o Redis con barcos activos: no se implementa recuperación ante fallos.

## Cómo se comunican

- `puerto:eventos`: lista Redis que recibe `SOLICITAR 1`, `LIBERAR 1`, etc.
- `puerto:permiso:1`, `:2` y `:3`: buzón individual de cada barco. El Coordinador
  agrega `AUTORIZADO`; el barco lo retira para entrar. No consulta un booleano.
- `RPUSH` agrega al final y `LPOP` retira del principio. Si no hay mensajes,
  `Recibir` espera **100 ms** y vuelve a consultar. No hay timeout de autorización.
- `GNAT.Expect` ejecuta `redis-cli` con argumentos separados y recoge la respuesta
  en memoria. No se usan archivos para enviar o recibir mensajes.

El Coordinador conserva el ocupante y una cola circular FIFO de pendientes. Solo
él modifica esos datos: no hay una copia del estado por barco. Una solicitud se
registra y se continúa atendiendo eventos, incluso cuando el atracadero está
ocupado. La liberación la debe enviar el ocupante; entonces se reserva el lugar
para el siguiente pendiente **antes** de poner su permiso en Redis.

Si dos barcos solicitan prácticamente al mismo tiempo, se atienden según el orden
de sus mensajes en la lista Redis. Los tiempos de navegación y uso se sortean
independientemente entre **1 y 3 segundos** con `Discrete_Random`. Cada barco
mantiene su propio generador y una única solicitud pendiente.

Antes de admitir barcos, el Coordinador limpia solamente las claves del proyecto
y marca `puerto:listo`. Los `healthcheck` y `depends_on` hacen que los barcos
arranquen después. No hay persistencia configurada ni permisos de una ejecución
anterior. Se presupone una sola instancia del Coordinador, como declara Compose.

El cliente conserva el control del código de salida de `redis-cli`: si falla,
lanza `Error_Comunicacion`. Se retiraron los diagnósticos adicionales sobre los
mensajes y las respuestas de Redis, y el manejador general de excepciones. La
espera y retirada del permiso con `LPOP`, la limpieza de CR/LF al recibir y la
liberación normal de los argumentos se mantienen. Los resultados que no se
comprueban se guardan sin leerlos. La opción de compilación `-gnatwU` desactiva
los avisos sobre elementos no utilizados; los demás avisos siguen activos y se
tratan como errores. No se agregan lecturas artificiales ni se desactivan las
comprobaciones de límites durante la ejecución. Véase `Resultados_no_utilizados.md`.

## Verificar y conservar evidencia

Con el conjunto recién iniciado y sin otros operadores enviando mensajes:

```powershell
python verificar.py
```

Se necesita Python 3 en el equipo **solo para automatizar la verificación**. El
verificador espera al menos tres ciclos completos por barco, reconstruye la fila
FIFO y el ocupante a partir del log del Coordinador y guarda las salidas de los
cuatro programas en `evidencia/`. Luego crea un escenario independiente, sin
barcos, para inyectar tres solicitudes juntas en orden 2,3,1 y comprobar que solo
se autoriza al siguiente al liberarse el atracadero. También comprueba que el
arranque descarte mensajes anteriores. Al terminar retira sus servicios con
`docker compose down`, incluso si una comprobación falla.

Las trazas `SOLICITUD`, `AUTORIZACION` y `LIBERACION` del Coordinador permiten
seguir el orden global de decisión. Los logs de cada barco muestran navegación,
entrada y salida. El orden de visualización entre contenedores no sustituye esas
relaciones de mensajes ni la revisión del protocolo.

## Fuentes y decisiones

- Letra, páginas 11-13: barcos Ada independientes, acceso exclusivo, solicitudes,
  autorizaciones, liberaciones, instrucciones y evidencia. No exige FIFO; se
  eligió para respetar el orden de llegada.
- Laboratorio 8, `voting-app.zip`: mensajes mediante Redis y lista con inserción
  al final/extracción al principio; Worker consulta cada 100 ms.
- Clase del 17/11 y `IntroduccionDockerCompose (1) (1).pdf`: servicios, redes,
  `healthcheck`, dependencias y arranque con Compose.
- [Redis LPOP](https://redis.io/docs/latest/commands/lpop/) y
  [Redis CLI](https://redis.io/docs/latest/develop/tools/cli/).
- [Biblioteca de GNAT](https://docs.adacore.com/gnat_rm-docs/html/gnat_rm/gnat_rm/the_gnat_library.html)
  para `GNAT.Expect`, y [Ada A.5.2](https://www.adaic.org/resources/add_content/standards/12rm/html/RM-A-5-2.html)
  para `Discrete_Random`.

El acceso desde Ada al cliente, el protocolo, la cola del Coordinador y la señal
de inicio son decisiones de esta implementación, no una solución docente. La
lógica está en Ada; Redis y su cliente transportan los mensajes. Se usó Codex
(GPT-6 según contexto de sesión) para implementar y verificar esta propuesta;
el equipo debe revisar y comprender lo incorporado. Este README es una guía de
trabajo; la documentación general de entrega se prepara al final.
