CREATE TABLE [dbo].[Sponsors] (
    [SponsorCode]         NVARCHAR (5)  NOT NULL,
    [SponsorCodeName]     NVARCHAR (30) NULL,
    [FederalAgencyCode]   NVARCHAR (2)  NULL,
    [SponsorCategoryCode] NVARCHAR (2)  NULL,
    [SponsorCategoryName] NVARCHAR (40) NULL,
    [ForeignSponsorInd]   NVARCHAR (1)  NULL,
    [UCOP_LastUpdateDate] DATETIME2 (7) NULL,
    [TP_LastUpdateDate]   DATETIME2 (7) NULL,
    CONSTRAINT [PK_Sponsors] PRIMARY KEY CLUSTERED ([SponsorCode] ASC)
);

