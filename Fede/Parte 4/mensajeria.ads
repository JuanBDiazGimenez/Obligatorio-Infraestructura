package Mensajeria is
   subtype Id_Barco is Positive range 1 .. 3;
   Eventos : constant String := "puerto:eventos";
   Error_Comunicacion : exception;
   function Buzon (Id : Id_Barco) return String;
   procedure Enviar (Cola, Mensaje : String);
   function Recibir (Cola : String) return String;
   procedure Preparar;
end Mensajeria;
