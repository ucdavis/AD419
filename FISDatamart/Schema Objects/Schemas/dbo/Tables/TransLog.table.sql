﻿CREATE TABLE [dbo].[TransLog] (
    [PKTrans]                VARCHAR (200)   NOT NULL,
    [OrganizationFK]         VARCHAR (14)    NULL,
    [FiscalYear]             INT             NOT NULL,
    [FiscalPeriod]           CHAR (2)        NOT NULL,
    [Chart]                  VARCHAR (2)     NOT NULL,
    [OrgCode]                CHAR (4)        NOT NULL,
    [OrgName]                VARCHAR (40)    NULL,
    [OrgLevel]               TINYINT         NOT NULL,
    [OrgType]                CHAR (4)        NOT NULL,
    [Level1_OrgCode]         CHAR (4)        NULL,
    [Level1_OrgName]         VARCHAR (40)    NULL,
    [Level2_OrgCode]         CHAR (4)        NULL,
    [Level2_OrgName]         VARCHAR (40)    NULL,
    [Level3_OrgCode]         CHAR (4)        NULL,
    [Level3_OrgName]         VARCHAR (40)    NULL,
    [Account]                VARCHAR (10)    NOT NULL,
    [AccountNum]             CHAR (7)        NOT NULL,
    [AccountName]            VARCHAR (40)    NULL,
    [AccountManager]         VARCHAR (30)    NULL,
    [PrincipalInvestigator]  VARCHAR (30)    NULL,
    [AccountType]            CHAR (2)        NULL,
    [AccountPurpose]         VARCHAR (400)   NULL,
    [FederalAgencyCode]      CHAR (2)        NULL,
    [AccountAwardNumber]     VARCHAR (20)    NULL,
    [AccountAwardType]       CHAR (1)        NULL,
    [AccountAwardAmount]     DECIMAL (15, 2) NULL,
    [AccountAwardEndDate]    DATETIME        NULL,
    [HigherEdFunctionCode]   CHAR (4)        NULL,
    [FringeBenefitIndicator] CHAR (1)        NULL,
    [FringeBenefitChart]     VARCHAR (2)     NULL,
    [FringeBenefitAccount]   CHAR (7)        NULL,
    [AccountFunctionCode]    CHAR (2)        NULL,
    [OPAccount]              CHAR (7)        NULL,
    [OPFund]                 CHAR (6)        NULL,
    [OPFundName]             VARCHAR (40)    NULL,
    [OPFundGroup]            CHAR (6)        NULL,
    [OPFundGroupName]        VARCHAR (40)    NULL,
    [AccountFundGroup]       CHAR (2)        NULL,
    [AccountFundGroupName]   VARCHAR (40)    NULL,
    [SubFundGroup]           CHAR (6)        NULL,
    [SubFundGroupName]       VARCHAR (40)    NULL,
    [SubFundGroupType]       CHAR (2)        NULL,
    [SubFundGroupTypeName]   VARCHAR (40)    NULL,
    [AnnualReportCode]       CHAR (6)        NULL,
    [SubAccount]             CHAR (5)        NULL,
    [SubAccountName]         VARCHAR (40)    NULL,
    [ObjectCode]             CHAR (4)        NULL,
    [ObjectName]             VARCHAR (40)    NULL,
    [ObjectShortName]        CHAR (12)       NULL,
    [BudgetAggregationCode]  CHAR (6)        NULL,
    [ObjectType]             CHAR (2)        NULL,
    [ObjectTypeName]         VARCHAR (40)    NULL,
    [ObjectLevelName]        VARCHAR (40)    NULL,
    [ObjectLevelShortName]   CHAR (12)       NULL,
    [ObjectLevelCode]        CHAR (4)        NULL,
    [ObjectSubType]          CHAR (2)        NULL,
    [ObjectSubTypeName]      VARCHAR (40)    NULL,
    [ConsolidationCode]      CHAR (4)        NULL,
    [ConsolidationName]      VARCHAR (40)    NULL,
    [ConsolidationShortName] CHAR (12)       NULL,
    [SubObject]              VARCHAR (5)     NULL,
    [ProjectCode]            CHAR (10)       NULL,
    [ProjectName]            VARCHAR (40)    NULL,
    [ProjectManager]         CHAR (8)        NULL,
    [ProjectDescription]     TEXT            NULL,
    [TransDocType]           CHAR (4)        NULL,
    [TransDocTypeName]       VARCHAR (40)    NULL,
    [TransDocOrigin]         CHAR (2)        NULL,
    [DocumentNumber]         VARCHAR (17)    NULL,
    [TransDocNum]            VARCHAR (14)    NULL,
    [TransDocTrackNum]       CHAR (10)       NULL,
    [TransDocInitiator]      CHAR (8)        NULL,
    [TransInitDate]          SMALLDATETIME   NULL,
    [LineSequenceNum]        DECIMAL (7)     NULL,
    [TransDescription]       VARCHAR (40)    NULL,
    [TransLineAmount]        DECIMAL (15, 2) NULL,
    [TransBalanceType]       CHAR (2)        NULL,
    [ExpendAmount]           DECIMAL (15, 2) NULL,
    [AppropAmount]           DECIMAL (15, 2) NULL,
    [EncumbAmount]           DECIMAL (15, 2) NULL,
    [TransLineReference]     CHAR (8)        NULL,
    [TransPriorDocTypeNum]   CHAR (4)        NULL,
    [TransPriorDocOrigin]    CHAR (2)        NULL,
    [TransPriorDocNum]       VARCHAR (14)    NULL,
    [TransEncumUpdateCode]   CHAR (1)        NULL,
    [TransCreationDate]      SMALLDATETIME   NULL,
    [TransPostDate]          SMALLDATETIME   NULL,
    [TransReversalDate]      SMALLDATETIME   NULL,
    [TransChangeDate]        SMALLDATETIME   NULL,
    [TransSourceTableCode]   CHAR (1)        NULL,
    [IsPendingTrans]         BIT             NULL,
    [IsCAESTrans]            TINYINT         NULL,
    [PartitionColumn]        AS              ([FiscalYear]%([FiscalYear]/(4))+(1)) PERSISTED
);






