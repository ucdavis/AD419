CREATE TABLE [dbo].[Distributions] (
    [EmployeeID]           CHAR (9)       NOT NULL,
    [DistNo]               SMALLINT       NOT NULL,
    [ApptNo]               SMALLINT       NOT NULL,
    [Chart]                CHAR (1)       NULL,
    [Account]              CHAR (7)       NULL,
    [SubAccount]           VARCHAR (5)    NULL,
    [Object]               VARCHAR (4)    NULL,
    [SubObject]            VARCHAR (3)    NULL,
    [Project]              VARCHAR (10)   NULL,
    [OPFund]               VARCHAR (6)    NULL,
    [SubFundGroupTypeCode] VARCHAR (2)    NULL,
    [SubFundGroupCode]     VARCHAR (6)    NULL,
    [DepartmentNo]         CHAR (6)       NULL,
    [OrgCode]              VARCHAR (4)    NULL,
    [FTE]                  DECIMAL (3, 2) NULL,
    [PayBegin]             DATETIME       NULL,
    [PayEnd]               DATETIME       NULL,
    [Percent]              DECIMAL (5, 4) NULL,
    [PayRate]              DECIMAL (9, 4) NULL,
    [DOSCode]              CHAR (3)       NULL,
    [ADCCode]              CHAR (1)       NULL,
    [Step]                 VARCHAR (4)    NULL,
    [OffScaleCode]         CHAR (1)       NULL,
    [WorkStudyPGM]         CHAR (1)       NULL,
    [IsInPPS]              BIT            NULL
);




GO
CREATE UNIQUE CLUSTERED INDEX [PK_Distributions]
    ON [dbo].[Distributions]([EmployeeID] ASC, [DistNo] ASC, [ApptNo] ASC, [PayBegin] ASC, [PayEnd] ASC);


GO
CREATE NONCLUSTERED INDEX [Distributions_Step_IDX]
    ON [dbo].[Distributions]([Step] ASC);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'The funding (FAU) for an appointment. Similar to the appointment, the distribution is also date and percentage of time controlled. The format and contents of the pay rate field depends on the hourly or annual rate code. The Derived Department Code comes from the DAFIS Chart of Accounts Account Table at the time in which the Distribution is established. The data originates from the Employee Data Base (EDB) and contains recently-expired, current and future distributions.

Similar to the Appointment Table (EDBAPP), the data warehouse update process does a comparison against the UCOP data base and any records that are added, changed or deleted are identified in the UCD_ADC_CODE and UCD_ADC_DATE. Records that are flagged as deleted will be deleted from the data warehouse after 8 days.

On July 1, 1997, a new financial management system (known as DaFIS) replaced the A11 accounting system. The A11 accounting data fields (location code, account number, fund number, and sub account number) were replaced by the data field FAU (Full Accounting Unit). The full account unit (FAU) is composed of the chart of accounts number, account number, sub account number, object number, sub object number, and project number. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Work study program code: The code indicating the type of work study program associated with the appointment. (translation in PAYROLL.CTLWSP table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'WorkStudyPGM';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub-object number: Provides for an object code to be broken down into greater detail. Assigned by account manager. (created from FAU field during update/load process) (translation in FISDataMart.Objects table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'SubObject';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub-fund group type code: The code used to group like sub funds. For example, Federal Contracts would be a sub fund group type with a number of associated sub fund groups. (Lookup in EDDACCT table). ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'SubFundGroupTypeCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub-fund group number: The code used to identify the fund source of an account. Similar to the A11 system fund number, but will be an alpha abbreviation instead of a number. (Lookup in EDDACCT table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'SubFundGroupCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub-account number: Allows an account to be broken down in more detail (Cost Center) in order to better track detail transactions. The sub account takes on the attributes of the account it reports, including account manager, fund group and function code. Assigned by account manager. (created from FAU field during update/load process) (translation in FISDataMart.SubAccounts table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'SubAccount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Salary step: The level, within a pay range, of the associated distribution pay rate.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'Step';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Project number: The code used to track and accumulate transactions across multiple charts, accounts and fund groups. (created from FAU field during update/load process) (translation in FISDataMart.Projects table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'Project';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Distribution percent time: The anticipated time which is chargeable to the distribution. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'Percent';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Distribution pay rate: The full-time hourly rate, pay period amount, or by agreement amount associated with the distribution. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'PayRate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Pay ending date: The date on which an appointment ceases to be charged against an associated distribution. For pay distributions with indefinite ending dates (99/99/99), this field is null. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'PayEnd';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Pay begin date: The date on which an appointment commences to be charged against an associated distribution. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'PayBegin';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Organization code: The identifier of an organization. (added from DaFIS Account table during update/load process) (Translation in the FISDataMart.Organizations table.)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'OrgCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'UCD/OP fund number: UCD pre-DAFIS fund number for reporting to Office of the President. (added from DaFIS Account table during update/load process)  (translation in FISDataMart.OpFund table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'OPFund';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Above/Off scale indicator: The code indicating the relationship of pay rate to the step and salary range for the title code of the appointment. (values are A=above scale-academic, B=above scale-academic/red circle, O=off scale-academic,P=off scale-academic/red circle,R=red circle-nonacademic or BLANK=on scale. Other codes can be created for special handling during pay reduction periods.) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'OffScaleCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Object number: Identifier used to classify accounting transactions by type. Examples are academic salaries, in-state travel, Reg Fee income. (created from FAU field during update/load process) (translation in FISDataMart.Objects table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'Object';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Is record in PPS?: A local flag, which indicates whether or not a person is in the current PPS dataset.  Used to determine if a person should be displayed as a current CA&ES employee. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'IsInPPS';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Dist. Full-time equivalent: The percentage of the budgeted position which the distribution represents. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'FTE';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Employee ID number: The unique employee identification number. (primary key) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'EmployeeID';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Discription of service code: The code indicating the type of service or type of pay associated with the appointment. (translation in PAYROLL.CTLDOS table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'DOSCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Distribution number: The number uniquely identifying a payroll distribution associated with an appointment. (primary key) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'DistNo';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Derived department code: The code indicating the department or other administrative unit associated with the account number for a distribution. (translation in Departments table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'DepartmentNo';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart of accounts: Identifer of a Chart of Accounts. (created from FAU field during update/load process) (translation in PAYROLL.COACRT table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'Chart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Appointment Number: The unique number used to identify an appointment. (primary key) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'ApptNo';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Add/Change/Delete flag:  The code indicating the type of action taken on a distribution. (values are A=add a new distribution, C=change an already existing distribution, or D=delete an existing distribution)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'ADCCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account number: Organization chosen identifier used to classify financial resources for accounting and reporting purposes. (created from FAU field during update/load process) (translation in FISDataMart.Accounts table) ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Distributions', @level2type = N'COLUMN', @level2name = N'Account';

