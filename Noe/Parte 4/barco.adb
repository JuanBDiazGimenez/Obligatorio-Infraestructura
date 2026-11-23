-- Microservicio BARCO: navega, pide el atracadero al puerto, lo usa, lo libera y vuelve a navegar.
-- Uso: barco <numero> <host_del_puerto>
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Command_Line;
with Ada.Numerics.Float_Random;
with GNAT.Sockets; use GNAT.Sockets;
with Protocolo;

procedure Barco is
   use Ada.Numerics.Float_Random;

   Numero : constant String := Ada.Command_Line.Argument (1);
   Host   : constant String := Ada.Command_Line.Argument (2);
   Nombre : constant String := "Barco " & Numero;
   Gen    : Generator;

   function Aleatorio (Min, Max : Float) return Duration is
     (Duration (Min + Random (Gen) * (Max - Min)));

   -- Conecta con el puerto; si todavia no esta escuchando (arranque de los contenedores) reintenta.
   procedure Conectar (Socket : out Socket_Type) is
      Direccion : Sock_Addr_Type;
   begin
      loop
         begin
            Create_Socket (Socket);
            Direccion := (Family_Inet, Addresses (Get_Host_By_Name (Host), 1), Protocolo.Puerto_TCP);
            Connect_Socket (Socket, Direccion);
            return;
         exception
            when Socket_Error | Host_Error =>
               Close_Socket (Socket);
               delay 1.0;
         end;
      end loop;
   end Conectar;

   Socket : Socket_Type;
begin
   Reset (Gen, Integer'Value (Numero));
   loop
      Put_Line (Nombre & " navegando...");
      delay Aleatorio (1.0, 5.0);

      Put_Line (Nombre & " solicita acceso al atracadero.");
      Conectar (Socket);
      declare
         Canal : constant Stream_Access := Stream (Socket);
      begin
         Protocolo.Escribir (Canal, "SOLICITAR " & Nombre);
         if Protocolo.Leer_Linea (Canal) = "AUTORIZADO" then     -- se queda esperando hasta que lo autoricen
            Put_Line (Nombre & " recibió autorización: INGRESA al atracadero.");
            delay Aleatorio (1.0, 3.0);
            Put_Line (Nombre & " abandona el atracadero.");
            Protocolo.Escribir (Canal, "LIBERAR " & Nombre);
         end if;
      end;
      Close_Socket (Socket);
      Put_Line (Nombre & " vuelve a navegar...");
   end loop;
end Barco;
