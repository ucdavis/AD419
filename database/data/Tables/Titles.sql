CREATE TABLE [data].[Titles]
(
    -- Title code to staff type lookup from the legacy PPSDataMart.dbo.titles
    -- table. TitleCode is the 4 character code that the UCPath import stores
    -- in UcPathTransactions.JobCode. Loaded once per environment outside
    -- source control, like OrgRs, and edited from the Job Code tab of Data
    -- Classification, which sets StaffTypeCode and adds a row (Name NULL) for
    -- a job code that has none. No foreign key to StaffTypes so a partial
    -- offline load still deploys; job codes with no line show on that tab.
    [TitleCode]     NVARCHAR(4)   NOT NULL,
    [StaffTypeCode] NVARCHAR(10)  NULL,
    [Name]          NVARCHAR(200) NULL,
    CONSTRAINT [PK_Titles] PRIMARY KEY CLUSTERED ([TitleCode])
);
