CREATE TABLE [dbo].[SFN_204_ProjctMatches] (
    [Accession]          CHAR (7)        NULL,
    [Project]            VARCHAR (24)    NULL,
    [Chart]              VARCHAR (2)     NULL,
    [Account]            VARCHAR (7)     NULL,
    [OpFund]             VARCHAR (6)     NULL,
    [AwardNumbersDiffer] BIT             NULL,
    [AccountAwardNum]    VARCHAR (20)    NULL,
    [FundAwardNum]       VARCHAR (20)    NULL,
    [FundName]           VARCHAR (40)    NULL,
    [PiNamesDiffer]      BIT             NULL,
    [AccountPI]          VARCHAR (30)    NULL,
    [FundPI]             VARCHAR (30)    NULL,
    [AccountName]        VARCHAR (40)    NULL,
    [AccountPurpose]     VARCHAR (400)   NULL,
    [OPFundProjectTitle] VARCHAR (256)   NULL,
    [ProjectTitle]       VARCHAR (200)   NULL,
    [Expenses]           DECIMAL (16, 2) NULL
);

