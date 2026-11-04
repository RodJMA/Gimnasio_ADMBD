-- ============================================================================
-- gimnasio | usuarios, roles y permisos 
-- ============================================================================
-- 1. contencion (servidor y base)
use master;
go
exec sp_configure 'contained database authentication', 1;
reconfigure;
go
alter database gimnasio set containment = partial;
go

use gimnasio;
go

-- 2. usuarios contenidos 
-- rotacion manual: alter user usr_recepcion with password = '<clave nueva>';
-- minimo usado: 14 caracteres con mayuscula, minuscula, digito y simbolo
create user usr_admin       with password = 'Adm!n-Gym#2026-Xk7';
create user usr_recepcion   with password = 'Recep!Gym#2026-Qm4';
create user usr_entrenador  with password = 'Entre!Gym#2026-Tz9';
create user usr_coordinador with password = 'Coord!Gym#2026-Bw3';
create user usr_analista_bi with password = 'Bi!Gym#2026-Lp8-Rv5';
create user usr_profesor    with password = 'Profe!Gym#2026-Hn6';
go

-- 3. roles por funcion 
-- profesor usa rol fijo (db_datareader)
create role rol_administracion;
create role rol_recepcionista;
create role rol_entrenador;
create role rol_coordinador;
create role rol_analista_bi;
go

-- 4. membresias 
alter role rol_administracion add member usr_admin;
alter role rol_recepcionista  add member usr_recepcion;
alter role rol_entrenador     add member usr_entrenador;
alter role rol_coordinador    add member usr_coordinador;
alter role rol_analista_bi    add member usr_analista_bi;
alter role db_datareader      add member usr_profesor;   -- solo lectura en todas las tablas
go


-- 5. permisos
-- 5.1 rol_administracion: supervisa el negocio y administra catalogos, personal y anulaciones
--     no es db_owner: no crea ni modifica objetos, usuarios, roles ni permisos
grant select on schema::socios      to rol_administracion;
grant select on schema::ventas      to rol_administracion;
grant select on schema::personal    to rol_administracion;
grant select on schema::operaciones to rol_administracion;
grant select on schema::reportes    to rol_administracion;
grant insert, update on ventas.plan_membresia to rol_administracion;   -- catalogo de planes
grant update (estado) on ventas.pago to rol_administracion;            -- confirmar un pago pendiente o anularlo (monto y comprobante no se editan)
grant insert, update on personal.entrenador to rol_administracion;     -- el entrenador se da de baja por estado, no se borra
grant insert, update on personal.especialidad to rol_administracion;
grant insert, update, delete on personal.entrenador_especialidad to rol_administracion; -- asignacion especialidad-entrenador
grant execute on ventas.sp_ingresos_por_mes      to rol_administracion;
grant execute on operaciones.sp_clases_por_fecha to rol_administracion;
grant execute on operaciones.sp_cancelar_reserva to rol_administracion;
 
-- 5.2 rol_recepcionista: registra socios, vende membresias y cobra; nunca borra
grant select, insert, update on socios.socio to rol_recepcionista;
grant select, insert, update on socios.contacto_emergencia to rol_recepcionista;
grant select on ventas.plan_membresia to rol_recepcionista;      -- el catalogo lo administra la administracion
grant select, insert on ventas.membresia to rol_recepcionista;
grant update (estado) on ventas.membresia to rol_recepcionista;  -- plan y fechas no se editan (renovar = fila nueva)
grant select, insert on ventas.pago to rol_recepcionista;        -- un pago no se modifica: se registra ya como PAGADO (confirmar pendientes o anular = administracion)
grant select on schema::operaciones to rol_recepcionista;        -- consulta agenda
grant execute on operaciones.sp_clases_por_fecha to rol_recepcionista;
grant insert on operaciones.reserva to rol_recepcionista;               -- crea reservas; cancelar solo por procedimiento
grant execute on operaciones.sp_cancelar_reserva to rol_recepcionista;
 
-- 5.3 rol_entrenador (entidad personal.entrenador): consulta su operacion y marca asistencia
--     trabaja sobre el esquema operaciones; no tiene acceso a personal, ventas ni contactos de emergencia
grant select (id_socio, nombre, apellido, fecha_nacimiento, estado) on socios.socio to rol_entrenador; -- sin dui, telefono, correo
grant select on schema::operaciones to rol_entrenador;
grant execute on operaciones.sp_clases_por_fecha     to rol_entrenador;
grant update (estado) on operaciones.reserva to rol_entrenador;          -- marca asistencia (clase: la cierra el coordinador)
 
-- 5.4 rol_coordinador: programa la agenda; no borra; reservas via procedimientos
grant select on schema::operaciones to rol_coordinador;
grant insert, update on operaciones.sala to rol_coordinador;
grant insert, update on operaciones.tipo_clase to rol_coordinador;
grant insert, update on operaciones.clase to rol_coordinador;    -- las clases se cancelan, no se borran
grant execute on operaciones.sp_clases_por_fecha to rol_coordinador;
grant execute on operaciones.sp_cancelar_reserva to rol_coordinador;
grant select (id_entrenador, nombre, apellido, fecha_contratacion, estado) on personal.entrenador to rol_coordinador; -- sin dui, telefono, correo
grant select on personal.especialidad to rol_coordinador;
grant select on personal.entrenador_especialidad to rol_coordinador;
 
-- 5.5 rol_analista_bi: solo lee el esquema reportes (vistas sin datos personales, pendientes de crear)
grant select on schema::reportes to rol_analista_bi;
-- refuerzo: aunque lo agreguen a otro rol, las tablas base siguen bloqueadas
-- (las vistas funcionaran por la cadena de propiedad)
deny select on schema::socios      to rol_analista_bi;
deny select on schema::ventas      to rol_analista_bi;
deny select on schema::personal    to rol_analista_bi;
deny select on schema::operaciones to rol_analista_bi;
go
 
