CREATE TABLE [dbo].[DaFIS_AccountsByARC] (
    [Chart]            VARCHAR (2) NOT NULL,
    [Account]          VARCHAR (7) NOT NULL,
    [AnnualReportCode] VARCHAR (6) NULL,
    [OpFundNum]        VARCHAR (6) NULL
);




GO
CREATE NONCLUSTERED INDEX [DaFISAccountsByARC_ChartAccount_ARC_CVIDX]
    ON [dbo].[DaFIS_AccountsByARC]([Chart] ASC, [Account] ASC)
    INCLUDE([AnnualReportCode]);

