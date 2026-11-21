with Ada.Command_Line;
with Ada.Text_IO; use Ada.Text_IO;
with Mensajeria;

procedure Emisor is
begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Put_Line ("Uso: ./emisor 'mensaje'");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   Mensajeria.Enviar (Ada.Command_Line.Argument (1));
   Put_Line ("Enviado: " & Ada.Command_Line.Argument (1));
end Emisor;
