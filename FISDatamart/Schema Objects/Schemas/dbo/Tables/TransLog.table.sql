CREATE TABLE [dbo].[TransLog] (
    [Account]                VARCHAR (10)    NOT NULL,
    [AccountAwardAmount]     DECIMAL (15, 2) NULL,
    [AccountAwardEndDate]    DATETIME        NULL,
    [AccountAwardNumber]     VARCHAR (20)    NULL,
    [AccountAwardType]       CHAR (1)        NULL,
    [AccountFunctionCode]    CHAR (2)        NULL,
    [AccountFundGroup]       CHAR (2)        NULL,
    [AccountFundGroupName]   VARCHAR (40)    NULL,
    [AccountManager]         VARCHAR (30)    NULL,
    [AccountName]            VARCHAR (40)    NULL,
    [AccountNum]             CHAR (7)        NOT NULL,
    [AccountPurpose]         VARCHAR (400)   NULL,
    [AccountType]            CHAR (2)        NULL,
    [AnnualReportCode]       CHAR (6)        NULL,
    [AppropAmount]           DECIMAL (15, 2) NULL,
    [BudgetAggregationCode]  CHAR (6)        NULL,
    [Chart]                  VARCHAR (2)     NOT NULL,
    [ConsolidationCode]      CHAR (4)        NULL,
    [ConsolidationName]      VARCHAR (40)    NULL,
    [ConsolidationShortName] CHAR (12)       NULL,
    [DocumentNumber]         VARCHAR (17)    NULL,
    [EncumbAmount]           DECIMAL (15, 2) NULL,
    [ExpendAmount]           DECIMAL (15, 2) NULL,
    [FederalAgencyCode]      CHAR (2)        NULL,
    [FiscalPeriod]           CHAR (2)        NOT NULL,
    [FiscalYear]             INT             NOT NULL,
    [FringeBenefitAccount]   CHAR (7)        NULL,
    [FringeBenefitChart]     VARCHAR (2)     NULL,
    [FringeBenefitIndicator] CHAR (1)        NULL,
    [HigherEdFunctionCode]   CHAR (4)        NULL,
    [IsCAESTrans]            TINYINT         NULL,
    [IsPendingTrans]         BIT             NULL,
    [Level1_OrgCode]         CHAR (4)        NULL,
    [Level1_OrgName]         VARCHAR (40)    NULL,
    [Level2_OrgCode]         CHAR (4)        NULL,
    [Level2_OrgName]         VARCHAR (40)    NULL,
    [Level3_OrgCode]         CHAR (4)        NULL,
    [Level3_OrgName]         VARCHAR (40)    NULL,
    [LineSequenceNum]        DECIMAL (7)     NULL,
    [ObjectCode]             CHAR (4)        NULL,
    [ObjectLevelCode]        CHAR (4)        NULL,
    [ObjectLevelName]        VARCHAR (40)    NULL,
    [ObjectLevelShortName]   CHAR (12)       NULL,
    [ObjectName]             VARCHAR (40)    NULL,
    [ObjectShortName]        CHAR (12)       NULL,
    [ObjectSubType]          CHAR (2)        NULL,
    [ObjectSubTypeName]      VARCHAR (40)    NULL,
    [ObjectType]             CHAR (2)        NULL,
    [ObjectTypeName]         VARCHAR (40)    NULL,
    [OPAccount]              CHAR (7)        NULL,
    [OPFund]                 CHAR (6)        NULL,
    [OPFundGroup]            CHAR (6)        NULL,
    [OPFundGroupName]        VARCHAR (40)    NULL,
    [OPFundName]             VARCHAR (40)    NULL,
    [OrganizationFK]         VARCHAR (14)    NULL,
    [OrgCode]                CHAR (4)        NOT NULL,
    [OrgLevel]               TINYINT         NOT NULL,
    [OrgName]                VARCHAR (40)    NULL,
    [OrgType]                CHAR (4)        NOT NULL,
    [PartitionColumn]        AS              ([FiscalYear]%([FiscalYear]/(4))+(1)) PERSISTED,
    [PKTrans]                VARCHAR (200)   NOT NULL,
    [PrincipalInvestigator]  VARCHAR (50)    NULL,
    [ProjectCode]            CHAR (10)       NULL,
    [ProjectDescription]     TEXT            NULL,
    [ProjectManager]         CHAR (8)        NULL,
    [ProjectName]            VARCHAR (40)    NULL,
    [SubAccount]             CHAR (5)        NULL,
    [SubAccountName]         VARCHAR (40)    NULL,
    [SubFundGroup]           CHAR (6)        NULL,
    [SubFundGroupName]       VARCHAR (40)    NULL,
    [SubFundGroupType]       CHAR (2)        NULL,
    [SubFundGroupTypeName]   VARCHAR (40)    NULL,
    [SubObject]              VARCHAR (5)     NULL,
    [TransBalanceType]       CHAR (2)        NULL,
    [TransChangeDate]        SMALLDATETIME   NULL,
    [TransCreationDate]      SMALLDATETIME   NULL,
    [TransDescription]       VARCHAR (40)    NULL,
    [TransDocInitiator]      CHAR (8)        NULL,
    [TransDocNum]            VARCHAR (14)    NULL,
    [TransDocOrigin]         CHAR (2)        NULL,
    [TransDocTrackNum]       CHAR (10)       NULL,
    [TransDocType]           CHAR (4)        NULL,
    [TransDocTypeName]       VARCHAR (40)    NULL,
    [TransEncumUpdateCode]   CHAR (1)        NULL,
    [TransInitDate]          SMALLDATETIME   NULL,
    [TransLineAmount]        DECIMAL (15, 2) NULL,
    [TransLineReference]     CHAR (8)        NULL,
    [TransPostDate]          SMALLDATETIME   NULL,
    [TransPriorDocNum]       VARCHAR (14)    NULL,
    [TransPriorDocOrigin]    CHAR (2)        NULL,
    [TransPriorDocTypeNum]   CHAR (4)        NULL,
    [TransReversalDate]      SMALLDATETIME   NULL,
    [TransSourceTableCode]   CHAR (1)        NULL
);




