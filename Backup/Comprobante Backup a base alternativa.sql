/* =====================================================================
  RESTAURAR gimnasio EN UNA BASE ALTERNATIVA (gimnasio_alt)
   ===================================================================== */
/* =====================================================================
   PASO 0. (Opcional) VER QUE HAY DENTRO DE CADA ARCHIVO DE RESPALDO
   Un mismo archivo puede guardar varios respaldos (columna Position).
   Usa en FILE = n la posicion del respaldo que quieras restaurar:
   normalmente el ULTIMO Full y el ULTIMO diferencial.
   ===================================================================== */
USE master;
GO
RESTORE HEADERONLY FROM DISK = N'/backup/Gimnasio/FULL/gimnasio_FULL.bak';
RESTORE HEADERONLY FROM DISK = N'/backup/Gimnasio/DIFF/gimnasio_DIFF.bak';
GO


/* =====================================================================
   PASO 1. RESTAURAR EL FULL CON OTRO NOMBRE
   - MOVE cambia donde se escriben los archivos (si no, intentaria
     sobrescribir los de "gimnasio" y fallaria).
   - NORECOVERY = la base queda "en restauracion" esperando mas respaldos.
   ===================================================================== */
USE master;
GO
RESTORE DATABASE gimnasio_alt
FROM DISK = N'/backup/Gimnasio/FULL/gimnasio_FULL.bak'
WITH FILE = 1,  -- posicion del Full (ver paso 0)
     MOVE N'gimnasio' TO N'/var/opt/mssql/data/gimnasio_alt.mdf',
     MOVE N'gimnasio_log' TO N'/var/opt/mssql/data/gimnasio_alt_log.ldf',
     NORECOVERY, STATS = 10;
GO


/* =====================================================================
   PASO 2. RESTAURAR EL DIFERENCIAL
   No lleva MOVE: los archivos ya quedaron ubicados en el paso 1.
   ===================================================================== */
RESTORE DATABASE gimnasio_alt
FROM DISK = N'/backup/Gimnasio/DIFF/gimnasio_DIFF.bak'
WITH FILE = 1,-- posicion del diferencial (ver paso 0)
     NORECOVERY, STATS = 10;
GO

/* =====================================================================
   PASO 4. RESTAURAR LOS LOGS
   ===================================================================== */
RESTORE HEADERONLY FROM DISK = N'/backup/Gimnasio/LOGS/gimnasio_LOG.trn';
RESTORE LOG gimnasio_alt FROM DISK = N'/backup/Gimnasio/LOGS/gimnasio_LOG.trn' WITH FILE = 16, RECOVERY; --Desde hoy 16


/* =====================================================================
   PASO 5. ABRIR LA BASE ALTERNATIVA  (siempre al final)
   RECOVERY termina la restauracion y deja gimnasio_alt en linea.
   ===================================================================== */
RESTORE DATABASE gimnasio_alt WITH RECOVERY;
GO


/* =====================================================================
   PASO 6. VERIFICAR
   - Las dos bases deben estar ONLINE (la original no se toco).
   - Los conteos de gimnasio_alt corresponden al punto al que restauraste
     (si restauraste hasta el ultimo log, deben ser parecidos a la original).
   ===================================================================== */
SELECT name, state_desc, recovery_model_desc
FROM sys.databases
WHERE name IN (N'gimnasio', N'gimnasio_alt');
GO

SELECT 'original' AS base, 'socio' AS tabla, COUNT(*) AS filas FROM gimnasio.socios.socio
UNION ALL SELECT 'alterna', 'socio', COUNT(*) FROM gimnasio_alt.socios.socio
UNION ALL SELECT 'original', 'pago', COUNT(*) FROM gimnasio.ventas.pago
UNION ALL SELECT 'alterna',  'pago', COUNT(*) FROM gimnasio_alt.ventas.pago
UNION ALL SELECT 'original', 'reserva', COUNT(*) FROM gimnasio.operaciones.reserva
UNION ALL SELECT 'alterna',  'reserva', COUNT(*) FROM gimnasio_alt.operaciones.reserva;
GO

-- Integridad de la copia (no debe devolver errores)
DBCC CHECKDB (gimnasio_alt) WITH NO_INFOMSGS;
GO


/* =====================================================================
   PASO 7. LIMPIEZA (al terminar la demostracion)
   Borra solo la copia. La base original no se toca.
   ===================================================================== */
USE master;
DROP DATABASE gimnasio_alt;
GO