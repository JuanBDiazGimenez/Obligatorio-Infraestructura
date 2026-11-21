with Ada.Text_IO; use Ada.Text_IO;
with Mensajeria;

procedure Receptor is
begin
   Put_Line ("Esperando mensaje (hasta diez segundos)...");
   Put_Line ("Recibido: " & Mensajeria.Recibir);
end Receptor;
