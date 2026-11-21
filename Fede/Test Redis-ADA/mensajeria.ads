package Mensajeria is
   Error_Comunicacion : exception;
   Tiempo_Agotado : exception;

   procedure Enviar (Mensaje : String);
   function Recibir return String;
end Mensajeria;
