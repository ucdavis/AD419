EXECUTE sp_addlinkedsrvlogin @rmtsrvname = N'PAY_PERS_EXTR', @useself = N'FALSE', @rmtuser = N'aesdean';


GO
EXECUTE sp_addlinkedsrvlogin @rmtsrvname = N'FIS_DS', @useself = N'FALSE', @rmtuser = N'CAES_FIS_APP';


GO
EXECUTE sp_addlinkedsrvlogin @rmtsrvname = N'TINNYTIM', @useself = N'FALSE', @rmtuser = N'ProdDonbot';

