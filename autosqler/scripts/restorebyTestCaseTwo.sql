USE [master]
RESTORE DATABASE [LW] FROM  DISK = N'S:\Backup\mylw.bak' WITH  FILE = 1,  MOVE N'LW' TO N'C:\MSSQL\MSSQL15.MSSQLSERVER\MSSQL\DATA\LW.mdf',  MOVE N'LW_log' TO N'C:\MSSQL\MSSQL15.MSSQLSERVER\MSSQL\DATA\LW_log.ldf',  NOUNLOAD,  STATS = 5

GO


