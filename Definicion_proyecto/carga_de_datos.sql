-- ============================================================================
-- sistema de reservas de gimnasio | carga de datos generados con mockaroo
-- ============================================================================

bulk insert plan_membresia
from '/var/opt/mssql/mockaroo/plan_membresia.csv'
with (format = 'csv', firstrow = 2, fieldterminator = ',',
      keepidentity, keepnulls, check_constraints);
go
 
bulk insert especialidad
from '/var/opt/mssql/mockaroo/especialidad.csv'
with (format = 'csv', firstrow = 2, fieldterminator = ',',
      keepidentity, keepnulls, check_constraints);
go
 
bulk insert sala
from '/var/opt/mssql/mockaroo/sala.csv'
with (format = 'csv', firstrow = 2, fieldterminator = ',',
      keepidentity, keepnulls, check_constraints);
go
 
bulk insert entrenador
from '/var/opt/mssql/mockaroo/entrenador.csv'
with (format = 'csv', firstrow = 2, fieldterminator = ',',
      keepidentity, keepnulls, check_constraints);
go
 
bulk insert socio
from '/var/opt/mssql/mockaroo/socio.csv'
with (format = 'csv', firstrow = 2, fieldterminator = ',',
      keepidentity, keepnulls, check_constraints);
go
 

bulk insert tipo_clase
from '/var/opt/mssql/mockaroo/tipo_clase.csv'
with (format = 'csv', firstrow = 2, fieldterminator = ',',
      keepidentity, keepnulls, check_constraints);
go
 
bulk insert entrenador_especialidad
from '/var/opt/mssql/mockaroo/entrenador_especialidad.csv'
with (format = 'csv', firstrow = 2, fieldterminator = ',',
      keepidentity, keepnulls, check_constraints);
go
 
bulk insert contacto_emergencia
from '/var/opt/mssql/mockaroo/contacto_emergencia.csv'
with (format = 'csv', firstrow = 2, fieldterminator = ',',
      keepidentity, keepnulls, check_constraints);
go
 
bulk insert membresia
from '/var/opt/mssql/mockaroo/membresia.csv'
with (format = 'csv', firstrow = 2, fieldterminator = ',',
      keepidentity, keepnulls, check_constraints);
go
 

bulk insert clase
from '/var/opt/mssql/mockaroo/clase.csv'
with (format = 'csv', firstrow = 2, fieldterminator = ',',
      keepidentity, keepnulls, check_constraints);
go
 
bulk insert pago
from '/var/opt/mssql/mockaroo/pago.csv'
with (format = 'csv', firstrow = 2, fieldterminator = ',',
      keepidentity, keepnulls, check_constraints);
go
 
bulk insert reserva
from '/var/opt/mssql/mockaroo/reserva.csv'
with (format = 'csv', firstrow = 2, fieldterminator = ',',
      keepidentity, keepnulls, check_constraints);
go

