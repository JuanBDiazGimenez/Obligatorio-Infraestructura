with Ada.Text_IO; use Ada.Text_IO;
with Ada.Numerics.Discrete_Random;

procedure Torneo is
   Total_Partidos : constant := 8;
   Total_Canchas  : constant := 3;

   type Lista_Parejas is array (1 .. Total_Partidos) of Integer;
   Parejas_A : Lista_Parejas;
   Parejas_B : Lista_Parejas;

   -- Se sortean enteros; mod acota los valores usados por el torneo.
   package Azar_Duracion is new Ada.Numerics.Discrete_Random (Integer);
   package Azar_Ganador is new Ada.Numerics.Discrete_Random (Integer);

   procedure Ejecutar_Torneo is
      -- El Coordinador asigna los partidos y recibe sus resultados.
      task Coordinador is
         entry Solicitar_Partido
           (Cancha : Integer; Numero : out Integer);
         entry Informar_Resultado
           (Cancha : Integer; Numero : Integer; Ganador : Integer);
      end Coordinador;

      -- Una misma definición sirve para tres tareas con identificadores distintos.
      task type Cancha (Id : Integer);

      task body Coordinador is
         Proximo : Integer := 1;
         Canchas_Cerradas : Natural := 0;
      begin
         -- Asignar el octavo no implica haber recibido su resultado. También
         -- debemos responder las solicitudes finales de las tres canchas.
         while Canchas_Cerradas < Total_Canchas loop
            -- Se atiende una cita por vez, de solicitud O de resultado.
            -- Un accept fijo podría esperar pedidos mientras llegan resultados.
            select
               accept Solicitar_Partido
                 (Cancha : Integer; Numero : out Integer)
               do
                  -- La cancha que llama espera hasta terminar este accept.

                  if Proximo <= Total_Partidos then
                     Numero := Proximo;
                     Proximo := Proximo + 1;
                     Put_Line
                       ("Coordinador: Partido" & Integer'Image (Numero)
                        & " asignado a Cancha" & Integer'Image (Cancha)
                        & ". Pareja" & Integer'Image (Parejas_A (Numero))
                        & " vs Pareja" & Integer'Image (Parejas_B (Numero))
                        & ".");
                  else
                     Numero := 0;
                     Canchas_Cerradas := Canchas_Cerradas + 1;
                     Put_Line
                       ("Coordinador: sin partidos pendientes para Cancha"
                        & Integer'Image (Cancha) & ".");
                  end if;
               end Solicitar_Partido;
            or
               accept Informar_Resultado
                 (Cancha : Integer; Numero : Integer; Ganador : Integer)
               do
                  Put_Line
                    ("Coordinador recibió resultado de Cancha"
                     & Integer'Image (Cancha) & ": Partido"
                     & Integer'Image (Numero) & ", ganador Pareja"
                     & Integer'Image (Ganador) & ".");
               end Informar_Resultado;
            end select;
         end loop;
         -- Cada cancha informa antes de volver a pedir. Cuando todas recibieron
         -- fin, ya no queda ningún partido en juego ni una futura llamada.
         Put_Line ("Todos los partidos han finalizado.");
      end Coordinador;

      task body Cancha is
         Numero : Integer;
         Duracion : Integer;
         Ganador : Integer;
         Generador_Duracion : Azar_Duracion.Generator;
         Generador_Ganador : Azar_Ganador.Generator;
      begin
         -- Estado propio: las canchas no comparten ni acceden al mismo generador.
         -- Reset sin semilla explícita inicializa usando el tiempo.
         Azar_Duracion.Reset (Generador_Duracion);
         Azar_Ganador.Reset (Generador_Ganador);
         loop
            Put_Line ("Cancha" & Integer'Image (Id) & " solicita un partido.");
            -- La llamada espera al accept. Numero es out: vuelve con la respuesta.
            Coordinador.Solicitar_Partido (Id, Numero);
            exit when Numero = 0;

            Duracion := Azar_Duracion.Random (Generador_Duracion) mod 5;
            Put_Line
              ("Cancha" & Integer'Image (Id) & " disputa Partido"
               & Integer'Image (Numero) & " durante"
               & Integer'Image (Duracion) & " segundos.");
            -- Fuera del accept: el Coordinador y otras canchas siguen trabajando.
            delay Duration (Duracion);
            if Azar_Ganador.Random (Generador_Ganador) mod 2 + 1 = 1 then
               Ganador := Parejas_A (Numero);
            else
               Ganador := Parejas_B (Numero);
            end if;
            Put_Line
              ("Cancha" & Integer'Image (Id) & " finalizó Partido"
               & Integer'Image (Numero) & ". Ganador: Pareja"
               & Integer'Image (Ganador) & ".");
            -- Espera la recepción del resultado antes de solicitar otro partido.
            Coordinador.Informar_Resultado (Id, Numero, Ganador);
         end loop;
         Put_Line ("Cancha" & Integer'Image (Id) & " termina su ejecución.");
      end Cancha;

      Cancha_1 : Cancha (1);
      Cancha_2 : Cancha (2);
      Cancha_3 : Cancha (3);
   begin
      -- Las tareas se activan automáticamente. Ada espera a que terminen todas
      -- antes de retornar del procedimiento, aunque aquí solo aparezca null.
      null;
   end Ejecutar_Torneo;
begin
   -- Se definen las parejas antes de llamar al procedimiento que activa las tareas.
   for I in 1 .. Total_Partidos loop
      Parejas_A (I) := 2 * I - 1;
      Parejas_B (I) := 2 * I;
   end loop;
   Ejecutar_Torneo;
   Put_Line ("Torneo terminado.");
end Torneo;
