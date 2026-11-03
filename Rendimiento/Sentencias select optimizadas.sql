
/* =====================================================================
   BASE DE DATOS: gimnasio (SQL Server 2025)
   5 CONSULTAS CON FUNCIONES VENTANA, CADA UNA OPTIMIZADA CON UN INDICE

   Principio de diseno de todos los indices:
     la clave del indice = columnas del PARTITION BY + columnas del ORDER BY
     de la ventana (en ese orden), y el resto de columnas que lee la consulta
     van en INCLUDE. Asi SQL Server lee las filas ya ordenadas por particion,
     no necesita el operador Sort y no hace Key Lookup.
   Todas las funciones de una misma consulta usan la MISMA particion y el
   MISMO orden, para que se calculen en una sola pasada.

   Estados validos (segun los CHECK de la base):
     membresia: ACTIVA | VENCIDA | CANCELADA | SUSPENDIDA
     clase    : PROGRAMADA | REALIZADA | CANCELADA
     pago     : PAGADO | PENDIENTE | ANULADO
     reserva  : RESERVADA | ASISTIO | NO_ASISTIO | CANCELADA

   COMO MEDIR (por cada consulta):
     1) Ejecuta "Quitar indice", luego la consulta con Ctrl+M (plan real).
        Anota lecturas logicas (pestana Messages) y si hay Sort / Lookup / Scan.
     2) Ejecuta "Crear indice" y repite. Deberias ver menos lecturas logicas
        y desaparecer el Sort y el Key Lookup.

   Los indices filtrados requieren QUOTED_IDENTIFIER ON (por defecto en SSMS).
   ===================================================================== */

USE gimnasio;
GO
SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO


/* =====================================================================
   CONSULTA 1 - RANK / DENSE_RANK / SUM() OVER ()
   Ranking de socios por total pagado y porcentaje del ingreso total.
   INDICE: IX_pago_pagado_membresia_fecha (compartido con la consulta 2)
   ===================================================================== */
DROP INDEX IF EXISTS IX_pago_pagado_membresia_fecha ON dbo.pago;
GO

WITH pagos_socio AS (
    SELECT  m.id_socio,
            SUM(p.monto) AS total_pagado,
            COUNT(*)     AS num_pagos
    FROM    dbo.pago p
    JOIN    dbo.membresia m ON m.id_membresia = p.id_membresia
    WHERE   p.estado = 'PAGADO'
    GROUP BY m.id_socio
)
SELECT  s.id_socio, s.nombre, s.apellido,
        ps.total_pagado, ps.num_pagos,
        RANK()       OVER (ORDER BY ps.total_pagado DESC) AS ranking,
        DENSE_RANK() OVER (ORDER BY ps.total_pagado DESC) AS ranking_denso,
        CAST(100.0 * ps.total_pagado
             / SUM(ps.total_pagado) OVER () AS DECIMAL(5,2)) AS pct_del_ingreso_total
FROM    pagos_socio ps
JOIN    dbo.socio s ON s.id_socio = ps.id_socio
ORDER BY ranking, s.id_socio;
GO

CREATE NONCLUSTERED INDEX IX_pago_pagado_membresia_fecha
    ON dbo.pago (id_membresia, fecha_pago, id_pago)
    INCLUDE (monto)
    WHERE estado = 'PAGADO';
GO


/* =====================================================================
   CONSULTA 2 - SUM() OVER (ROWS ...) acumulado + LAG + ROW_NUMBER
   Pagos de cada membresia: acumulado, saldo pendiente frente al precio
   del plan y dias desde el pago anterior.
   INDICE: el mismo IX_pago_pagado_membresia_fecha (clave = PARTITION BY
   id_membresia + ORDER BY fecha_pago, id_pago).
   ===================================================================== */

