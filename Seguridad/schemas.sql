use gimnasio;
go
-- esquemas por funcion / area del negocio (propietario dbo)
create schema socios      authorization dbo;
go
create schema ventas      authorization dbo;
go
create schema personal    authorization dbo;
go
create schema operaciones authorization dbo;
go
create schema reportes authorization dbo;
go
 
-- socios
alter schema socios transfer dbo.socio;
alter schema socios transfer dbo.contacto_emergencia;
-- ventas
alter schema ventas transfer dbo.plan_membresia;
alter schema ventas transfer dbo.membresia;
alter schema ventas transfer dbo.pago;
-- personal
alter schema personal transfer dbo.entrenador;
alter schema personal transfer dbo.especialidad;
alter schema personal transfer dbo.entrenador_especialidad;
-- operaciones
alter schema operaciones transfer dbo.sala;
alter schema operaciones transfer dbo.tipo_clase;
alter schema operaciones transfer dbo.clase;
alter schema operaciones transfer dbo.reserva;

-- procedimientos
alter schema operaciones transfer dbo.sp_cancelar_reserva;
alter schema operaciones transfer dbo.sp_clases_por_fecha;
alter schema ventas transfer dbo.sp_ingresos_por_mes;
go