GO
CREATE NONCLUSTERED INDEX [TransLogMain_FYChartArcCodeConsolidationCodeTransBalType_IDX]
    ON [dbo].[TransLog]([FiscalYear] ASC, [Chart] ASC, [AnnualReportCode] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    INCLUDE([ObjectCode], [ExpendAmount])
    ON [MyPartitionScheme] ([PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_FringeBenefitChartFringeBenefitAccount_IDX]
    ON [dbo].[TransLog]([FringeBenefitChart] ASC, [FringeBenefitAccount] ASC)
    ON [MyPartitionScheme] ([PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_FiscalYearChartOPFundIsCAESTransObjectCodeConsolidationCodeTransBalanceType_CVINDX]
    ON [dbo].[TransLog]([FiscalYear] ASC, [Chart] ASC, [OPFund] ASC, [IsCAESTrans] ASC, [ObjectCode] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    INCLUDE([AccountNum], [HigherEdFunctionCode], [OPAccount], [SubAccount], [SubObject], [ProjectCode], [TransLineAmount])
    ON [MyPartitionScheme] ([PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_FiscalYearChartOPFundIsCAESTransObjectCodeConsolidationCodeTransBalanceType]
    ON [dbo].[TransLog]([FiscalYear] ASC, [Chart] ASC, [OPFund] ASC, [IsCAESTrans] ASC, [ObjectCode] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    INCLUDE([AccountNum], [HigherEdFunctionCode], [OPAccount], [SubAccount], [SubObject], [ProjectCode], [TransLineAmount])
    ON [MyPartitionScheme] ([PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_ChartOPFundIsCAESTransFiscalYearObjectCodeConsolidationCodeTransBalanceType_CVINDX]
    ON [dbo].[TransLog]([Chart] ASC, [OPFund] ASC, [IsCAESTrans] ASC, [FiscalYear] ASC, [ObjectCode] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    INCLUDE([Level3_OrgCode], [AccountNum], [TransLineAmount])
    ON [MyPartitionScheme] ([PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_ChartOPFundIsCAESTransFiscalYearObjectCodeConsolidationCodeTransBalanceType_CVIDX]
    ON [dbo].[TransLog]([Chart] ASC, [OPFund] ASC, [IsCAESTrans] ASC, [FiscalYear] ASC, [ObjectCode] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    INCLUDE([Level3_OrgCode], [AccountNum], [TransLineAmount])
    ON [MyPartitionScheme] ([PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_ChartOPFundIsCAESTransFiscalYearAccountNumObjectCodeConsolidationCodeTransBalanceType_CVIDX]
    ON [dbo].[TransLog]([Chart] ASC, [OPFund] ASC, [IsCAESTrans] ASC, [FiscalYear] ASC, [AccountNum] ASC, [ObjectCode] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    INCLUDE([Level3_OrgCode], [TransLineAmount])
    ON [MyPartitionScheme] ([PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_ChartOPFundIsCAESTransFiscalYearAccountNumObjectCodeConsolidationCodeTransBalanceType]
    ON [dbo].[TransLog]([Chart] ASC, [OPFund] ASC, [IsCAESTrans] ASC, [FiscalYear] ASC, [AccountNum] ASC, [ObjectCode] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    ON [MyPartitionScheme] ([PartitionColumn]);


GO
CREATE NONCLUSTERED INDEX [TransLogMain_ChartOPFundIsCAESTransFiscalYearAccountNumConsolidationCodeTransBalanceType_CVIDX]
    ON [dbo].[TransLog]([Chart] ASC, [OPFund] ASC, [IsCAESTrans] ASC, [FiscalYear] ASC, [AccountNum] ASC, [ConsolidationCode] ASC, [TransBalanceType] ASC)
    INCLUDE([ObjectCode])
    ON [MyPartitionScheme] ([PartitionColumn]);

