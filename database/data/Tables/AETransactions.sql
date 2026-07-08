CREATE TABLE [data].[AETransactions]
(
    [Id]                             BIGINT         NOT NULL IDENTITY(1, 1),

    -- Chart string segments (column names aligned with UcPathTransactions for a future union)
    [Entity]                         NVARCHAR(50)   NULL,
    [Fund]                           NVARCHAR(50)   NULL,
    [FinancialDepartment]            NVARCHAR(50)   NULL,
    [Account]                        NVARCHAR(50)   NULL,
    [Purpose]                        NVARCHAR(50)   NULL,
    [Program]                        NVARCHAR(50)   NULL,
    [Project]                        NVARCHAR(50)   NULL,
    [Activity]                       NVARCHAR(50)   NULL,

    [EntityDescription]              NVARCHAR(400)  NULL,
    [FundDescription]                NVARCHAR(400)  NULL,
    [FinancialDepartmentDescription] NVARCHAR(400)  NULL,
    [AccountDescription]             NVARCHAR(400)  NULL,
    [PurposeDescription]             NVARCHAR(400)  NULL,
    [ProgramDescription]             NVARCHAR(400)  NULL,
    [ProjectDescription]             NVARCHAR(400)  NULL,
    [ActivityDescription]            NVARCHAR(400)  NULL,

    [DocumentType]                   NVARCHAR(10)   NULL,
    [AccountingSequenceNumber]       BIGINT         NULL,
    [TrackingNo]                     NVARCHAR(300)  NULL,
    [Reference]                      NVARCHAR(300)  NULL,
    [JournalLineDescription]         NVARCHAR(400)  NULL,
    [JournalAcctDate]                DATE           NULL,
    [JournalName]                    NVARCHAR(200)  NULL,
    [JournalReference]               NVARCHAR(160)  NULL,
    [PeriodName]                     NVARCHAR(30)   NULL,
    [JournalBatchName]               NVARCHAR(200)  NULL,
    [JournalSource]                  NVARCHAR(50)   NULL,
    [JournalCategory]                NVARCHAR(50)   NULL,
    [BatchStatus]                    NVARCHAR(2)    NULL,

    [Amount]                         DECIMAL(19, 4) NULL,  -- actual_amount; import filters to actual_flag = 'A'
    [CommitmentAmount]               DECIMAL(19, 4) NULL,
    [ObligationAmount]               DECIMAL(19, 4) NULL,
    [EtlLoadDt]                      DATETIME2(7)   NULL,

    -- Persisted exclusions for rules not owned by step 2 classification.
    -- NULL = not yet classified (fails closed downstream).
    [ExcludedByDate]                 BIT            NULL,

    [LoadedAt]                       DATETIME2(3)   NULL CONSTRAINT [DF_AETransactions_LoadedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_AETransactions] PRIMARY KEY CLUSTERED ([Id])
);
