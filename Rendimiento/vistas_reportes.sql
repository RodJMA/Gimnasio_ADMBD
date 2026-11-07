-- ============================================================================
-- gimnasio / vistas de reporte (esquema reportes) para Power BI
-- Basadas en las 3 consultas con funciones ventana de Rendimiento/.
-- Ejecutar con sa en gimnasio, despues de schemas.sql y seguridad.sql.
-- Sin datos personales de socios (solo id_socio), segun el diseno de seguridad.
-- usr_analista_bi las lee por encadenamiento de propiedad (todo es de dbo).
-- ============================================================================
use gimnasio;
go

-- 1. ranking de socios por total pagado (RANK / DENSE_RANK / SUM OVER)
create or alter view reportes.vw_ranking_socios as
with pagos_socio as (
    select  m.id_socio,
            sum(p.monto) as total_pagado,
            count(*)     as num_pagos
    from    ventas.pago p
    join    ventas.membresia m on m.id_membresia = p.id_membresia
    where   p.estado = 'PAGADO'
    group by m.id_socio
)
select  ps.id_socio, ps.total_pagado, ps.num_pagos,
        rank()       over (order by ps.total_pagado desc) as ranking,
        dense_rank() over (order by ps.total_pagado desc) as ranking_denso,
        cast(100.0 * ps.total_pagado
             / sum(ps.total_pagado) over () as decimal(5,2)) as pct_del_ingreso_total
from    pagos_socio ps;
go

-- 2. pagos por membresia: acumulado, saldo y dias desde el pago anterior
create or alter view reportes.vw_pagos_acumulados as
select  m.id_socio,
        p.id_membresia,
        pm.nombre as plan_,
        pm.precio as precio_plan,
        p.fecha_pago,
        p.monto,
        row_number() over (partition by p.id_membresia
                           order by p.fecha_pago, p.id_pago) as nro_pago,
        sum(p.monto) over (partition by p.id_membresia
                           order by p.fecha_pago, p.id_pago
                           rows between unbounded preceding and current row) as acumulado,
        pm.precio - sum(p.monto) over (partition by p.id_membresia
                           order by p.fecha_pago, p.id_pago
                           rows between unbounded preceding and current row) as saldo_pendiente,
        datediff(day,
                 lag(p.fecha_pago) over (partition by p.id_membresia
                                         order by p.fecha_pago, p.id_pago),
                 p.fecha_pago) as dias_desde_pago_anterior
from    ventas.pago p
join    ventas.membresia m       on m.id_membresia = p.id_membresia
join    ventas.plan_membresia pm on pm.id_plan     = m.id_plan
where   p.estado = 'PAGADO';
go

-- 3. agenda de entrenadores: minutos libres y traslapes (LAG / LEAD)
create or alter view reportes.vw_agenda_entrenadores as
with agenda as (
    select  c.id_clase, c.id_entrenador, c.id_sala, c.fecha,
            c.hora_inicio, c.hora_fin,
            row_number() over (partition by c.id_entrenador, c.fecha
                               order by c.hora_inicio, c.id_clase) as nro_del_dia,
            count(*)     over (partition by c.id_entrenador, c.fecha) as clases_del_dia,
            lag(c.hora_fin) over (partition by c.id_entrenador, c.fecha
                                  order by c.hora_inicio, c.id_clase) as fin_clase_anterior
    from    operaciones.clase c
    where   c.estado <> 'CANCELADA'
)
select  e.nombre + ' ' + e.apellido as entrenador,
        a.fecha, a.nro_del_dia, a.clases_del_dia,
        a.hora_inicio, a.hora_fin,
        datediff(minute, a.fin_clase_anterior, a.hora_inicio) as minutos_libres_antes,
        case when a.hora_inicio < a.fin_clase_anterior
             then 'TRASLAPE' else 'OK' end as estado_agenda
from    agenda a
join    personal.entrenador e on e.id_entrenador = a.id_entrenador
where   a.clases_del_dia > 1;
go

-- verificacion
select schema_name(schema_id) as esquema, name from sys.views where schema_name(schema_id) = 'reportes';
go