with Ada.Command_Line;
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Numerics.Discrete_Random;
with Mensajeria; use Mensajeria;

procedure Barco is
   subtype Segundos is Integer range 1 .. 3;
   package Azar is new Ada.Numerics.Discrete_Random (Segundos);
   Generador : Azar.Generator;
   Id : Id_Barco;
   Tiempo : Segundos;
begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Put_Line ("Uso: barco <identificador 1..3>");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   Id := Id_Barco'Value (Ada.Command_Line.Argument (1));
   Azar.Reset (Generador);
   loop
      Tiempo := Azar.Random (Generador);
      Put_Line ("BARCO" & Id_Barco'Image (Id) & " NAVEGA" & Segundos'Image (Tiempo));
      delay Duration (Tiempo);
      Put_Line ("BARCO" & Id_Barco'Image (Id) & " SOLICITA");
      Enviar (Eventos, "SOLICITAR" & Id_Barco'Image (Id));
      -- Espera en su buzon individual con LPOP y pausas de 100 ms.
      -- No consulta si el atracadero esta libre: recibe una reserva exclusiva.
      declare
         Permiso : constant String := Recibir (Buzon (Id));
      begin
         null;
      end;
      Tiempo := Azar.Random (Generador);
      Put_Line ("BARCO" & Id_Barco'Image (Id) & " ENTRA" & Segundos'Image (Tiempo));
      delay Duration (Tiempo);
      Put_Line ("BARCO" & Id_Barco'Image (Id) & " SALE");
      Enviar (Eventos, "LIBERAR" & Id_Barco'Image (Id));
   end loop;
end Barco;
