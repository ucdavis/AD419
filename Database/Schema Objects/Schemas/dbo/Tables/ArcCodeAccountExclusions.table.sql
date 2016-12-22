CREATE TABLE [dbo].[ArcCodeAccountExclusions] (
    [Year]             INT           NOT NULL,
    [Chart]            VARCHAR (2)   NOT NULL,
    [Account]          VARCHAR (7)   NOT NULL,
    [AnnualReportCode] CHAR (6)      NOT NULL,
    [Comments]         VARCHAR (MAX) NULL,
    [Is204]            BIT           NULL,
    [AwardNumber]      VARCHAR (20)  NULL,
    [ProjectNumber]    VARCHAR (24)  NULL,
    CONSTRAINT [PK_ArcCodeAccountExclusions] PRIMARY KEY CLUSTERED ([Year] ASC, [Chart] ASC, [Account] ASC, [AnnualReportCode] ASC)
);






GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'ARC Code Account Exclusions: Contains accounts that should be excluded from the AD-419 process for the specified reporting year.  Added as an afterthought to handle AD-419 reporting year 2012-2013 issue for arc code 441042 that were miscoded by department.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ArcCodeAccountExclusions';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Org/Account Record Effective Fiscal Year: The fiscal year in which this set of values was in effect', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ArcCodeAccountExclusions', @level2type = N'COLUMN', @level2name = N'Year';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart Of Accounts Number: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ArcCodeAccountExclusions', @level2type = N'COLUMN', @level2name = N'Chart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Annual Report Code: Could also be considered a departmental report code for the Campus Financial Schedules. Code used to map individual accounts into one.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ArcCodeAccountExclusions', @level2type = N'COLUMN', @level2name = N'AnnualReportCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Number: Organization chosen identifier used to classify financial resources for accounting and reporting purposes. Identifies a pool of funds assigned to a specific university division, for a specific function.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ArcCodeAccountExclusions', @level2type = N'COLUMN', @level2name = N'Account';

