CREATE TABLE [dbo].[204AcctXProj] (
    [AccountID]         CHAR (7)     NOT NULL,
    [Expenses]          FLOAT        NOT NULL,
    [DividedAmount]     FLOAT        NULL,
    [Accession]         CHAR (7)     NULL,
    [Chart]             CHAR (1)     NULL,
    [pk]                INT          IDENTITY (1, 1) NOT NULL,
    [Is219]             BIT          NULL,
    [CSREES_ContractNo] VARCHAR (20) NULL,
    [IsCurrentProject]  BIT          NULL
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Contains SFN 204 expenses as identified by OpFundGroupCode, FederalAgencyCode, SponsorCode, and OpFundNum like "USDA%CSREES%" or "USDA%NIFA%" and their corresponding account numbers. 
The expense and account numbers are populated automatically by the AD419 data load process. The project''s accession number is updated programatically using the AD-419 web application user interface. (Used by the AD-419 Web Application).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'204AcctXProj';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'FIS account number related to corresponding expense.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'204AcctXProj', @level2type = N'COLUMN', @level2name = N'AccountID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Full sum of expense totals for corresponding account number.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'204AcctXProj', @level2type = N'COLUMN', @level2name = N'Expenses';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fractional expense amount used for prorating expenses across multiple projects for the same PI when a matching 204 project cannot be uniquely identified.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'204AcctXProj', @level2type = N'COLUMN', @level2name = N'DividedAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Project accession number associated with expense.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'204AcctXProj', @level2type = N'COLUMN', @level2name = N'Accession';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'FIS fiscal chart number of corresponding expense.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'204AcctXProj', @level2type = N'COLUMN', @level2name = N'Chart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Table primary key.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'204AcctXProj', @level2type = N'COLUMN', @level2name = N'pk';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Set to 1 if expense cannot be identified as a 204 expense.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'204AcctXProj', @level2type = N'COLUMN', @level2name = N'Is219';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'The corrected, full 14 digit, numerical CSREES contract/award number. Used for matching expense against project if a correctly formatted award number was not present and the expense was not matched by prior attempts.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'204AcctXProj', @level2type = N'COLUMN', @level2name = N'CSREES_ContractNo';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Set if to 0 if expense is found to be related to an expired ''CG'', ''OG'' or ''SG'' project.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'204AcctXProj', @level2type = N'COLUMN', @level2name = N'IsCurrentProject';

