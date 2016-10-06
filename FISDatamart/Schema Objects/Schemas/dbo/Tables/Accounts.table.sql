CREATE TABLE [dbo].[Accounts] (
    [Year]                      INT             NOT NULL,
    [Period]                    CHAR (2)        NOT NULL,
    [Chart]                     VARCHAR (2)     NOT NULL,
    [Account]                   CHAR (7)        NOT NULL,
    [Org]                       CHAR (4)        NOT NULL,
    [AccountName]               VARCHAR (40)    NULL,
    [SubFundGroupNum]           CHAR (6)        NULL,
    [SubFundGroupTypeCode]      CHAR (2)        NULL,
    [FundGroupCode]             CHAR (2)        NULL,
    [EffectiveDate]             DATETIME        NULL,
    [CreateDate]                DATETIME        NULL,
    [ExpirationDate]            DATETIME        NULL,
    [LastUpdateDate]            DATETIME        NULL,
    [MgrId]                     VARCHAR (8)     NULL,
    [MgrName]                   VARCHAR (30)    NULL,
    [ReviewerId]                VARCHAR (8)     NULL,
    [ReviewerName]              VARCHAR (30)    NULL,
    [PrincipalInvestigatorId]   VARCHAR (8)     NULL,
    [PrincipalInvestigatorName] VARCHAR (30)    NULL,
    [TypeCode]                  CHAR (2)        NULL,
    [Purpose]                   VARCHAR (400)   NULL,
    [ControlChart]              CHAR (2)        NULL,
    [ControlAccount]            CHAR (7)        NULL,
    [SponsorCode]               CHAR (4)        NULL,
    [SponsorCategoryCode]       CHAR (2)        NULL,
    [FederalAgencyCode]         CHAR (2)        NULL,
    [CFDANum]                   CHAR (6)        NULL,
    [AwardNum]                  VARCHAR (20)    NULL,
    [AwardTypeCode]             CHAR (1)        NULL,
    [AwardYearNum]              CHAR (2)        NULL,
    [AwardBeginDate]            DATETIME        NULL,
    [AwardEndDate]              DATETIME        NULL,
    [AwardAmount]               DECIMAL (15, 2) NULL,
    [ICRTypeCode]               CHAR (2)        NULL,
    [ICRSeriesNum]              CHAR (3)        NULL,
    [HigherEdFuncCode]          CHAR (4)        NULL,
    [ReportsToChart]            CHAR (2)        NULL,
    [ReportsToAccount]          CHAR (7)        NULL,
    [A11AcctNum]                CHAR (7)        NULL,
    [A11FundNum]                CHAR (7)        NULL,
    [OpFundNum]                 VARCHAR (6)     NULL,
    [OpFundGroupCode]           CHAR (6)        NULL,
    [AcademicDisciplineCode]    CHAR (3)        NULL,
    [AnnualReportCode]          CHAR (6)        NULL,
    [PaymentMediumCode]         CHAR (2)        NULL,
    [NIHDocNum]                 CHAR (12)       NULL,
    [FringeBenefitIndicator]    CHAR (1)        NULL,
    [FringeBenefitChart]        VARCHAR (2)     NULL,
    [FringeBenefitAccount]      CHAR (7)        NULL,
    [YeType]                    CHAR (1)        NULL,
    [AccountPK]                 CHAR (17)       NULL,
    [OrgFK]                     CHAR (14)       NULL,
    [FunctionCodeID]            SMALLINT        NULL,
    [OPFundFK]                  VARCHAR (17)    NULL,
    [IsCAES]                    TINYINT         NULL,
    CONSTRAINT [PK_Accounts] PRIMARY KEY CLUSTERED ([Year] ASC, [Period] ASC, [Chart] ASC, [Account] ASC),
    CONSTRAINT [FK_Accounts_Organizations] FOREIGN KEY ([Year], [Period], [Org], [Chart]) REFERENCES [dbo].[Organizations] ([Year], [Period], [Org], [Chart]) NOT FOR REPLICATION
);


