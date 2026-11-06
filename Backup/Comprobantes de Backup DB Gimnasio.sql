/* =====================================================================
   PASO 1. CONTEO DE FILAS ANTES DE BORRAR
   Anota estos numeros: despues de restaurar deben ser identicos.
   ===================================================================== */
USE gimnasio;
GO
SELECT 'socio' AS tabla, COUNT(*) AS filas FROM socios.socio
UNION ALL SELECT 'membresia', COUNT(*) FROM ventas.membresia
UNION ALL SELECT 'pago',      COUNT(*) FROM ventas.pago
UNION ALL SELECT 'reserva',   COUNT(*) FROM operaciones.reserva
UNION ALL SELECT 'clase',     COUNT(*) FROM operaciones.clase;
GO

/* =====================================================================
   PASO 2. RESTAURAR EL FULL Y EL DIFF
   NORECOVERY = la base queda "en restauracion" esperando mas backups.
   ===================================================================== */
USE master;
GO
RESTORE DATABASE gimnasio FROM DISK = N'/backup/Gimnasio/FULL/gimnasio_FULL.bak'
WITH FILE = 1, NORECOVERY, STATS = 10;

RESTORE DATABASE gimnasio FROM DISK = N'/backup/Gimnasio/DIFF/gimnasio_DIFF.bak'
WITH FILE = 1, NORECOVERY, STATS = 10;
GO

/* =====================================================================
   PASO 3. VERIFICAR CUALES LOGS SE RESTAURARAN 
   ===================================================================== */
   RESTORE HEADERONLY FROM DISK = N'/backup/Gimnasio/FULL/gimnasio_FULL.bak';
   RESTORE HEADERONLY FROM DISK = N'/backup/Gimnasio/DIFF/gimnasio_DIFF.bak';
   RESTORE HEADERONLY FROM DISK = N'/backup/Gimnasio/LOGS/gimnasio_LOG.trn';


/* =====================================================================
   PASO 4. RESTAURAR LOS ULTIMOS LOGS (con el ultimo log con recovery)
   ===================================================================== */
   
   RESTORE LOG gimnasio FROM DISK = N'/backup/Gimnasio/LOGS/gimnasio_LOG.trn' WITH FILE = 4, RECOVERY;


/* =====================================================================
   PASO 5. VERIFICAR INTEGRIDAD FISICA Y RESTRICCIONES
   ===================================================================== */
	-- Integridad fisica y logica (no debe devolver errores)
	DBCC CHECKDB (gimnasio) WITH NO_INFOMSGS;
	-- Restricciones (claves foraneas y CHECK): sin filas = correcto
	DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS, NO_INFOMSGS;
	GO
	-- Estado final de la base
	SELECT name, state_desc, recovery_model_desc, containment_desc
	FROM sys.databases WHERE name = N'gimnasio';
	GO

