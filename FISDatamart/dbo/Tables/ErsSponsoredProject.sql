CREATE TABLE [dbo].[ErsSponsoredProject] (
    [ErsSponsoredProjectId]     NUMERIC (9)    NOT NULL,
    [ContractNum]               NVARCHAR (30)  NULL,
    [SponsorCode]               NVARCHAR (10)  NULL,
    [sponsorName]               NVARCHAR (90)  NULL,
    [ProjectId]                 NVARCHAR (30)  NULL,
    [ProjectName]               NVARCHAR (135) NULL,
    [ ProjectIdAlt]             NVARCHAR (50)  NULL,
    [ProjectNameAlt]            NVARCHAR (200) NULL,
    [CertificationRequiredInd]  NCHAR (1)      NOT NULL,
    [SponsoredProjectStartDate] DATETIME2 (7)  NOT NULL,
    [SponsoredProjectEndDate]   DATETIME2 (7)  NOT NULL,
    CONSTRAINT [PK_ErsSponsoredProject] PRIMARY KEY CLUSTERED ([ErsSponsoredProjectId] ASC)
);

