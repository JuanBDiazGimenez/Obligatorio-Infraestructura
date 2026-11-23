-- Torneo de padel (Parte 3): 3 tasks Cancha piden partidos a una task Coordinador mediante citas (rendezvous).
-- Compilar: gnatmake torneo_padel.adb   Ejecutar: ./torneo_padel
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Numerics.Float_Random;

procedure Torneo_Padel is

   Num_Partidos : constant := 8;   -- partido k enfrenta a las parejas 2k-1 y 2k (16 parejas)
   Num_Canchas  : constant := 3;

   task Coordinador is
      -- Devuelve el numero de partido asignado, o 0 si ya no quedan partidos pendientes.
      entry Pedir_Partido (Id_Cancha : in Positive; Partido : out Natural);
      entry Informar_Resultado (Id_Cancha : in Positive; Ganador : in Positive);
   end Coordinador;

   task type Cancha (Id : Positive);

   task body Coordinador is
      Siguiente : Positive := 1;      -- proximo partido sin asignar
      Despedidas : Natural := 0;      -- canchas a las que ya se les dijo que no quedan partidos
   begin
      while Despedidas < Num_Canchas loop
         select
            accept Pedir_Partido (Id_Cancha : in Positive; Partido : out Natural) do
               if Siguiente <= Num_Partidos then
                  Partido := Siguiente;
                  Put_Line ("Coordinador:" & ASCII.LF
                            & "Partido" & Integer'Image (Siguiente) & " asignado a Cancha" & Integer'Image (Id_Cancha) & "." & ASCII.LF
                            & "Pareja" & Integer'Image (2 * Siguiente - 1) & " vs Pareja" & Integer'Image (2 * Siguiente) & ".");
                  Siguiente := Siguiente + 1;
               else
                  Partido := 0;
                  Despedidas := Despedidas + 1;
               end if;
            end Pedir_Partido;
         or
            accept Informar_Resultado (Id_Cancha : in Positive; Ganador : in Positive) do
               Put_Line ("Coordinador recibió el resultado de Cancha" & Integer'Image (Id_Cancha)
                         & " (ganó Pareja" & Integer'Image (Ganador) & ").");
            end Informar_Resultado;
         end select;
      end loop;
      Put_Line ("Todos los partidos han finalizado.");
      Put_Line ("Torneo terminado.");
   end Coordinador;

   task body Cancha is
      use Ada.Numerics.Float_Random;
      Gen     : Generator;            -- un generador por task: no se comparte entre tasks
      Partido : Natural;
      Ganador : Positive;
   begin
      Reset (Gen, Id);
      loop
         Put_Line ("Cancha" & Integer'Image (Id) & " solicita un partido.");
         Coordinador.Pedir_Partido (Id, Partido);
         exit when Partido = 0;       -- no hay mas partidos: la cancha termina

         Put_Line ("Cancha" & Integer'Image (Id) & " está disputando el partido" & Integer'Image (Partido) & "...");
         delay Duration (Random (Gen) * 4.0);   -- duracion aleatoria, no mayor a 4 segundos

         if Random (Gen) < 0.5 then      -- el ganador se sortea entre las dos parejas del partido
            Ganador := 2 * Partido - 1;
         else
            Ganador := 2 * Partido;
         end if;
         Put_Line ("Cancha" & Integer'Image (Id) & " finalizó el partido" & Integer'Image (Partido)
                   & ". Ganador: Pareja" & Integer'Image (Ganador) & ".");
         Coordinador.Informar_Resultado (Id, Ganador);
      end loop;
   end Cancha;

   C1 : Cancha (1);
   C2 : Cancha (2);
   C3 : Cancha (3);

begin
   null;   -- el procedimiento principal espera a que terminen las tasks (Coordinador y canchas)
end Torneo_Padel;
