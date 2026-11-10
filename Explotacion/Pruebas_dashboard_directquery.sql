use gimnasio;
go

-- Verificar datos
select count(*) as pagos, sum(monto) as ingresos from reportes.vw_pagos_acumulados;

-- Prueba 1: agregar pagos (suben ingresos, numero de pagos y la barra de octubre)
insert into ventas.pago (id_membresia, fecha_pago, monto, metodo_pago, estado, numero_comprobante)
select top 1 id_membresia, '2026-10-20', 999.00, 'EFECTIVO', 'PAGADO', 'TEST-0001' from ventas.membresia order by id_membresia;

insert into ventas.pago (id_membresia, fecha_pago, monto, metodo_pago, estado, numero_comprobante)
select top 1 id_membresia, '2026-10-20', 500.00, 'TARJETA', 'PAGADO', 'TEST-0002' from ventas.membresia order by id_membresia;

-- Prueba 2: pago de un socio que no tenia pagos (sube socios con pagos)
insert into ventas.pago (id_membresia, fecha_pago, monto, metodo_pago, estado, numero_comprobante)
select top 1 m.id_membresia, '2026-10-21', 300.00, 'TRANSFERENCIA', 'PAGADO', 'TEST-0003'
from ventas.membresia m
where m.id_socio not in (select m2.id_socio from ventas.pago p join ventas.membresia m2 on m2.id_membresia = p.id_membresia
where p.estado = 'PAGADO')
order by m.id_membresia;

-- Prueba 3: agregar dos clases a un entrenador el mismo dia (aparece en la matriz con 2 clases)
-- el cupo 77 solo sirve para identificar las clases de prueba al borrarlas
insert into operaciones.clase (id_tipo_clase, id_entrenador, id_sala, fecha, hora_inicio, hora_fin, cupo_max, estado)
select top 1 (select top 1 id_tipo_clase from operaciones.tipo_clase order by id_tipo_clase),
             e.id_entrenador,
             (select top 1 id_sala from operaciones.sala order by id_sala),
             '2026-10-23', '08:00', '09:00', 77, 'PROGRAMADA'
from personal.entrenador e where e.nombre = 'Brenda' and e.apellido = 'Quintanilla';
 
insert into operaciones.clase (id_tipo_clase, id_entrenador, id_sala, fecha, hora_inicio, hora_fin, cupo_max, estado)
select top 1 (select top 1 id_tipo_clase from operaciones.tipo_clase order by id_tipo_clase),
             e.id_entrenador,
             (select top 1 id_sala from operaciones.sala order by id_sala),
             '2026-10-23', '09:30', '10:30', 77, 'PROGRAMADA'
from personal.entrenador e where e.nombre = 'Brenda' and e.apellido = 'Quintanilla';
 
-- Ver las clases de prueba en la vista
select * from reportes.vw_agenda_entrenadores where entrenador = 'Brenda Quintanilla' and fecha = '2026-10-23';

-- Borrar datos para no alterar la base
delete from ventas.pago where numero_comprobante like 'TEST-%';
delete from operaciones.clase where cupo_max = 77;
