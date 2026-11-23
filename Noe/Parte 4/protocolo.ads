-- Protocolo de texto entre barco y puerto: una linea por mensaje, terminada en LF.
--   barco -> puerto: "SOLICITAR Barco N"   puerto -> barco: "AUTORIZADO"   barco -> puerto: "LIBERAR Barco N"
with GNAT.Sockets;

package Protocolo is
   Puerto_TCP : constant GNAT.Sockets.Port_Type := 5000;

   function Leer_Linea (Canal : GNAT.Sockets.Stream_Access) return String;
   procedure Escribir (Canal : GNAT.Sockets.Stream_Access; Texto : String);
end Protocolo;
