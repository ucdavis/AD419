EXECUTE sp_addlinkedserver @server = N'TINNYTIM', @srvproduct = N'', @provider = N'SQLNCLI', @datasrc = N'TINNYTIM';


GO
EXECUTE sp_serveroption @server = N'TINNYTIM', @optname = N'rpc', @optvalue = N'TRUE';


GO
EXECUTE sp_serveroption @server = N'TINNYTIM', @optname = N'rpc out', @optvalue = N'TRUE';


GO
EXECUTE sp_serveroption @server = N'TINNYTIM', @optname = N'remote proc transaction promotion', @optvalue = N'FALSE';


GO
EXECUTE sp_addlinkedserver @server = N'SIS', @srvproduct = N'Oracle', @provider = N'OraOLEDB.Oracle', @datasrc = N'SIS', @provstr = N'ChunkSize=65535';


GO
EXECUTE sp_addlinkedserver @server = N'QB5FM1U0EB.DATABASE.WINDOWS.NET', @srvproduct = N'', @provider = N'SQLNCLI', @datasrc = N'tcp:qb5fm1u0eb.database.windows.net';


GO
EXECUTE sp_addlinkedserver @server = N'PAY_PERS_EXTR', @srvproduct = N'Oracle', @provider = N'OraOLEDB.Oracle', @datasrc = N'PAY_PERS_EXTR', @provstr = N'ChunkSize=65535';


GO
EXECUTE sp_addlinkedserver @server = N'MOTHRA_PROD', @srvproduct = N'Oracle', @provider = N'OraOLEDB.Oracle', @datasrc = N'MOTHRA', @provstr = N'ChunkSize=65535';


GO
EXECUTE sp_addlinkedserver @server = N'ISODS_PROD', @srvproduct = N'Oracle', @provider = N'OraOLEDB.Oracle', @datasrc = N'ISODS_PROD', @provstr = N'ChunkSize=65535';


GO
EXECUTE sp_addlinkedserver @server = N'ICMSP', @srvproduct = N'Oracle', @provider = N'OraOLEDB.Oracle', @datasrc = N'(DESCRIPTION=
(ADDRESS=(PROTOCOL=TCP)(HOST=regoracle.ucdavis.edu)(PORT=1521))
(CONNECT_DATA=(SID=ICMSP))
)', @provstr = N'ChunkSize=65535';


GO
EXECUTE sp_addlinkedserver @server = N'FIS_DS_STAGE', @srvproduct = N'Oracle', @provider = N'OraOLEDB.Oracle', @datasrc = N'FIS_DS_STAGE', @provstr = N'ChunkSize=65535';


GO
EXECUTE sp_addlinkedserver @server = N'FIS_DS', @srvproduct = N'Oracle', @provider = N'OraOLEDB.Oracle', @datasrc = N'FIS_DS', @provstr = N'ChunkSize=65535';


GO
EXECUTE sp_addlinkedserver @server = N'AIS_STAGE', @srvproduct = N'Oracle', @provider = N'OraOLEDB.Oracle', @datasrc = N'ais_stage', @provstr = N'ChunkSize=65535';

