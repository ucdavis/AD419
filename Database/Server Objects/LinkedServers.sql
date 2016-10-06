EXECUTE sp_addlinkedserver @server = N'PAY_PERS_EXTR', @srvproduct = N'Oracle', @provider = N'OraOLEDB.Oracle', @datasrc = N'PAY_PERS_EXTR', @provstr = N'ChunkSize=65535';


GO
EXECUTE sp_addlinkedserver @server = N'FIS_DS', @srvproduct = N'Oracle', @provider = N'OraOLEDB.Oracle', @datasrc = N'FIS_DS', @provstr = N'ChunkSize=65535';


GO
EXECUTE sp_addlinkedserver @server = N'TINNYTIM', @srvproduct = N'', @provider = N'SQLNCLI', @datasrc = N'TINNYTIM';


GO
EXECUTE sp_serveroption @server = N'TINNYTIM', @optname = N'rpc', @optvalue = N'TRUE';


GO
EXECUTE sp_serveroption @server = N'TINNYTIM', @optname = N'rpc out', @optvalue = N'TRUE';


GO
EXECUTE sp_serveroption @server = N'TINNYTIM', @optname = N'remote proc transaction promotion', @optvalue = N'FALSE';