GO
ALTER TABLE [dbo].[Accounts] NOCHECK CONSTRAINT [FK_Accounts_Organizations];




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organizational Accounts: Contains the data about an account and the related organization', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Org/Account Record Effective Fiscal Year: The fiscal year in which this set of values was in effect', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'Year';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Org/Account Record Effective Fiscal Period: The fiscal period for which this set of values was in effect', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'Period';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart Of Accounts Number: Identifier of a Chart of Accounts', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'Chart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Number: Organization chosen identifier used to classify financial resources for accounting and reporting purposes. Identifies a pool of funds assigned to a specific university division, for a specific function.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'Account';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization Identifier: Identifies the organization to which the account belongs. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'Org';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Name: The descriptive name of the account', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'AccountName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Number: Code that identifies the fund source of an account. Similar to the A11 system fund number, but will be an alpha abbreviation instead of a number. Examples of sub fund groups include continuing education accounts, scholarships and fellowships, general funds, etc.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'SubFundGroupNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Type Code: Used to group like sub funds. For example, Federal Contracts would be a sub fund group type with a number of associated sub fund groups.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'SubFundGroupTypeCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fund Group Code: Code that identifies a major fund group. The fund groups are current funds, plant funds, agency funds, endowment funds, loan funds and ucrs funds.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'FundGroupCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Effective Date: The date which this account became effective and can begin accepting transactions.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'EffectiveDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Create Date: The date which this account was initially created', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'CreateDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Expiration Date: This is the date on which the account expires and will no longer accept transactions.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'ExpirationDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Last Update Date: This is the date on which the data about this account was changed', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Manager Name: Identifies an individual who is responsible in some way for the activity in an account.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'MgrName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Principal Investigator Name: The name of the Principal Investigator of a contract or grant.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'PrincipalInvestigatorName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Type Code: Identifies the account type. Examples of account types include EX (expenditure), BS (balance sheet), IN (income), UN (unbalanced), etc.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'TypeCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Purpose Text: The account guidelines or purpose (inquiry).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'Purpose';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Control Chart Of Accounts Number: Chart of Accounts that the Control Account belongs to.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'ControlChart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Control Account Number: TIdentifies the primary spending authority account for a contract/grant that has been assigned multiple accounts . This is the account used for most reporting. in the system. Most reporting will be done out of this account because it represents the full functionality of the project and its corresponding expenditures and revenues. (Don''t blame me for the typos.  I just copied the description verbatim from the Campus'' data dictionary!)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'ControlAccount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sponsor Code: Reserved for Extramural Accounting.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'SponsorCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sponsor Category Code: Reserved for Extramural Accounting.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'SponsorCategoryCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Federal Agency Code: A code which identifies the federal agency which a sponsor is associated with or a part of', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'FederalAgencyCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'C.F.D.A. Number: Code of Federal Domestic Assistance Number used on Contracts and Grants reporting', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'CFDANum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Award Number: Identifies the specific award number assigned by the sponsor or university.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'AwardNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Award Type Code: Identifies an award as a contract or grant. ''1'' = Cooperative Agreement; ''2'' = Contract; ''3'' = Grant; and ''4'' = Gift  	', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'AwardTypeCode';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Award Year Number: The contract or grant budget year.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'AwardYearNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Award Begin Date: Effective date of the a contract or grant.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'AwardBeginDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Award End Date: The termination date of a contract or grant.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'AwardEndDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Award Amount: The dollar amount of the total awarded for the contract or grant.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'AwardAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'I.C.R. Type (Indirect Cost Recovery Type): A two character code to identify a group of accounts which share a common basis for the calculation of indirect cost. The accounts associated with this type will exclude a common set of object codes from their indirect cost calculation.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'ICRTypeCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Icr Series Number: Indicates the indirect cost rate that applies to a contract or grant account', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'ICRSeriesNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Higher Education Function Code: Function codes which are assigned to each account which match expenditures to the functionality of the account. Higher Education examples are instruction, academic support, art and museums, etc. These names are the most detailed level of functional classification and are utilized in determining AICPA function codes, and federal function codes for indirect cost purposes.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'HigherEdFuncCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Reports To Account In Chart Of Accounts Number: Identifies the Chart of Accounts that contains the Account to which this Account reports.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'ReportsToChart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Reports To Account Number: The Account to which this Account reports.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'ReportsToAccount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'OP Account Number: The OP Account that was the old system precursor to this Account.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'A11AcctNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Old IBM A11 Fund Number: Do Not Use -- invalid data -- use the "OP Fund Number" instead.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'A11FundNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'OP Fund Number: UCD/OP reporting fund', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'OpFundNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Op Fund Group Code: OP code indicating the category to which a fund belongs in the university`s accounting structure.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'OpFundGroupCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Academic Discipline Code: Code indicating the academic discipline associated with a specific category of current fund expenditure accounts.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'AcademicDisciplineCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Annual Report Code: Could also be considered a departmental report code for the Campus Financial Schedules. Code used to map individual accounts into one.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'AnnualReportCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Payment Medium Code: Indicates how a sponsor will make payments to the university.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'PaymentMediumCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Nih Document Number: National Institutes of Health Document Number', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'NIHDocNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Unknown/Unused: Unknown field that is automatically populated with NULL during data download process.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'YeType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Primary Key: Unique key distinguishing one account from any other account; composed of Year, Period, Chart and Account', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'AccountPK';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organizations Foreign Key: FK to Account''s Organization in Organizations table', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'OrgFK';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Function Code ID: FK to FunctionCode table if account is classified as CE, OR or IR ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'FunctionCodeID';




GO
CREATE NONCLUSTERED INDEX [Accounts_FundGroupCode_CVIDX]
    ON [dbo].[Accounts]([FundGroupCode] ASC)
    INCLUDE([Account], [Org], [AnnualReportCode], [AccountPK], [OrgFK], [OPFundFK]);


GO
CREATE NONCLUSTERED INDEX [Accounts_FringeBenefitChartFringeBenefitAccount]
    ON [dbo].[Accounts]([FringeBenefitChart] ASC, [FringeBenefitAccount] ASC);


GO
CREATE NONCLUSTERED INDEX [Accounts_ChartYearExpirationDate_CVIDX]
    ON [dbo].[Accounts]([Chart] ASC, [Year] ASC, [ExpirationDate] ASC)
    INCLUDE([Account], [MgrId], [MgrName]);


GO
CREATE NONCLUSTERED INDEX [Accounts_ChartOpFundNumYearExpirationDate_CVIDX]
    ON [dbo].[Accounts]([Chart] ASC, [OpFundNum] ASC, [Year] ASC, [ExpirationDate] ASC)
    INCLUDE([Period], [Account], [Org], [HigherEdFuncCode], [A11AcctNum], [MgrId], [MgrName]);


GO
CREATE NONCLUSTERED INDEX [Accounts_Chart,Year,Account,ExpirationDate_IDX]
    ON [dbo].[Accounts]([Chart] ASC, [Year] ASC, [Account] ASC, [ExpirationDate] ASC);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Reviewer Name: Name of an individual who is interested in the activity of an account, but who is not responsible for inputting transactions.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'ReviewerName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Reviewer Id: Identifies the user ID of the account reviewer for the account. The account reviewer is an individual who is interested in the activity of an account on an ongoing basis but who is not responsible for the fiscal activity of the account.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'ReviewerId';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Principal Investigator Id: Identifies the user ID of the principal investigator of the contract or grant for whom the account has been set up.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'PrincipalInvestigatorId';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Manager Id: The user id of the person responsible for an organization; specifically for the financial operations of the organization.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'MgrId';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fringe Benefit Indicator: Identifies if this account can receive fringe benefit costs', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'FringeBenefitIndicator';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fringe Benefit Chart Number: The GENFND chart number to which the FEDAPP benefits costs are charged against', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'FringeBenefitChart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Fringe Benefit Account Number: The GENFND account number to which the FEDAPP benefits costs are charged against', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Accounts', @level2type = N'COLUMN', @level2name = N'FringeBenefitAccount';

