# Parte 4 (Virtualización / microservicios) – Atracadero: guía para entender y explicar la solución

## 0. Qué se hizo y cómo (proceso)

1. La letra no impone cómo comunicar los microservicios. Se evaluaron opciones y se eligió **TCP con un protocolo de texto de 3 mensajes** (ver sección 2).
2. Se dividió el sistema en **2 programas Ada**: `puerto` (dueño del atracadero, un servicio) y `barco` (se ejecuta varias veces: uno por contenedor). Comparten el paquete `Protocolo` (leer/escribir líneas).
3. Se empaquetó todo en **un Dockerfile** y un **docker-compose.yml** que levanta `puerto` + 4 barcos (la letra pide al menos 3).
4. Se compiló con `-gnatwa` (sin warnings) y se probó la lógica corriendo los procesos juntos (45 s, 4 barcos): un script verificó que **nunca hubo 2 barcos autorizados a la vez**, que se autorizó en orden de llegada y que hubo competencia (hasta 3 barcos esperando a la vez).
5. Se ejecutó con `docker compose up` (5 contenedores, 45 s) y se verificó el log del puerto con el mismo script: **OK** (22 autorizaciones, nunca 2 barcos a la vez, orden FIFO, hasta 3 barcos solicitando a la vez). Ver sección 6.

## 1. Arquitectura
```
 ┌─────────┐   SOLICITAR Barco 1   ┌────────────────────────────┐
 │ barco1  │ ────────────────────► │ puerto                     │
 │ barco2  │ ◄──────────────────── │  atracadero (objeto        │
 │ barco3  │       AUTORIZADO      │  protegido: 1 a la vez)    │
 │ barco4  │   LIBERAR Barco 1     │  una task por conexión     │
 └─────────┘ ────────────────────► └────────────────────────────┘
   contenedores (red de compose, el servicio se llama "puerto")        puerto TCP 5000
```
Flujo de un barco (el ciclo de la letra): navegar (1-5 s aleatorio) → **solicitar** → **esperar autorización** → usar el atracadero (1-3 s) → **informar que lo abandona** → volver a navegar → repetir.

## 2. Cómo se resuelve la comunicación entre microservicios
**Elección: sockets TCP**, un mensaje por línea. Cada visita de un barco es **una conexión corta**:

| Paso | Quién | Mensaje |
|---|---|---|
| 1 | barco → puerto | `SOLICITAR Barco 2` |
| 2 | puerto → barco | `AUTORIZADO` (solo cuando el atracadero está libre; hasta entonces el barco queda **bloqueado esperando la respuesta**) |
| 3 | barco → puerto | `LIBERAR Barco 2` |

**Por qué TCP y no otra cosa:**

- No necesita infraestructura extra (broker, base de datos). Con Docker alcanza el nombre del servicio (`puerto`) como dirección.
- TCP es confiable y ordenado: los mensajes llegan completos y en orden.
- Esperar la autorización es natural: el barco simplemente **queda leyendo del socket** hasta que el puerto escribe.
- Alternativas descartadas: HTTP/REST (necesita servidor web y librerías externas en Ada), cola de mensajes tipo RabbitMQ/Redis (otro contenedor y otra dependencia), memoria compartida/archivos (no sirve entre contenedores).

## 3. Exclusión mutua: cómo se garantiza "nunca más de un barco"

- El atracadero es un **objeto protegido de Ada** (`protected Atracadero`, `puerto.adb` líneas 10-31). Un objeto protegido ejecuta **una sola operación a la vez**.
- `entry Ocupar ... when Libre`: la **barrera** `when Libre` bloquea a quien llame mientras el atracadero esté ocupado. Al liberarse (`Liberar` pone `Libre := True`), **solo uno** de los que esperan entra: los demás siguen en la cola de la entry, atendidos en orden de llegada (FIFO).
- Aunque varios barcos pidan "prácticamente al mismo tiempo", el objeto protegido los ordena: no puede haber dos autorizaciones simultáneas.
- Como prueba, el puerto lleva la cuenta `Ocupados` y la imprime en cada autorización: siempre vale 1.

