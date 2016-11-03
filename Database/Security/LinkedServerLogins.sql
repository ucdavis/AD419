EXECUTE sp_addlinkedsrvlogin @rmtsrvname = N'TINNYTIM', @useself = N'FALSE', @rmtuser = N'ProdDonbot';


GO
EXECUTE sp_addlinkedsrvlogin @rmtsrvname = N'SIS', @useself = N'FALSE', @rmtuser = N'ops$caesdo';


GO
EXECUTE sp_addlinkedsrvlogin @rmtsrvname = N'QB5FM1U0EB.DATABASE.WINDOWS.NET', @useself = N'FALSE', @rmtuser = N'opp@qb5fm1u0eb.database.windows.net';


GO
EXECUTE sp_addlinkedsrvlogin @rmtsrvname = N'PAY_PERS_EXTR', @useself = N'FALSE', @rmtuser = N'aesdean';


GO
EXECUTE sp_addlinkedsrvlogin @rmtsrvname = N'MOTHRA_PROD', @useself = N'FALSE', @rmtuser = N'caes';


GO
EXECUTE sp_addlinkedsrvlogin @rmtsrvname = N'ISODS_PROD', @useself = N'FALSE', @rmtuser = N'cru';


GO
EXECUTE sp_addlinkedsrvlogin @rmtsrvname = N'ICMSP', @useself = N'FALSE', @rmtuser = N'navcourseinfo_ag';


GO
EXECUTE sp_addlinkedsrvlogin @rmtsrvname = N'FIS_DS_STAGE', @useself = N'FALSE', @rmtuser = N'CAES_FIS_APP';


GO
EXECUTE sp_addlinkedsrvlogin @rmtsrvname = N'FIS_DS', @useself = N'FALSE', @rmtuser = N'CAES_FIS_APP';


GO
EXECUTE sp_addlinkedsrvlogin @rmtsrvname = N'AIS_STAGE', @useself = N'FALSE', @rmtuser = N'advancerep';

