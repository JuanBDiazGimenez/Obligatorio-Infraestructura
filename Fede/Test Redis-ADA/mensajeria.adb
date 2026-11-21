with Ada.Characters.Latin_1;
with Ada.Real_Time;
with GNAT.Expect;
with GNAT.OS_Lib;

package body Mensajeria is
   Cola : constant String := "infra:test:redis_ada:mensajes";

   function Ejecutar (Operacion, Dato : String) return String is
      -- Argumentos separados: no se construye una orden para un shell.
      Argumentos : GNAT.OS_Lib.Argument_List :=
        (new String'("-h"), new String'("infra-test-redis-ada"),
         new String'("-p"), new String'("6739"),
         new String'("--raw"), new String'("-e"),
         new String'(Operacion), new String'(Cola), new String'(Dato));
      Estado : aliased Integer;
      Ultimo_Argumento : Positive := Argumentos'Last;
   begin
      -- LPOP recibe solo la clave. RPUSH también recibe el mensaje.
      if Operacion = "LPOP" then
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
   exception
      when others =>
         -- Free deja cada acceso en null: también sirve si ya fue liberado.
         for Argumento of Argumentos loop
            GNAT.OS_Lib.Free (Argumento);
         end loop;
         raise;
   end Ejecutar;

   procedure Enviar (Mensaje : String) is
   begin
      if Mensaje'Length = 0 then
         raise Error_Comunicacion with "El mensaje no puede estar vacio";
      end if;
      declare
         Respuesta : constant String := Ejecutar ("RPUSH", Mensaje);
         Cantidad : constant Integer := Integer'Value (Respuesta);
      begin
         if Cantidad < 1 then
            raise Error_Comunicacion with "Respuesta RPUSH inesperada";
         end if;
      end;
   end Enviar;

   function Recibir return String is
      use type Ada.Real_Time.Time;
      -- El reloj monotónico limita esta prueba, sin depender de la hora del día.
      Limite : constant Ada.Real_Time.Time :=
        Ada.Real_Time.Clock + Ada.Real_Time.Seconds (10);
   begin
      loop
         declare
            -- LPOP retira atómicamente un mensaje; si no hay, vuelve vacío.
            Respuesta : constant String := Ejecutar ("LPOP", "");
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
         if Ada.Real_Time.Clock >= Limite then
            raise Tiempo_Agotado with "No llego un mensaje en diez segundos";
         end if;
         -- Se suspende el proceso Ada antes de volver a consultar Redis.
         delay 0.1;
      end loop;
   end Recibir;
end Mensajeria;
