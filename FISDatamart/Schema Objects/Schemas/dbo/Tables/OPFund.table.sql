CREATE TABLE [dbo].[OPFund] (
    [Year]              INT             NOT NULL,
    [Period]            CHAR (2)        NOT NULL,
    [Chart]             VARCHAR (2)     NOT NULL,
    [FundNum]           VARCHAR (6)     NOT NULL,
    [FundName]          VARCHAR (40)    NULL,
    [FundGroupCode]     VARCHAR (6)     NULL,
    [FundGroupName]     VARCHAR (40)    NULL,
    [SubFundGroupNum]   VARCHAR (6)     NULL,
    [AwardNum]          VARCHAR (20)    NULL,
    [AwardType]         VARCHAR (1)     NULL,
    [AwardYearNum]      VARCHAR (2)     NULL,
    [AwardBeginDate]    VARCHAR (30)    NULL,
    [AwardEndDate]      VARCHAR (30)    NULL,
    [AwardAmount]       NUMERIC (15, 2) NULL,
    [LastUpdateDate]    SMALLDATETIME   NULL,
    [OPFundPK]          VARCHAR (17)    NULL,
    [SubFundGroupFK]    VARCHAR (14)    NULL,
    [PrimaryPIUserName] VARCHAR (50)    NULL,
    [ProjectTitle]      VARCHAR (256)   NULL,
    [CFDANum]           VARCHAR (6)     NULL,
    CONSTRAINT [PK_OPFund_1] PRIMARY KEY CLUSTERED ([Year] ASC, [Period] ASC, [Chart] ASC, [FundNum] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'List of all OP fund numbers, by location code, used at Davis.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'OP Location/Fund Effective Fiscal Year: The fiscal year in which this set of values was in effect', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund', @level2type = N'COLUMN', @level2name = N'Year';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'OP Location/Fund Effective Fiscal Period: The fiscal period for which this set of values was in effect', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund', @level2type = N'COLUMN', @level2name = N'Period';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'OP Fund Number: Office of the President fund number. The Location/Fund combination is used for reporting DaFIS information back to OP.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund', @level2type = N'COLUMN', @level2name = N'FundNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'OP Fund Name: Descriptive Name of the OP Fund Number', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund', @level2type = N'COLUMN', @level2name = N'FundName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'OP Fund Group Code: Identifies groups of Fund Numbers for reporting purposes', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund', @level2type = N'COLUMN', @level2name = N'FundGroupCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'OP Fund Group Name: Descriptive Name of the OP Fund Group Code', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund', @level2type = N'COLUMN', @level2name = N'FundGroupName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Sub Fund Group Number: Code that identifies the fund source of an account. Examples of sub fund groups include continuing education accounts, scholarships and fellowships, general funds, etc.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund', @level2type = N'COLUMN', @level2name = N'SubFundGroupNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Award Number: Identifies the specific award number assigned by the sponsor or university.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund', @level2type = N'COLUMN', @level2name = N'AwardNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Award Type Code: Identifies an award as a contract or grant. ''1'' = Cooperative Agreement; ''2'' = Contract; ''3'' = Grant; and ''4'' = Gift', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund', @level2type = N'COLUMN', @level2name = N'AwardType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Award Year Number: The contract or grant budget year.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund', @level2type = N'COLUMN', @level2name = N'AwardYearNum';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Award Begin Date: Effective date of the a contract or grant.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund', @level2type = N'COLUMN', @level2name = N'AwardBeginDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Award End Date: The termination date of a contract or grant.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund', @level2type = N'COLUMN', @level2name = N'AwardEndDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Award Amount: The dollar amount of the total awarded for the contract or grant.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund', @level2type = N'COLUMN', @level2name = N'AwardAmount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Last Update Date: Date this row was last updated in Decision Support', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Primary Key: Unique identifier used for performing FK joins on other tables comprised of Year, Period, Chart and FundNum.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'OPFund', @level2type = N'COLUMN', @level2name = N'OPFundPK';

