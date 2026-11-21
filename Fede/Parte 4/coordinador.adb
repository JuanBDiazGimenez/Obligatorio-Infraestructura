with Ada.Text_IO; use Ada.Text_IO;
with Ada.Strings.Fixed;
with Mensajeria; use Mensajeria;

procedure Coordinador is
   type Estado_Barco is (Navegando, Esperando, Autorizado);
   Estados : array (Id_Barco) of Estado_Barco := (others => Navegando);
   Pendientes : array (1 .. 3) of Id_Barco;
   Entrada, Salida : Positive range 1 .. 3 := 1;
   Cantidad : Natural range 0 .. 3 := 0;
   -- Cero indica libre. Solo este proceso puede modificarlo.
   Ocupante : Natural range 0 .. 3 := 0;
begin
   Preparar;
   Put_Line ("PUERTO LISTO");
   loop
      declare
         Mensaje : constant String := Recibir (Eventos);
         Separador : constant Natural := Ada.Strings.Fixed.Index (Mensaje, " ");
         Accion : constant String := Mensaje (Mensaje'First .. Separador - 1);
         Id : constant Id_Barco := Id_Barco'Value
           (Mensaje (Separador + 1 .. Mensaje'Last));
      begin
         if Accion = "SOLICITAR" then
            pragma Assert (Estados (Id) = Navegando);
            Put_Line ("SOLICITUD" & Id_Barco'Image (Id));
            Estados (Id) := Esperando;
            Pendientes (Entrada) := Id;
            Entrada := Entrada mod 3 + 1;
            Cantidad := Cantidad + 1;
         elsif Accion = "LIBERAR" then
            pragma Assert (Ocupante = Id and Estados (Id) = Autorizado);
            Put_Line ("LIBERACION" & Id_Barco'Image (Id));
            Ocupante := 0;
            Estados (Id) := Navegando;
         else
            raise Program_Error with "Evento desconocido";
         end if;

         -- Nunca esperamos la liberacion dentro de la atencion de un pedido:
         -- guardamos el pendiente y seguimos recibiendo eventos de todos.
         if Ocupante = 0 and Cantidad > 0 then
            declare
               Siguiente : constant Id_Barco := Pendientes (Salida);
            begin
               Salida := Salida mod 3 + 1;
               Cantidad := Cantidad - 1;
               -- La reserva se realiza ANTES de poner el permiso en el buzon.
               Ocupante := Siguiente;
               Estados (Siguiente) := Autorizado;
               Put_Line ("AUTORIZACION" & Id_Barco'Image (Siguiente));
               Enviar (Buzon (Siguiente), "AUTORIZADO");
            end;
         end if;
      end;
   end loop;
end Coordinador;
