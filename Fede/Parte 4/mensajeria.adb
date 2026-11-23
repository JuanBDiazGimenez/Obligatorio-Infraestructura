with Ada.Characters.Latin_1;
with Ada.Strings.Fixed;
with Ada.Strings;
with GNAT.Expect;
with GNAT.OS_Lib;

package body Mensajeria is

   function Ejecutar (Operacion, Cola : String; Dato : String := "") return String is
      -- Argumentos separados: no se construye una orden para un shell.
      Argumentos : GNAT.OS_Lib.Argument_List :=
        (new String'("-h"), new String'("redis"),
         new String'("-p"), new String'("6739"),
         new String'("--raw"), new String'("-e"),
         new String'(Operacion), new String'(Cola), new String'(Dato));
      Estado : aliased Integer;
      Ultimo_Argumento : Positive := Argumentos'Last;
   begin
      -- LPOP recibe solo la clave. RPUSH también recibe el mensaje.
      if Operacion /= "RPUSH" and Operacion /= "SET" then
         Ultimo_Argumento := 8;
      end if;
      declare
         -- La salida viaja por un pipe y vuelve como String en memoria.
         Salida : constant String := GNAT.Expect.Get_Command_Output
           (Command => "/usr/bin/redis-cli",
            Arguments => Argumentos (1 .. Ultimo_Argumento),
            Input => "", Status => Estado'Access, Err_To_Out => True);
      begin
         for Argumento of Argumentos loop
            GNAT.OS_Lib.Free (Argumento);
         end loop;
         if Estado /= 0 then
            raise Error_Comunicacion with Salida;
         end if;
         return Salida;
      end;
   end Ejecutar;

   procedure Enviar (Cola, Mensaje : String) is
      Respuesta_Ignorada : constant String := Ejecutar ("RPUSH", Cola, Mensaje);
   begin
      null;
   end Enviar;

   function Recibir (Cola : String) return String is
   begin
      loop
         declare
            Respuesta : constant String := Ejecutar ("LPOP", Cola);
            Ultimo : Integer := Respuesta'Last;
         begin
            while Ultimo >= Respuesta'First and then
              (Respuesta (Ultimo) = Ada.Characters.Latin_1.LF
               or else Respuesta (Ultimo) = Ada.Characters.Latin_1.CR)
            loop
               Ultimo := Ultimo - 1;
            end loop;
            if Ultimo >= Respuesta'First then
               return Respuesta (Respuesta'First .. Ultimo);
            end if;
         end;
         -- Una consulta sin mensaje no es un error ni consume una autorizacion.
         delay 0.1;
      end loop;
   end Recibir;

   function Buzon (Id : Id_Barco) return String is
   begin
      return "puerto:permiso:" & Ada.Strings.Fixed.Trim
        (Id_Barco'Image (Id), Ada.Strings.Both);
   end Buzon;

   procedure Preparar is
      procedure Borrar (Clave : String) is
         Respuesta_Ignorada : constant String := Ejecutar ("DEL", Clave);
      begin
         null;
      end Borrar;
   begin
      -- Solo el Coordinador, antes de que arranquen los barcos. Nunca FLUSHALL.
      Borrar ("puerto:listo");
      Borrar (Eventos);
      for Id in Id_Barco loop
         Borrar (Buzon (Id));
      end loop;
      declare
         Respuesta_Ignorada : constant String := Ejecutar ("SET", "puerto:listo", "1");
      begin
         null;
      end;
   end Preparar;
end Mensajeria;
