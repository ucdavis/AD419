CREATE TABLE [dbo].[FFY_ExpensesByARC] (
    [AnnualReportCode]  VARCHAR (20) NULL,
    [Chart]             VARCHAR (2)  NULL,
    [Account]           VARCHAR (7)  NULL,
    [ConsolidationCode] VARCHAR (4)  NULL,
    [DirectTotal]       MONEY        NULL,
    [IndirectTotal]     MONEY        NULL,
    [Total]             MONEY        NULL,
    [SFN]               VARCHAR (5)  NULL,
    [OpFundNum]         VARCHAR (6)  NULL
);