## 4. El código por bloques

### 4.1 `protocolo.ads` / `protocolo.adb`
| Elemento | Qué hace |
|---|---|
| `Puerto_TCP` | Constante 5000: puerto del servicio. |
| `Leer_Linea` | Lee caracteres del canal hasta el salto de línea (`ASCII.LF`) y devuelve el texto. Si el otro lado cierra, `Character'Read` levanta una excepción. |
| `Escribir` | Envía el texto con un salto de línea al final (`String'Write`). |

### 4.2 `puerto.adb`
| Líneas | Qué hace |
|---|---|
| 10-16 | Especificación del objeto protegido: `Ocupar` (entry con barrera), `Liberar` (procedure), y su estado privado (`Libre`, `Ocupados`). |
| 19-24 | `Ocupar`: se ejecuta solo cuando `Libre`. Marca ocupado y cuenta. |
| 26-30 | `Liberar`: descuenta y vuelve a dejarlo libre. |
| 34-36 | `task type Atender`: **una task por conexión**, para que un barco que espera no impida atender a los otros (el hilo principal sigue aceptando). |
| 43-45 | `accept Iniciar`: el hilo principal le entrega el socket a la task (los sockets no pueden ser discriminantes de una task, por eso se usa una cita). |
| 48-49 | Lee `SOLICITAR Barco N` y extrae el nombre (`Pedido'First + 10`: "SOLICITAR " tiene 10 caracteres). |
| 52 | **`Atracadero.Ocupar`**: la task se **bloquea acá** hasta que el atracadero esté libre. |
| 54-55 | Imprime la autorización y responde `AUTORIZADO` al barco. |
| 58-62 | Espera `LIBERAR` y llama a `Liberar`. |
| 67-75 | Manejo de errores: si el barco se cae con el atracadero tomado, el puerto lo libera (si no, quedaría **bloqueado para siempre**). |
| 84-88 | Crea el socket servidor, `Reuse_Address` (permite reiniciar rápido), `Bind` al puerto 5000 y `Listen`. |
| 89-93 | Bucle principal: `Accept_Socket` espera una conexión, crea una task `Atender` y le pasa el socket. |

### 4.3 `barco.adb`
| Líneas | Qué hace |
|---|---|
| 12-14 | Toma por parámetros su número y el host del puerto (`barco 2 puerto`). |
| 17-18 | `Aleatorio`: duración aleatoria entre `Min` y `Max` segundos. |
| 21-36 | `Conectar`: crea el socket y se conecta al puerto. Si falla (el puerto todavía no arrancó en el contenedor), **reintenta cada segundo**. `Get_Host_By_Name` resuelve el nombre `puerto` (el DNS de compose). |
| 40 | Semilla distinta por barco. |
| 41-60 | Ciclo infinito: navegar, solicitar, esperar autorización (línea 51: `Leer_Linea` bloquea), usar el atracadero, avisar `LIBERAR` y volver a navegar. |

## 5. Docker
### `Dockerfile` (2 etapas)
| Instrucción | Qué hace |
|---|---|
| `FROM debian:bookworm-slim AS build` | Imagen base mínima; la etapa se llama `build`. |
| `RUN apt-get install ... gnat` | Instala el compilador de Ada (`--no-install-recommends` evita paquetes extra; se borra la caché de apt para achicar la imagen). |
| `COPY *.ads *.adb ./` | Copia los fuentes. |
| `RUN gnatmake -O2 puerto.adb && gnatmake -O2 barco.adb` | Compila los dos programas. |
| `FROM debian:bookworm-slim` (2ª etapa) | Imagen final limpia, sin compilador. |
| `RUN ... libgnat-12` | Solo la librería de ejecución de Ada que necesitan los binarios. |
| `COPY --from=build ...` | Trae solo los 2 binarios de la etapa anterior. |
| `CMD ["puerto"]` | Comando por defecto; cada servicio lo cambia en compose. |

