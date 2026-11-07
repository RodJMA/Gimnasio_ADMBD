-- ============================================================================
-- gimnasio / auditoria 
-- Requisitos: ejecutar antes schemas.sql y seguridad.sql
-- Los logs se guardan en /audit/gimnasio_audit/
-- ============================================================================

-- 1. auditoria de servidor
use master;
go

create server audit audit_gimnasio
to file (filepath = N'/audit/gimnasio_audit/', maxsize = 50 mb, max_rollover_files = 10)
with (queue_delay = 1000, on_failure = continue);
go
alter server audit audit_gimnasio with (state = on);
go
select name, status_desc, audit_file_path from sys.dm_server_audit_status;

-- 2. especificacion de servidor: logins y roles de servidor
create server audit specification spec_srv_gimnasio
for server audit audit_gimnasio
    add (failed_login_group),
    add (successful_login_group),
    add (server_role_member_change_group)
with (state = on);
go

-- 3. especificacion de base de datos
use gimnasio;
go
create database audit specification spec_db_gimnasio
for server audit audit_gimnasio
    -- usuarios contenidos
    add (failed_database_authentication_group),
    add (successful_database_authentication_group),
    -- cambios de seguridad
    add (database_principal_change_group),             -- create/alter/drop user y role
    add (database_role_member_change_group),           -- add/drop member
    add (database_permission_change_group),            -- grant/deny/revoke a nivel base
    add (schema_object_permission_change_group),       -- grant/deny/revoke sobre esquemas y objetos
    add (schema_object_change_group),                  -- create/alter/drop objetos
    -- datos sensibles
    add (update, delete on schema::ventas   by public),
    add (update, delete on schema::socios   by public),
    add (update, delete on schema::personal by public)
with (state = on);
go

-- 4. eventos de prueba (registros para la evidencia)
update ventas.pago set estado = estado where id_pago = 1;
update socios.socio set nombre = nombre where id_socio = 1;
create role rol_prueba_auditoria;
drop role rol_prueba_auditoria;
-- login fallido: conectarse como usr_recepcion con una contrasena incorrecta
-- y ejecutar las pruebas execute as de seguridad.sql
--Estas 4 lineas solo funcionan si ya existe rol_coordinador y usr_profesor
grant select on schema::reportes to rol_coordinador;
revoke select on schema::reportes from rol_coordinador;
alter role rol_coordinador add member usr_profesor;
alter role rol_coordinador drop member usr_profesor;
go

-- 5. consulta del log
declare @patron nvarchar(300) = N'/audit/gimnasio_audit/*.sqlaudit';
select event_time, action_id, succeeded, server_principal_name,
       database_principal_name, database_name, schema_name, object_name, statement
from sys.fn_get_audit_file(@patron, default, default)
order by event_time desc;
go

-- 5.1 solo logins de usuarios de la base y logins fallidos de servidor
select event_time, action_id, succeeded, server_principal_name,
       database_principal_name, statement
from sys.fn_get_audit_file(N'/audit/gimnasio_audit/*.sqlaudit', default, default)
where action_id in ('DBAS','DBAF','LGIF','LGIS')
  and statement not like 'Network error%'
  and (server_principal_name like 'usr[_]%'
    or database_principal_name like 'usr[_]%'
    or action_id in ('DBAF','LGIF'))
order by event_time desc;
go

-- 5.2 cambios de seguridad y de datos 
select event_time, action_id, succeeded, database_principal_name,
       schema_name, object_name, statement
from sys.fn_get_audit_file(N'/audit/gimnasio_audit/*.sqlaudit', default, default)
where action_id not in ('LGIS','LGIF','DBAS','DBAF')
order by event_time desc;
go

-- 6. verificacion de la configuracion
use gimnasio;
go

select name, status_desc, audit_file_path from sys.dm_server_audit_status
where name = 'audit_gimnasio';
select name, is_state_enabled, type_desc from sys.server_audits
where name = 'audit_gimnasio';
select name, is_state_enabled from sys.server_audit_specifications;
select name, is_state_enabled from sys.database_audit_specifications;
go
