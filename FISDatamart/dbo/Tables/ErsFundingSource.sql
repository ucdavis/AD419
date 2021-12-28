CREATE TABLE [dbo].[ErsFundingSource] (
    [ErsFundingSourceId]       NUMERIC (9)   NOT NULL,
    [ErsSponsoredProjectId]    NUMERIC (9)   NULL,
    [ErnFAU]                   NCHAR (30)    NOT NULL,
    [SponsoredFundsInd]        NCHAR (1)     NULL,
    [CertificationRequiredInd] NCHAR (1)     NOT NULL,
    [FundingSourceStartDate]   DATETIME2 (7) NOT NULL,
    [FundingSourceEndDate]     DATETIME2 (7) NOT NULL,
    [FundName]                 NVARCHAR (50) NULL,
    [AccountOrgCode]           NUMERIC (9)   NULL,
    [FundOrgCode]              NUMERIC (9)   NULL,
    [FedFundInd]               NCHAR (1)     NOT NULL,
    [EffectiveDate]            DATETIME2 (7) NOT NULL,
    CONSTRAINT [PK_ErsFundingSource] PRIMARY KEY CLUSTERED ([ErsFundingSourceId] ASC)
);

