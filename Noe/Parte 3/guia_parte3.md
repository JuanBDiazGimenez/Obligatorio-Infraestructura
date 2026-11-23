# Parte 3 (Ada) – Torneo de pádel: guía para entender y explicar el código

Archivo: `torneo_padel.adb` (80 líneas). Sin paquetes extra: solo `Ada.Text_IO` y `Ada.Numerics.Float_Random`.

```bash
gnatmake torneo_padel.adb
./torneo_padel            # ~5 segundos
```

## 0. Qué se hizo y cómo (proceso)

1. Se tradujo la letra a una analogía vista en clase: **un servidor (Coordinador) y varios clientes (Canchas)** que se comunican por citas (rendezvous).
2. Se decidió qué entradas (`entry`) necesita el Coordinador: una para **pedir** partido y otra para **informar** el resultado.
3. Se resolvió cómo terminan las tasks: el Coordinador responde "0" cuando no quedan partidos, y las canchas terminan solas.
4. Se compiló con `-gnatwa` (todos los warnings: ninguno) y se corrió 5 veces verificando: 8 partidos asignados, todos distintos, 8 finalizados, 8 resultados recibidos, y última línea "Torneo terminado.".

## 1. Mapa del programa
```
         Pedir_Partido(Id) ───────────►
Cancha 1 ◄─────────── Partido (o 0)       ┌──────────────┐
Cancha 2 ──Informar_Resultado(Id, Ganador)►│ Coordinador  │  (task con 2 entries, dentro de un select)
Cancha 3                                   └──────────────┘
```

- El procedimiento `Torneo_Padel` declara **4 tasks**: `Coordinador` (una sola) y 3 canchas (`task type Cancha`, instancias C1, C2, C3).
- Las tasks se **activan automáticamente** al llegar al `begin` del procedimiento. El `begin ... null; end` es vacío: el procedimiento principal no termina hasta que todas las tasks que declaró terminan.

## 2. Qué hay que saber de Ada (conceptos)
| Concepto | Qué significa |
|---|---|
| **`task`** | Unidad de ejecución concurrente. Tiene una especificación (con sus `entry`) y un cuerpo (`task body`). |
| **`task type`** | Una "plantilla" para crear varias tasks iguales. `Cancha (Id : Positive)` tiene un **discriminante** `Id` que identifica a cada instancia (`C1 : Cancha (1)`). |
| **`entry`** | Punto de entrada: lo que otra task puede pedirle a esta. Se llama como un procedimiento: `Coordinador.Pedir_Partido (Id, Partido)`. |
| **`accept`** | Dentro de la task dueña de la entry: la atiende. |
| **Cita (rendezvous)** | Se produce cuando una task llama a una entry **y** la dueña llega a su `accept`. Quien llega primero espera. Mientras dura el cuerpo del `accept`, ambas están sincronizadas; después, cada una sigue por su cuenta. |
| **`select ... or ...`** | La task espera **simultáneamente** varias entries y atiende la primera que reciba una llamada. |
| **Parámetros `in` / `out`** | `Id_Cancha` viaja de la cancha al Coordinador (`in`); `Partido` vuelve del Coordinador a la cancha (`out`). |
| **`delay`** | Duerme la task el tiempo indicado (en segundos, tipo `Duration`). |
| **Generador aleatorio** | `Ada.Numerics.Float_Random.Generator`: da números de 0.0 a 1.0. |

## 3. El código por bloques

### 3.1 Declaraciones (líneas 3-17)
| Líneas | Qué hace |
|---|---|
| 3-4 | `with` importa los paquetes. `use Ada.Text_IO` permite escribir `Put_Line` sin prefijo. |
| 8-9 | Constantes: 8 partidos, 3 canchas. El partido *k* es entre las parejas *2k-1* y *2k* (partido 1: parejas 1 y 2; partido 8: 15 y 16). Así las 16 parejas quedan cubiertas sin tablas. |
| 11-15 | Especificación del Coordinador: 2 entries. `Pedir_Partido` devuelve el número de partido (o 0). `Informar_Resultado` recibe la cancha y la pareja ganadora. |
| 17 | `task type Cancha (Id : Positive)`: el tipo de las canchas. |

### 3.2 Cuerpo del Coordinador (líneas 19-46)
| Líneas | Qué hace |
|---|---|
| 20 | `Siguiente`: el próximo partido sin asignar (1, 2, … 8). Es **local** del Coordinador: nadie más lo toca, por eso no hace falta ninguna exclusión mutua extra. Solo atiende una cita a la vez. |
| 21 | `Despedidas`: cuántas canchas ya recibieron "no hay más partidos". |
| 23 | El Coordinador trabaja hasta despedir a las 3 canchas. |
| 24-42 | `select`: espera una llamada a `Pedir_Partido` **o** a `Informar_Resultado`. |
| 26-31 | Si queda un partido (`Siguiente <= 8`): se lo entrega a la cancha (`Partido := Siguiente`), imprime la asignación y avanza `Siguiente`. Por estar dentro de un `accept`, **un mismo partido nunca se asigna a dos canchas**: las citas se atienden de a una. |
| 32-35 | Si no quedan: `Partido := 0` y cuenta una despedida. |
| 38-41 | Recibe el resultado e imprime. |
| 44-45 | Al salir del bucle (las 3 canchas despedidas) imprime el cierre. Como cada cancha informa su resultado **antes** de volver a pedir, para ese momento ya se recibieron los 8 resultados. |

