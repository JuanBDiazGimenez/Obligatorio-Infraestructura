-- Microservicio PUERTO: dueno del atracadero. Atiende a los barcos por TCP (puerto 5000).
with Ada.Text_IO; use Ada.Text_IO;
with GNAT.Sockets; use GNAT.Sockets;
with Protocolo;

procedure Puerto is

   -- El atracadero es un objeto protegido: la barrera "when Libre" deja pasar de a uno.
   -- Los barcos que esperan quedan encolados en la entry, en orden de llegada (FIFO).
   protected Atracadero is
      entry Ocupar (En_Uso : out Natural);
      procedure Liberar;
   private
      Libre    : Boolean := True;
      Ocupados : Natural := 0;     -- cuantos barcos lo usan; nunca debe superar 1
   end Atracadero;

   protected body Atracadero is
      entry Ocupar (En_Uso : out Natural) when Libre is
      begin
         Libre := False;
         Ocupados := Ocupados + 1;
         En_Uso := Ocupados;
      end Ocupar;

      procedure Liberar is
      begin
         Ocupados := Ocupados - 1;
         Libre := True;
      end Liberar;
   end Atracadero;

   -- Una task por conexion: asi un barco esperando no bloquea la atencion de los demas.
   task type Atender is
      entry Iniciar (Cliente : Socket_Type);
   end Atender;

   task body Atender is
      Socket    : Socket_Type;
      Tiene     : Boolean := False;   -- este barco tiene el atracadero
      En_Uso    : Natural;
   begin
      accept Iniciar (Cliente : Socket_Type) do
         Socket := Cliente;
      end Iniciar;
      declare
         Canal  : constant Stream_Access := Stream (Socket);
         Pedido : constant String := Protocolo.Leer_Linea (Canal);   -- "SOLICITAR Barco N"
         Barco  : constant String := Pedido (Pedido'First + 10 .. Pedido'Last);
      begin
         Put_Line ("[puerto] " & Barco & " solicita acceso.");
         Atracadero.Ocupar (En_Uso);
         Tiene := True;
         Put_Line ("[puerto] AUTORIZA a " & Barco & " (barcos en el atracadero:" & Natural'Image (En_Uso) & ")");
         Protocolo.Escribir (Canal, "AUTORIZADO");

         declare
            Aviso : constant String := Protocolo.Leer_Linea (Canal);  -- "LIBERAR Barco N"
            pragma Unreferenced (Aviso);
         begin
            Atracadero.Liberar;
            Tiene := False;
            Put_Line ("[puerto] " & Barco & " libera el atracadero.");
         end;
      end;
      Close_Socket (Socket);
   exception
      when others =>
         -- Si el barco se cae con el atracadero tomado, se libera para no trabar a los demas.
         if Tiene then
            Atracadero.Liberar;
            Put_Line ("[puerto] conexion perdida: atracadero liberado.");
         end if;
         Close_Socket (Socket);
   end Atender;

   type Atender_Acc is access Atender;

   Servidor  : Socket_Type;
   Cliente   : Socket_Type;
   Direccion : Sock_Addr_Type;
   Tarea     : Atender_Acc;
begin
   Create_Socket (Servidor);
   Set_Socket_Option (Servidor, Socket_Level, (Reuse_Address, True));
   Bind_Socket (Servidor, (Family_Inet, Any_Inet_Addr, Protocolo.Puerto_TCP));
   Listen_Socket (Servidor);
   Put_Line ("[puerto] atracadero libre, escuchando en el puerto" & Port_Type'Image (Protocolo.Puerto_TCP));
   loop
      Accept_Socket (Servidor, Cliente, Direccion);
      Tarea := new Atender;   -- shortcut: las tasks terminadas no se liberan (alcanza para la demo)
      Tarea.Iniciar (Cliente);
   end loop;
end Puerto;
