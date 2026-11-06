
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

WITH pagos_socio AS (
    SELECT  m.id_socio,
            SUM(p.monto) AS total_pagado,
            COUNT(*)     AS num_pagos
    FROM    ventas.pago p
    JOIN    ventas.membresia m ON m.id_membresia = p.id_membresia
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
FROM    ventas.pago p
JOIN    ventas.membresia m       ON m.id_membresia = p.id_membresia
JOIN    ventas.plan_membresia pm ON pm.id_plan     = m.id_plan
WHERE   p.estado = 'PAGADO'
ORDER BY p.id_membresia, p.fecha_pago, p.id_pago;
GO


/* =====================================================================
   CONSULTA 3 -
   Agenda de cada entrenador por dia: minutos libres entre clases y
   deteccion de traslapes (una clase empieza antes de que acabe la anterior).
   INDICE: IX_clase_entrenador_dia
   ===================================================================== */
DROP INDEX IF EXISTS IX_clase_entrenador_dia ON operaciones.clase;
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
    FROM    operaciones.clase c
    WHERE   c.estado <> 'CANCELADA'
)
SELECT  e.nombre + ' ' + e.apellido                          AS entrenador,
        a.fecha, a.nro_del_dia, a.clases_del_dia,
        a.hora_inicio, a.hora_fin,
        DATEDIFF(MINUTE, a.fin_clase_anterior, a.hora_inicio) AS minutos_libres_antes,
        CASE WHEN a.hora_inicio < a.fin_clase_anterior
             THEN 'TRASLAPE' ELSE 'OK' END                    AS estado_agenda
FROM    agenda a
JOIN    personal.entrenador e ON e.id_entrenador = a.id_entrenador
WHERE   a.clases_del_dia > 1
ORDER BY a.id_entrenador, a.fecha, a.nro_del_dia;
GO

CREATE NONCLUSTERED INDEX IX_clase_entrenador_dia
    ON operaciones.clase (id_entrenador, fecha, hora_inicio, id_clase)
    INCLUDE (hora_fin, id_sala)
    WHERE estado <> 'CANCELADA';
GO