### 3.3 Cuerpo de la Cancha (líneas 48-72)
| Líneas | Qué hace |
|---|---|
| 50 | Cada cancha tiene su **propio** generador (si se compartiera entre tasks habría una condición de carrera). |
| 54 | `Reset (Gen, Id)`: semilla distinta por cancha, así no sortean lo mismo. |
| 55-71 | Bucle: **pedir → jugar → informar**. |
| 56-57 | Imprime que solicita y llama a la entry (se queda esperando hasta que el Coordinador la atienda). |
| 58 | Si recibió 0, sale del bucle: la task termina sola. Esto cumple "cuando no queden partidos pendientes, las canchas deberán finalizar". |
| 61 | Duración aleatoria: `Random` da entre 0.0 y 1.0, multiplicado por 4.0 → **no mayor a 4 segundos**. |
| 63-67 | Ganador aleatorio entre las dos parejas del partido. |
| 70 | Informa el resultado mediante otra cita. |

### 3.4 Cuerpo principal (líneas 74-80)
Declara las 3 instancias. Al llegar a `begin` se activan las 4 tasks. `null` no hace nada: el procedimiento espera a que todas terminen antes de finalizar, así el programa termina cuando se disputaron los 8 partidos.

## 4. Cómo se cumple cada consideración de la letra
| Consideración | Cómo |
|---|---|
| 8 partidos, 3 canchas | Constantes y 3 instancias de `Cancha`. |
| Cada cancha es una task | `task type Cancha`. |
| Task Coordinador | `task Coordinador` con `select`. |
| Piden partido por cita | `Coordinador.Pedir_Partido` es una llamada a entry. |
| Informan resultado por cita | `Coordinador.Informar_Resultado`. |
| Una cancha juega un partido a la vez | El bucle es secuencial: pide, juega, informa. |
| Un partido no va a dos canchas | `Siguiente` se incrementa dentro del `accept`, y el Coordinador atiende una cita por vez. |
| Duración ≤ 4 s y ganador aleatorio | Líneas 61 y 63. |
| Canchas terminan sin partidos | `exit when Partido = 0`. |
| Programa termina con los 8 partidos | Todas las tasks terminan; el principal espera a sus tasks. |
| Muestra asignaciones y resultados | `Put_Line` en Coordinador y Canchas. |

## 5. Preguntas probables de defensa

1. ¿Qué es una cita (rendezvous)? → Sincronización entre dos tasks: una llama a la entry y la otra la acepta. Mientras dura el `accept` las dos están "juntas"; el que llega primero espera.
2. ¿Qué hace el `select`? → Permite al Coordinador esperar dos entries a la vez y atender la que llegue.
3. ¿Qué pasa si dos canchas piden a la vez? → Las llamadas se encolan en la entry (en orden de llegada, FIFO) y se atienden una por una.
4. ¿Por qué no hay riesgo de asignar el mismo partido a dos canchas? → Porque `Siguiente` solo lo modifica el Coordinador dentro del `accept`, y atiende una cita por vez.
5. ¿Cómo termina el programa? → El Coordinador responde 0; cada cancha sale de su bucle; cuando terminan todas las tasks, termina el procedimiento principal.
6. ¿Para qué sirve el discriminante `Id`? → Identifica a cada cancha al crearla (`Cancha (1)`).
7. ¿Qué significa `out` en `Partido : out Natural`? → El valor viaja del Coordinador a la cancha como resultado de la cita.
8. ¿Qué pasaría con un generador aleatorio compartido? → Dos tasks podrían usarlo a la vez: no está protegido (condición de carrera). Por eso hay uno por task.
9. ¿Por qué el Coordinador cuenta `Despedidas` en vez de resultados? → Termina cuando todas las canchas fueron despedidas; como cada cancha informa antes de volver a pedir, ya llegaron los 8 resultados.
10. ¿Qué pasa si el `select` no tiene `or`? → Solo esperaría una entry y la otra quedaría bloqueada.

## 6. Limitaciones / decisiones

- Los `Put_Line` de distintas tasks pueden intercalarse entre sí (cada `Put_Line` es atómico, pero no un grupo de varios). Por eso la asignación del Coordinador se imprime en **un solo** `Put_Line` (con saltos de línea `ASCII.LF`).
- Los mensajes llevan tildes (UTF-8): se ven bien en un terminal UTF-8.

## 7. Declaración de uso de IA

- **Herramienta:** Claude Code (Claude Sonnet 5.5, Anthropic).
- **Contexto de uso:** diseño y redacción inicial del código y de esta guía, y compilación y pruebas del programa.
- **Verificación propia:** [completar: qué compiló, ejecutó, revisó y modificó cada integrante].
- Somos responsables de cualquier error del contenido generado.
