CREATE TABLE [data].[Titles]
(
    -- Title code to staff type lookup from the legacy PPSDataMart.dbo.titles
    -- table. TitleCode is the 4 character code that the UCPath import stores
    -- in UcPathTransactions.JobCode. Loaded once per environment outside
    -- source control, like OrgRs. No foreign key to StaffTypes so a partial
    -- offline load still deploys; unmatched chains show up in review data.
    [TitleCode]     NVARCHAR(4)   NOT NULL,
    [StaffTypeCode] NVARCHAR(10)  NULL,
    [Name]          NVARCHAR(200) NULL,
    CONSTRAINT [PK_Titles] PRIMARY KEY CLUSTERED ([TitleCode])
);
