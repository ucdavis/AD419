CREATE TABLE [dbo].[OpFundInvestigator] (
    [Year]                    NUMERIC (4)   NOT NULL,
    [Period]                  VARCHAR (2)   NOT NULL,
    [OpLocationCode]          VARCHAR (2)   NOT NULL,
    [OpFundNum]               VARCHAR (6)   NOT NULL,
    [OpFundInvestigatorNum]   VARCHAR (12)  NOT NULL,
    [InvestigatorTypeCode]    VARCHAR (1)   NOT NULL,
    [InvestigatorDaFisUserId] VARCHAR (10)  NULL,
    [InvestigatorUserId]      VARCHAR (8)   NULL,
    [InvestigatorName]        VARCHAR (123) NULL,
    [Chart]                   VARCHAR (2)   NULL,
    [OrgId]                   VARCHAR (4)   NULL,
    [ContactInd]              VARCHAR (1)   NULL,
    [ResponsibleInd]          VARCHAR (1)   NULL,
    [LastUpdateDate]          DATETIME2 (7) NULL,
    CONSTRAINT [PK_OpFundInvestigator] PRIMARY KEY CLUSTERED ([Year] ASC, [Period] ASC, [OpLocationCode] ASC, [OpFundNum] ASC, [OpFundInvestigatorNum] ASC)
);