SELECT  m.id_socio,
        p.id_membresia,
        pm.nombre                                        AS plan_,
        pm.precio                                        AS precio_plan,
        p.fecha_pago,
        p.monto,
        ROW_NUMBER() OVER (PARTITION BY p.id_membresia
                           ORDER BY p.fecha_pago, p.id_pago)            AS nro_pago,
        SUM(p.monto) OVER (PARTITION BY p.id_membresia
                           ORDER BY p.fecha_pago, p.id_pago
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS acumulado,
        pm.precio - SUM(p.monto) OVER (PARTITION BY p.id_membresia
                           ORDER BY p.fecha_pago, p.id_pago
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS saldo_pendiente,
        DATEDIFF(DAY,
                 LAG(p.fecha_pago) OVER (PARTITION BY p.id_membresia
                                         ORDER BY p.fecha_pago, p.id_pago),
                 p.fecha_pago)                           AS dias_desde_pago_anterior
FROM    dbo.pago p
JOIN    dbo.membresia m       ON m.id_membresia = p.id_membresia
JOIN    dbo.plan_membresia pm ON pm.id_plan     = m.id_plan
WHERE   p.estado = 'PAGADO'
ORDER BY p.id_membresia, p.fecha_pago, p.id_pago;
GO


/* =====================================================================
   CONSULTA 3 - LAG / LEAD / ROW_NUMBER / COUNT() OVER
   Agenda de cada entrenador por dia: minutos libres entre clases y
   deteccion de traslapes (una clase empieza antes de que acabe la anterior).
   INDICE: IX_clase_entrenador_dia
   ===================================================================== */
DROP INDEX IF EXISTS IX_clase_entrenador_dia ON dbo.clase;
GO

WITH agenda AS (
    SELECT  c.id_clase, c.id_entrenador, c.id_sala, c.fecha,
            c.hora_inicio, c.hora_fin,
            ROW_NUMBER() OVER (PARTITION BY c.id_entrenador, c.fecha
                               ORDER BY c.hora_inicio, c.id_clase) AS nro_del_dia,
            COUNT(*)     OVER (PARTITION BY c.id_entrenador, c.fecha) AS clases_del_dia,
            LAG(c.hora_fin)      OVER (PARTITION BY c.id_entrenador, c.fecha
                                       ORDER BY c.hora_inicio, c.id_clase) AS fin_clase_anterior,
            LEAD(c.hora_inicio)  OVER (PARTITION BY c.id_entrenador, c.fecha
                                       ORDER BY c.hora_inicio, c.id_clase) AS inicio_clase_siguiente
    FROM    dbo.clase c
    WHERE   c.estado <> 'CANCELADA'
)
SELECT  e.nombre + ' ' + e.apellido                          AS entrenador,
        a.fecha, a.nro_del_dia, a.clases_del_dia,
        a.hora_inicio, a.hora_fin,
        DATEDIFF(MINUTE, a.fin_clase_anterior, a.hora_inicio) AS minutos_libres_antes,
        CASE WHEN a.hora_inicio < a.fin_clase_anterior
             THEN 'TRASLAPE' ELSE 'OK' END                    AS estado_agenda
FROM    agenda a
JOIN    dbo.entrenador e ON e.id_entrenador = a.id_entrenador
WHERE   a.clases_del_dia > 1
ORDER BY a.id_entrenador, a.fecha, a.nro_del_dia;
GO

CREATE NONCLUSTERED INDEX IX_clase_entrenador_dia
    ON dbo.clase (id_entrenador, fecha, hora_inicio, id_clase)
    INCLUDE (hora_fin, id_sala)
    WHERE estado <> 'CANCELADA';
GO


/* =====================================================================
   CONSULTA 4 - ROW_NUMBER / COUNT() OVER PARTITION BY
   Clases con sobreventa: posicion de cada reserva por orden de llegada y
   quienes quedan en lista de espera (posicion > cupo_max).
   INDICE: IX_reserva_clase_orden
   ===================================================================== */
DROP INDEX IF EXISTS IX_reserva_clase_orden ON dbo.reserva;
GO

WITH cola AS (
    SELECT  r.id_clase, r.id_socio, r.fecha_reserva,
            ROW_NUMBER() OVER (PARTITION BY r.id_clase
                               ORDER BY r.fecha_reserva, r.id_socio) AS posicion,
            COUNT(*)     OVER (PARTITION BY r.id_clase)                AS total_reservas
    FROM    dbo.reserva r
    WHERE   r.estado <> 'CANCELADA'
)
SELECT  c.id_clase, c.fecha, c.cupo_max,
        q.total_reservas,
        q.posicion,
        q.id_socio,
        q.fecha_reserva,
        CASE WHEN q.posicion > c.cupo_max THEN 'LISTA_ESPERA' ELSE 'CON_CUPO' END AS situacion
FROM    cola q
JOIN    dbo.clase c ON c.id_clase = q.id_clase
WHERE   q.total_reservas > c.cupo_max
ORDER BY c.id_clase, q.posicion;
GO

CREATE NONCLUSTERED INDEX IX_reserva_clase_orden
    ON dbo.reserva (id_clase, fecha_reserva, id_socio)
    WHERE estado <> 'CANCELADA';
GO


/* =====================================================================
   CONSULTA 5 - ROW_NUMBER / COUNT() OVER / LAG
   Ultima membresia de cada socio, su plan y dias de hueco respecto a la
   membresia anterior (indicador de renovacion).
   INDICE: IX_membresia_socio_fin
   ===================================================================== */
DROP INDEX IF EXISTS IX_membresia_socio_fin ON dbo.membresia;
GO

WITH historial AS (
    SELECT  m.id_membresia, m.id_socio, m.id_plan,
            m.fecha_inicio, m.fecha_fin, m.estado,
            ROW_NUMBER() OVER (PARTITION BY m.id_socio
                               ORDER BY m.fecha_fin, m.id_membresia) AS nro_membresia,
            COUNT(*)     OVER (PARTITION BY m.id_socio)              AS total_membresias,
            LAG(m.fecha_fin) OVER (PARTITION BY m.id_socio
                                   ORDER BY m.fecha_fin, m.id_membresia) AS fin_anterior
    FROM    dbo.membresia m
)
SELECT  s.id_socio, s.nombre, s.apellido,
        pm.nombre   AS plan_actual,
        pm.precio,
        h.fecha_inicio, h.fecha_fin, h.estado,
        h.total_membresias,
        DATEDIFF(DAY, h.fin_anterior, h.fecha_inicio) AS dias_hueco_vs_anterior
FROM    historial h
JOIN    dbo.socio s           ON s.id_socio = h.id_socio
JOIN    dbo.plan_membresia pm ON pm.id_plan = h.id_plan
WHERE   h.nro_membresia = h.total_membresias      -- ultima membresia de cada socio
ORDER BY s.id_socio;
GO

CREATE NONCLUSTERED INDEX IX_membresia_socio_fin
    ON dbo.membresia (id_socio, fecha_fin, id_membresia)
    INCLUDE (id_plan, fecha_inicio, estado);
GO