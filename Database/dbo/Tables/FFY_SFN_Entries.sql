CREATE TABLE [dbo].[FFY_SFN_Entries] (
    [Id]                INT             IDENTITY (1, 1) NOT NULL,
    [Chart]             VARCHAR (2)     NULL,
    [Account]           VARCHAR (7)     NULL,
    [SFN]               VARCHAR (5)     NULL,
    [Accounts_AwardNum] VARCHAR (50)    NULL,
    [OpFund_AwardNum]   VARCHAR (50)    NULL,
    [AccessionNumber]   VARCHAR (10)    NULL,
    [ProjectNumber]     VARCHAR (24)    NULL,
    [IsExpired]         BIT             NULL,
    [ProjectEndDate]    DATETIME2 (7)   NULL,
    [Expenses]          MONEY           NULL,
    [FTE]               DECIMAL (14, 4) NULL,
    CONSTRAINT [PK_FFY_SFN_Entries] PRIMARY KEY CLUSTERED ([Id] ASC)
);

