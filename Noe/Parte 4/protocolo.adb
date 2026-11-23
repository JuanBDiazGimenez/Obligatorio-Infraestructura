package body Protocolo is

   -- Lee caracteres hasta el LF. Si el otro extremo cierra la conexion, Character'Read levanta End_Error.
   function Leer_Linea (Canal : GNAT.Sockets.Stream_Access) return String is
      Linea : String (1 .. 100);
      N     : Natural := 0;
      C     : Character;
   begin
      loop
         Character'Read (Canal, C);
         exit when C = ASCII.LF;
         if N < Linea'Last then
            N := N + 1;
            Linea (N) := C;
         end if;
      end loop;
      return Linea (1 .. N);
   end Leer_Linea;

   procedure Escribir (Canal : GNAT.Sockets.Stream_Access; Texto : String) is
   begin
      String'Write (Canal, Texto & ASCII.LF);
   end Escribir;

end Protocolo;
