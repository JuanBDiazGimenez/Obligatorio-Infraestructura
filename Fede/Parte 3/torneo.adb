with Ada.Text_IO; use Ada.Text_IO;
with Ada.Numerics.Discrete_Random;

procedure Torneo is
   Total_Partidos : constant := 8;
   Total_Canchas  : constant := 3;

   subtype Id_Cancha is Integer range 1 .. Total_Canchas;
   -- Cero es la respuesta «no quedan partidos», no un encuentro adicional.
   subtype Numero_Partido is Integer range 0 .. Total_Partidos;
   subtype Id_Pareja is Integer range 1 .. 16;
   subtype Segundos is Integer range 0 .. 4;
   subtype Opcion_Ganador is Integer range 1 .. 2;

   type Partido is record
      Pareja_A : Id_Pareja;
      Pareja_B : Id_Pareja;
   end record;

   Partidos : constant array (1 .. Total_Partidos) of Partido :=
     ((1, 2), (3, 4), (5, 6), (7, 8),
      (9, 10), (11, 12), (13, 14), (15, 16));

   -- Instanciar adapta la plantilla estándar al rango que necesitamos sortear.
   package Azar_Duracion is new Ada.Numerics.Discrete_Random (Segundos);
   package Azar_Ganador is new Ada.Numerics.Discrete_Random (Opcion_Ganador);

begin
   declare
      -- El Coordinador es el único que modifica asignaciones y resultados.
      task Coordinador is
         entry Solicitar_Partido
           (Cancha : Id_Cancha; Numero : out Numero_Partido);
         entry Informar_Resultado
           (Cancha : Id_Cancha; Numero : Numero_Partido; Ganador : Id_Pareja);
      end Coordinador;

      -- Una misma definición sirve para tres tareas con identificadores distintos.
      task type Cancha (Id : Id_Cancha);

      task body Coordinador is
         Proximo : Integer range 1 .. Total_Partidos + 1 := 1;
         Terminados : Natural := 0;
         Canchas_Cerradas : Natural := 0;
         En_Juego : array (Id_Cancha) of Numero_Partido := (others => 0);
         Cerrada : array (Id_Cancha) of Boolean := (others => False);
         Ganadores : array (1 .. Total_Partidos) of Natural := (others => 0);
      begin
         -- Asignar el octavo no implica haber recibido su resultado. También
         -- debemos responder las solicitudes finales de las tres canchas.
         while Canchas_Cerradas < Total_Canchas loop
            -- Se atiende una cita por vez, de solicitud O de resultado.
            -- Un accept fijo podría esperar pedidos mientras llegan resultados.
            select
               accept Solicitar_Partido
                 (Cancha : Id_Cancha; Numero : out Numero_Partido)
               do
                  -- La cancha que llama espera hasta terminar este accept.
                  pragma Assert (En_Juego (Cancha) = 0 and not Cerrada (Cancha));
                  if Proximo <= Total_Partidos then
                     Numero := Proximo;
                     En_Juego (Cancha) := Numero;
                     Proximo := Proximo + 1;
                     Put_Line
                       ("Coordinador: Partido" & Numero_Partido'Image (Numero)
                        & " asignado a Cancha" & Id_Cancha'Image (Cancha)
                        & ". Pareja" & Id_Pareja'Image (Partidos (Numero).Pareja_A)
                        & " vs Pareja" & Id_Pareja'Image (Partidos (Numero).Pareja_B)
                        & ".");
                  else
                     Numero := 0;
                     Cerrada (Cancha) := True;
                     Canchas_Cerradas := Canchas_Cerradas + 1;
                     Put_Line
                       ("Coordinador: sin partidos pendientes para Cancha"
                        & Id_Cancha'Image (Cancha) & ".");
                  end if;
               end Solicitar_Partido;
            or
               accept Informar_Resultado
                 (Cancha : Id_Cancha; Numero : Numero_Partido; Ganador : Id_Pareja)
               do
                  -- Assert comprueba una condición; no bloquea ni sincroniza.
                  pragma Assert (Numero /= 0 and then En_Juego (Cancha) = Numero);
                  pragma Assert (Ganadores (Numero) = 0);
                  pragma Assert
                    (Ganador = Partidos (Numero).Pareja_A
                     or else Ganador = Partidos (Numero).Pareja_B);
                  Ganadores (Numero) := Ganador;
                  En_Juego (Cancha) := 0;
                  Terminados := Terminados + 1;
                  Put_Line
                    ("Coordinador recibió resultado de Cancha"
                     & Id_Cancha'Image (Cancha) & ": Partido"
                     & Numero_Partido'Image (Numero) & ", ganador Pareja"
                     & Id_Pareja'Image (Ganador) & ".");
               end Informar_Resultado;
            end select;
         end loop;
         -- Cada cancha informa antes de volver a pedir. Cuando todas recibieron
         -- fin, ya no queda ningún partido en juego ni una futura llamada.
         pragma Assert (Terminados = Total_Partidos);
         Put_Line ("Todos los partidos han finalizado.");
      end Coordinador;

      task body Cancha is
         Numero : Numero_Partido;
         Duracion : Segundos;
         Ganador : Id_Pareja;
         Generador_Duracion : Azar_Duracion.Generator;
         Generador_Ganador : Azar_Ganador.Generator;
      begin
         -- Estado propio: las canchas no comparten ni acceden al mismo generador.
         -- Reset sin semilla explícita inicializa usando el tiempo.
         Azar_Duracion.Reset (Generador_Duracion);
         Azar_Ganador.Reset (Generador_Ganador);
         loop
            Put_Line ("Cancha" & Id_Cancha'Image (Id) & " solicita un partido.");
            -- La llamada espera al accept. Numero es out: vuelve con la respuesta.
            Coordinador.Solicitar_Partido (Id, Numero);
            exit when Numero = 0;

            Duracion := Azar_Duracion.Random (Generador_Duracion);
            Put_Line
              ("Cancha" & Id_Cancha'Image (Id) & " disputa Partido"
               & Numero_Partido'Image (Numero) & " durante"
               & Segundos'Image (Duracion) & " segundos.");
            -- Fuera del accept: el Coordinador y otras canchas siguen trabajando.
            delay Duration (Duracion);
            if Azar_Ganador.Random (Generador_Ganador) = 1 then
               Ganador := Partidos (Numero).Pareja_A;
            else
               Ganador := Partidos (Numero).Pareja_B;
            end if;
            Put_Line
              ("Cancha" & Id_Cancha'Image (Id) & " finalizó Partido"
               & Numero_Partido'Image (Numero) & ". Ganador: Pareja"
               & Id_Pareja'Image (Ganador) & ".");
            -- Espera la recepción del resultado antes de solicitar otro partido.
            Coordinador.Informar_Resultado (Id, Numero, Ganador);
         end loop;
         Put_Line ("Cancha" & Id_Cancha'Image (Id) & " termina su ejecución.");
      end Cancha;

      Cancha_1 : Cancha (1);
      Cancha_2 : Cancha (2);
      Cancha_3 : Cancha (3);
   begin
      -- Las tareas se activan automáticamente. Ada espera a que terminen todas
      -- antes de abandonar este bloque, aunque aquí solo aparezca null.
      null;
   end;
   Put_Line ("Torneo terminado.");
end Torneo;