-- 6. verificacion (consultas sobre sys.database_principals)
select name as base_de_datos, containment_desc as contencion
from sys.databases where name = 'gimnasio';
 
-- usuarios contenidos (authentication_type 2 = password guardada en la base)
select name as usuario, type_desc, authentication_type_desc
from sys.database_principals
where type = 'S' and authentication_type = 2
order by name;
 
-- roles y miembros
select r.name as rol, m.name as miembro
from sys.database_role_members rm
join sys.database_principals r on r.principal_id = rm.role_principal_id
join sys.database_principals m on m.principal_id = rm.member_principal_id
where r.name like 'rol[_]%' or r.name = 'db_datareader'
order by r.name, m.name;
 
-- permisos otorgados y negados a los roles propios
select pr.name as rol, p.state_desc as estado, p.permission_name as permiso,
       case p.class when 3 then 'schema::' + schema_name(p.major_id)
                    when 1 then object_schema_name(p.major_id) + '.' + object_name(p.major_id)
                    else 'database' end as elemento,
       case when p.class = 1 and p.minor_id > 0 then col_name(p.major_id, p.minor_id) end as columna
from sys.database_permissions p
join sys.database_principals pr on pr.principal_id = p.grantee_principal_id
where pr.name like 'rol[_]%'
order by pr.name, elemento, p.permission_name;
go
 
-- 7. pruebas con execute as user / revert
-- cada usuario: primero lo permitido, luego lo negado (error 229 o 230; el script sigue).
-- los "update x = x" no modifican nada; los delete llevan where 1 = 0 por seguridad.
-- los exec de procedimientos con parametros: agregar los parametros que correspondan.
 
-- 7.1 administracion
execute as user = 'usr_admin';
select top (3) * from ventas.pago;                                        -- permitido
select top (3) * from socios.socio;                                       -- permitido
update ventas.pago set estado = estado where id_pago = 1;                 -- permitido (sin cambio real)
update ventas.plan_membresia set precio = precio where id_plan = 1;       -- permitido (sin cambio real)
update ventas.pago set monto = monto where id_pago = 1;                   -- negado: el monto no se edita
update socios.socio set nombre = nombre where id_socio = 1;               -- negado: los socios los gestiona recepcion
delete from ventas.pago where 1 = 0;                                      -- negado: sin DELETE
create table dbo.prueba_admin (id int);                                   -- negado: no es db_owner
revert;
 
-- 7.2 recepcion
execute as user = 'usr_recepcion';
select top (3) * from socios.socio;                                       -- permitido
update ventas.membresia set estado = estado where id_membresia = 1;       -- permitido (sin cambio real)
update operaciones.reserva set estado = estado where id_clase = 1;        -- negado: cancelar solo por sp_cancelar_reserva
delete from socios.socio where 1 = 0;                                     -- negado: sin DELETE
update ventas.pago set estado = estado where id_pago = 1;                 -- negado: anular = administracion
update ventas.membresia set fecha_fin = fecha_fin where id_membresia = 1; -- negado: solo cambia estado
update ventas.plan_membresia set precio = precio where id_plan = 1;       -- negado: catalogo = administracion
select top (3) * from personal.entrenador;                                -- negado: sin acceso a personal
revert;
 
-- 7.3 entrenador
execute as user = 'usr_entrenador';
select top (3) id_socio, nombre, apellido from socios.socio;              -- permitido
select top (3) * from operaciones.clase;                                  -- permitido
select top (3) dui from socios.socio;                                     -- negado: columna restringida
select top (3) * from socios.socio;                                       -- negado: el * incluye columnas restringidas
select top (3) * from ventas.pago;                                        -- negado: sin acceso a ventas
select top (3) * from personal.entrenador;                                -- negado: sin acceso a personal
select top (3) * from socios.contacto_emergencia;                         -- negado: sin acceso
update operaciones.reserva set estado = estado where id_clase = 1;        -- permitido (sin cambio real)
insert into operaciones.reserva (id_socio, id_clase) values (1, 1);       -- negado: no crea reservas
update operaciones.clase set estado = estado where id_clase = 1;          -- negado: la clase la gestiona el coordinador
revert;

-- 7.4 coordinador
execute as user = 'usr_coordinador';
select top (3) * from operaciones.clase;                                  -- permitido
update operaciones.clase set cupo_max = cupo_max where id_clase = 1;      -- permitido (sin cambio real)
delete from operaciones.clase where 1 = 0;                                -- negado: las clases se cancelan
update operaciones.reserva set estado = estado where id_clase = 1;        -- negado: reservas por procedimientos
select top (3) dui from personal.entrenador;                              -- negado: columna restringida
select top (3) * from ventas.pago;                                        -- negado: sin acceso a ventas
revert;
 
-- 7.5 analista BI (las pruebas de lectura sobre reportes se agregan cuando existan las vistas)
execute as user = 'usr_analista_bi';
select top (5) * from socios.socio;                                       -- negado: tabla base
select top (5) * from ventas.pago;                                        -- negado: tabla base
select top (5) * from personal.entrenador;                                -- negado: tabla base
revert;
 
-- 7.6 profesor
execute as user = 'usr_profesor';
select top (3) * from socios.socio;                                       -- permitido
select top (3) * from ventas.pago;                                        -- permitido
update socios.socio set nombre = nombre where id_socio = 1;               -- negado: solo lectura
delete from operaciones.clase where 1 = 0;                                -- negado: solo lectura
revert;
go
 