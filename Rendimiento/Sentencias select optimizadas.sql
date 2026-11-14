
/* =====================================================================
   BASE DE DATOS: gimnasio -- esquemas: socios, personal, ventas, operaciones
   3 CONSULTAS CON FUNCIONES VENTANA, CADA UNA OPTIMIZADA CON UN INDICE
   ===================================================================== */

USE gimnasio;
GO
SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO


/* =====================================================================
   CONSULTA 1 -
   Ranking de socios por total pagado y porcentaje del ingreso total.
   INDICE: IX_pago_pagado_membresia_fecha
   ===================================================================== */
DROP INDEX IF EXISTS IX_pago_pagado_membresia_fecha ON ventas.pago;
GO

WITH PagosAgrupados AS (
    SELECT  id_membresia,
            SUM(monto) AS monto_membresia,
            COUNT(*)   AS conteo_membresia
    FROM    ventas.pago
    WHERE   estado = 'PAGADO'
    GROUP BY id_membresia
),
pagos_socio AS (
    SELECT  m.id_socio,
            SUM(pa.monto_membresia) AS total_pagado,
            SUM(pa.conteo_membresia) AS num_pagos
    FROM    PagosAgrupados pa
    JOIN    ventas.membresia m ON m.id_membresia = pa.id_membresia
    GROUP BY m.id_socio
)
SELECT  s.id_socio, s.nombre, s.apellido,
        ps.total_pagado, ps.num_pagos,
        RANK()       OVER (ORDER BY ps.total_pagado DESC) AS ranking,
        DENSE_RANK() OVER (ORDER BY ps.total_pagado DESC) AS ranking_denso,
        CAST(100.0 * ps.total_pagado
             / SUM(ps.total_pagado) OVER () AS DECIMAL(5,2)) AS pct_del_ingreso_total
FROM    pagos_socio ps
JOIN    socios.socio s ON s.id_socio = ps.id_socio
ORDER BY ranking, s.id_socio;
GO

CREATE NONCLUSTERED INDEX IX_pago_pagado_membresia_fecha
    ON ventas.pago (id_membresia, fecha_pago, id_pago)
    INCLUDE (monto)
    WHERE estado = 'PAGADO';
GO


/* =====================================================================
   CONSULTA 2 -
   Pagos de cada membresia: acumulado, saldo pendiente frente al precio
   del plan y dias desde el pago anterior.
   INDICE: el mismo IX_pago_pagado_membresia_fecha (clave = PARTITION BY
   id_membresia + ORDER BY fecha_pago, id_pago).
   ===================================================================== */
   
   DROP INDEX IF EXISTS IX_pago_pagado_membresia_fecha ON ventas.pago;
   GO

WITH PagosProcesados AS (
    SELECT  id_membresia,
            fecha_pago,
            id_pago,
            monto,
            ROW_NUMBER() OVER (
                PARTITION BY id_membresia 
                ORDER BY fecha_pago, id_pago
            ) AS nro_pago,
            SUM(monto) OVER (
                PARTITION BY id_membresia 
                ORDER BY fecha_pago, id_pago 
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS acumulado,
            LAG(fecha_pago) OVER (
                PARTITION BY id_membresia 
                ORDER BY fecha_pago, id_pago
            ) AS fecha_anterior
    FROM    ventas.pago
    WHERE   estado = 'PAGADO'
)
SELECT  m.id_socio,
        pp.id_membresia,
        pm.nombre AS plan_,
        pm.precio AS precio_plan,
        pp.fecha_pago,
        pp.monto,
        pp.nro_pago,
        pp.acumulado,
        pm.precio - pp.acumulado AS saldo_pendiente,
        DATEDIFF(DAY, pp.fecha_anterior, pp.fecha_pago) AS dias_desde_pago_anterior
FROM    PagosProcesados pp
JOIN    ventas.membresia m ON m.id_membresia = pp.id_membresia
JOIN    ventas.plan_membresia pm ON pm.id_plan     = m.id_plan
ORDER BY pp.id_membresia, pp.fecha_pago, pp.id_pago;
GO

CREATE NONCLUSTERED INDEX IX_pago_pagado_membresia_fecha
    ON ventas.pago (id_membresia, fecha_pago, id_pago)
    INCLUDE (monto)
    WHERE estado = 'PAGADO';
GO


/* =====================================================================
   CONSULTA 3 -
   Agenda de cada entrenador por dia: minutos libres entre clases y
   deteccion de traslapes (una clase empieza antes de que acabe la anterior).
   INDICE: IX_clase_entrenador_dia
   ===================================================================== */
DROP INDEX IF EXISTS IX_clase_entrenador_dia ON operaciones.clase;
GO

WITH conteo_clases AS (
    SELECT  id_clase, id_entrenador, fecha, hora_inicio, hora_fin,
            COUNT(*) OVER (PARTITION BY id_entrenador, fecha) AS clases_del_dia
    FROM    operaciones.clase
    WHERE   estado <> 'CANCELADA'
),
agenda_filtrada AS (
    SELECT  id_entrenador, fecha, hora_inicio, hora_fin, clases_del_dia,
            ROW_NUMBER() OVER (PARTITION BY id_entrenador, fecha
                               ORDER BY hora_inicio, id_clase) AS nro_del_dia,
            LAG(hora_fin) OVER (PARTITION BY id_entrenador, fecha
                                ORDER BY hora_inicio, id_clase) AS fin_clase_anterior
    FROM    conteo_clases
    WHERE   clases_del_dia > 1
)
SELECT  e.nombre + ' ' + e.apellido AS entrenador,
        a.fecha, a.nro_del_dia, a.clases_del_dia,
        a.hora_inicio, a.hora_fin,
        DATEDIFF(MINUTE, a.fin_clase_anterior, a.hora_inicio) AS minutos_libres_antes,
        CASE WHEN a.hora_inicio < a.fin_clase_anterior
             THEN 'TRASLAPE' ELSE 'OK' END AS estado_agenda
FROM    agenda_filtrada a
JOIN    personal.entrenador e ON e.id_entrenador = a.id_entrenador
ORDER BY a.id_entrenador, a.fecha, a.nro_del_dia;
GO

CREATE NONCLUSTERED INDEX IX_clase_entrenador_dia
    ON operaciones.clase (id_entrenador, fecha, hora_inicio, id_clase)
    INCLUDE (hora_fin, id_sala)
    WHERE estado <> 'CANCELADA';
GO