GO
CREATE NONCLUSTERED INDEX [TransLogMain_FYChartArcCodeConsolidationCodeTransBalType_IDX]
    ON [dbo].[TransLog]([FiscalYear] ASC, [Chart] ASC, [AnnualReportCode] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    INCLUDE([ObjectCode], [ExpendAmount], [PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_FringeBenefitChartFringeBenefitAccount_IDX]
    ON [dbo].[TransLog]([FringeBenefitChart] ASC, [FringeBenefitAccount] ASC)
    INCLUDE([PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_FiscalYearChartOPFundIsCAESTransObjectCodeConsolidationCodeTransBalanceType_CVINDX]
    ON [dbo].[TransLog]([FiscalYear] ASC, [Chart] ASC, [OPFund] ASC, [IsCAESTrans] ASC, [ObjectCode] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    INCLUDE([ProjectCode], [TransLineAmount], [AccountNum], [HigherEdFunctionCode], [OPAccount], [SubAccount], [SubObject], [PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_FiscalYearChartOPFundIsCAESTransObjectCodeConsolidationCodeTransBalanceType]
    ON [dbo].[TransLog]([FiscalYear] ASC, [Chart] ASC, [OPFund] ASC, [IsCAESTrans] ASC, [ObjectCode] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    INCLUDE([AccountNum], [HigherEdFunctionCode], [OPAccount], [SubAccount], [SubObject], [ProjectCode], [TransLineAmount], [PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_ChartOPFundIsCAESTransFiscalYearObjectCodeConsolidationCodeTransBalanceType_CVINDX]
    ON [dbo].[TransLog]([Chart] ASC, [OPFund] ASC, [IsCAESTrans] ASC, [FiscalYear] ASC, [ObjectCode] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    INCLUDE([Level3_OrgCode], [AccountNum], [TransLineAmount], [PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_ChartOPFundIsCAESTransFiscalYearObjectCodeConsolidationCodeTransBalanceType_CVIDX]
    ON [dbo].[TransLog]([Chart] ASC, [OPFund] ASC, [IsCAESTrans] ASC, [FiscalYear] ASC, [ObjectCode] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    INCLUDE([Level3_OrgCode], [AccountNum], [TransLineAmount], [PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_ChartOPFundIsCAESTransFiscalYearAccountNumObjectCodeConsolidationCodeTransBalanceType_CVIDX]
    ON [dbo].[TransLog]([Chart] ASC, [OPFund] ASC, [IsCAESTrans] ASC, [FiscalYear] ASC, [AccountNum] ASC, [ObjectCode] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    INCLUDE([Level3_OrgCode], [TransLineAmount], [PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_ChartOPFundIsCAESTransFiscalYearAccountNumObjectCodeConsolidationCodeTransBalanceType]
    ON [dbo].[TransLog]([Chart] ASC, [OPFund] ASC, [IsCAESTrans] ASC, [FiscalYear] ASC, [AccountNum] ASC, [ObjectCode] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    INCLUDE([PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_ChartOPFundIsCAESTransFiscalYearAccountNumConsolidationCodeTransBalanceType_CVIDX]
    ON [dbo].[TransLog]([Chart] ASC, [OPFund] ASC, [IsCAESTrans] ASC, [FiscalYear] ASC, [AccountNum] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    INCLUDE([ObjectCode], [PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLog_TransBalType_YearPeriodChartAccountArcObjCdConsolCdExpdAmount_CVIDX]
    ON [dbo].[TransLog]([TransBalanceType] ASC)
    INCLUDE([FiscalYear], [FiscalPeriod], [Chart], [AccountNum], [AnnualReportCode], [ObjectCode], [ConsolidationCode], [ExpendAmount], [PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLog_TransBalType_IDX]
    ON [dbo].[TransLog]([TransBalanceType] ASC)
    INCLUDE([PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLog_FiscalYearBalType_CVIDX]
    ON [dbo].[TransLog]([FiscalYear] ASC, [TransBalanceType] ASC)
    INCLUDE([Chart], [OrgCode], [Level1_OrgCode], [Level2_OrgCode], [Level3_OrgCode], [Account], [AccountNum], [ObjectCode], [ConsolidationCode], [ExpendAmount], [IsCAESTrans], [PartitionColumn]);