### `docker-compose.yml`

- `x-ada: &ada`: bloque reutilizable (ancla YAML): construye la imagen del Dockerfile y le pone nombre. Cada servicio lo incluye con `<<: *ada`.
- 5 servicios = **5 contenedores** = 5 microservicios independientes: `puerto` y `barco1..barco4`.
- `command`: qué ejecuta cada uno (`["barco", "2", "puerto"]` = barco número 2 que se conecta al host `puerto`).
- Compose crea una **red** donde cada servicio es accesible por su nombre: por eso el barco usa `puerto` como host.
- `depends_on: [puerto]`: arranca el puerto antes. (No espera a que esté escuchando: por eso `Conectar` reintenta.)

### Ejecución
```bash
docker compose up --build          # construye y levanta los 5 contenedores; muestra los logs mezclados
docker compose up --build -d && docker compose logs -f puerto     # alternativa: en segundo plano
docker compose down                # detiene y borra los contenedores
```

## 6. Evidencia de ejecución

- `evidencia_puerto_sin_docker.log`: log del puerto con 4 barcos corriendo como procesos (45 s). Verificado con `awk -f verificar_log.awk <log>` → "OK: nunca 2 barcos a la vez, orden FIFO, hasta 3 barcos solicitando a la vez". (Las 3 últimas líneas son "conexión perdida": ocurrió al detener los barcos con `pkill`, y muestra que el puerto libera el atracadero si un barco se cae.)
- `evidencia_docker.log`: logs de los 5 contenedores (`docker compose logs --timestamps`) tras 45 s de `docker compose up`. Se verifica con `awk -f verificar_log.awk evidencia_docker.log` → OK. Ahí se ven los 4 barcos compitiendo y que el puerto autoriza de a uno.

## 7. Preguntas probables de defensa

1. ¿Cómo se comunican los microservicios? → Por TCP con mensajes de texto (SOLICITAR / AUTORIZADO / LIBERAR), usando `GNAT.Sockets`.
2. ¿Cómo garantizás que solo un barco usa el atracadero? → Objeto protegido con barrera `when Libre`: solo una autorización a la vez.
3. ¿Qué pasa si dos barcos piden a la vez? → Se encolan en la entry `Ocupar` y se atienden en orden de llegada.
4. ¿Qué pasa si un barco se cae con el atracadero tomado? → El `exception` del puerto lo libera; sin eso quedaría bloqueado.
5. ¿Por qué una task por conexión? → Si el hilo principal atendiera a un barco esperando, no podría aceptar a los demás.
6. ¿Para qué sirve el multi-stage del Dockerfile? → La imagen final no lleva el compilador: es mucho más chica.
7. ¿Cómo encuentra el barco al puerto? → Por el nombre del servicio (`puerto`): la red de compose lo resuelve por DNS.
8. ¿Qué diferencia hay entre imagen y contenedor? → La imagen es la plantilla (de solo lectura); el contenedor es una instancia en ejecución.
9. ¿Por qué `depends_on` no alcanza? → Solo ordena el arranque, no espera a que el servicio esté listo; por eso el barco reintenta.
10. ¿Por qué no se usó una base de datos o un broker? → Complicaba la solución sin necesidad; un objeto protegido ya resuelve la exclusión.

## 8. Limitaciones

- Las tasks `Atender` terminadas no se liberan de memoria (`shortcut` comentado en el código); para una demo larga no es un problema.
- No hay cifrado ni autenticación en el socket (red interna de compose).
- Si el puerto se cae, los barcos reintentan conectar pero pierden su turno.

## 9. Declaración de uso de IA

- **Herramienta:** Claude Code (Claude Sonnet 5.5, Anthropic).
- **Contexto de uso:** diseño y redacción inicial del código, el Dockerfile, el compose y esta guía, y compilación y pruebas.
- **Verificación propia:** [completar: qué compiló, ejecutó, revisó y modificó cada integrante].
- Somos responsables de cualquier error del contenido generado.
