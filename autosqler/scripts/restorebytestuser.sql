USE [master]
RESTORE DB [LW] FROM  DISK = N'S:\Backup\mylw.bak' WITH  FILE = 1,  NOUNLOAD,  REPLACE,  STATS = 5

GO
